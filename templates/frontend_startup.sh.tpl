#!/bin/bash
JAVA_PACKAGE=java-11-amazon-corretto
sudo dnf install -y $JAVA_PACKAGE-devel mariadb105 || (sleep 120 ; sudo dnf install -y $JAVA_PACKAGE-devel mariadb105)

sudo su

sudo tee /etc/sysctl.conf > /dev/null << EOF
vm.swappiness = 0
vm.overcommit_memory = 1
kernel.perf_event_paranoid = 1
vm.max_map_count = 262144
net.ipv4.tcp_abort_on_overflow = 1
net.core.somaxconn=1024
EOF

sudo sysctl -p

cd /opt
sudo wget --quiet https://releases.starrocks.io/starrocks/StarRocks-${starrocks_version}-centos-amd64.tar.gz
sudo tar -xzvf StarRocks-${starrocks_version}-centos-amd64.tar.gz

sudo mkdir -p ${starrocks_data_path}/fe/
cp -a StarRocks-${starrocks_version}-centos-amd64/fe ${starrocks_data_path}/
sudo mkdir -p ${starrocks_data_path}/storage
sudo mkdir -p ${starrocks_data_path}/fe/meta

sudo tee /etc/environment > /dev/null << EOF
JAVA_HOME=/usr/bin/java
STARROCKS_HOME=${starrocks_data_path}
EOF


cat >> /etc/rc.d/rc.local << EOF
if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
   echo madvise > /sys/kernel/mm/transparent_hugepage/enabled
fi
if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
   echo madvise > /sys/kernel/mm/transparent_hugepage/defrag
fi
echo kyber | sudo tee /sys/block/nvme0p1/queue/scheduler
EOF
chmod +x /etc/rc.d/rc.local

sed -i 's/SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
sed -i 's/SELINUXTYPE/#SELINUXTYPE/' /etc/selinux/config

cat > ${starrocks_data_path}/fe/conf/fe.conf<< EOF
# Harcode defaults
http_port=8030
rpc_port=9020
query_port=9030
edit_log_port=9010

run_mode = shared_data
enable_load_volume_from_conf = true
cloud_native_storage_type = S3

aws_s3_endpoint = https://s3.${region}.amazonaws.com
aws_s3_path = s3://${bucket}
aws_s3_use_instance_profile = true
aws_s3_use_aws_sdk_default_behavior = true

meta_dir=${starrocks_data_path}/fe/meta
priority_networks=${vpc_cidr}

mysql_service_nio_enabled = true
enable_collect_query_detail_info = true
enable_udf = true

sys_log_delete_age = 3d
sys_log_roll_num = 5
internal_log_delete_age = 2d
internal_log_roll_num = 5
enable_profile_log = false
audit_log_delete_age = 14d
EOF

IS_FOLLOWER="${is_follower}"
LEADER_IP="${leader_ip}"

if [ "$IS_FOLLOWER" = "true" ]; then
    # Create flag file to indicate follower mode
    echo "$LEADER_IP" > ${starrocks_data_path}/fe/.follower_mode
fi

sudo tee /etc/systemd/system/starrocks-fe.service > /dev/null <<EOF
[Unit]
Description=StarRocks Frontend
After=network.target

[Service]
Type=simple
Environment="JAVA_HOME=/usr/lib/jvm/$JAVA_PACKAGE.x86_64/"
Environment="STARROCKS_HOME=${starrocks_data_path}"
Environment="LD_LIBRARY_PATH=/usr/lib/jvm/$JAVA_PACKAGE.x86_64/lib/server/"
Environment="JAVA_OPTS=-Djava.net.preferIPv4Stack=true -Xmx${java_heap_size_mb}m -XX:+UseG1GC -Djava.security.policy=${starrocks_data_path}/conf/udf_security.policy"
ExecStartPre=/bin/bash -c 'if [ -f ${starrocks_data_path}/fe/.follower_mode ]; then \
    LEADER=\$(cat ${starrocks_data_path}/fe/.follower_mode); \
    echo "Waiting for leader \$LEADER to be ready..."; \
    for i in {1..60}; do \
        if mysql -h \$LEADER -P 9030 -u root -e "SELECT 1" 2>/dev/null; then \
            echo "Leader is ready!"; \
            exit 0; \
        fi; \
        echo "Waiting for leader..."; \
        sleep 5; \
    done; \
    echo "ERROR: Leader not ready after 5 minutes"; \
    exit 1; \
fi'
ExecStart=/bin/bash -c 'if [ -f ${starrocks_data_path}/fe/.follower_mode ]; then \
    LEADER=\$(cat ${starrocks_data_path}/fe/.follower_mode); \
    echo "Starting as follower, joining leader at \$LEADER:9010"; \
    ${starrocks_data_path}/fe/bin/start_fe.sh --helper \$LEADER:9010; \
else \
    echo "Starting as leader"; \
    ${starrocks_data_path}/fe/bin/start_fe.sh; \
fi'
ExecStartPost=/bin/bash -c 'if [ -f ${starrocks_data_path}/fe/.follower_mode ]; then \
    LEADER=\$(cat ${starrocks_data_path}/fe/.follower_mode); \
    MY_IP=\$(hostname -I | awk "{print \$1}"); \
    echo "Waiting for FE to start..."; \
    sleep 30; \
    echo "Registering with leader as follower..."; \
    mysql -h \$LEADER -P 9030 -u root -e "ALTER SYSTEM ADD FOLLOWER \"\$MY_IP:9010\";" || echo "Failed to register, may already be registered"; \
fi'
ExecStop=${starrocks_data_path}/fe/bin/stop_fe.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable starrocks-fe
sudo systemctl start starrocks-fe
