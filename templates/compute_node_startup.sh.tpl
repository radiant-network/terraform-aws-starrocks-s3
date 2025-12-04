#!/bin/bash
JAVA_PACKAGE=java-11-amazon-corretto
sudo dnf install -y $JAVA_PACKAGE-devel mariadb105 || (sleep 120 ; sudo dnf install -y $JAVA_PACKAGE-devel mariadb105)

sudo su

cd /opt
sudo wget --quiet https://releases.starrocks.io/starrocks/StarRocks-${starrocks_version}-centos-amd64.tar.gz
sudo tar -xzvf StarRocks-${starrocks_version}-centos-amd64.tar.gz

sudo mkdir -p ${starrocks_data_path}/storage
sudo mkdir -p ${starrocks_data_path}/cn
cp -a StarRocks-${starrocks_version}-centos-amd64/be/. ${starrocks_data_path}/cn/

sudo tee /etc/sysctl.conf > /dev/null << EOF
vm.swappiness = 0
vm.overcommit_memory = 1
kernel.perf_event_paranoid = 1
vm.max_map_count = 262144
net.ipv4.tcp_abort_on_overflow = 1
net.core.somaxconn=1024
EOF

sudo sysctl -p

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

#TODO look into datacache settings
cat > ${starrocks_data_path}/cn/conf/cn.conf<< EOF
# Harcode defaults
be_port=9060
be_http_port=8040
heartbeat_service_port=9050
brpc_port=8060
starlet_port=9070

storage_root_path=${starrocks_data_path}/storage
priority_networks=${vpc_cidr}
memory_limitation_per_thread_for_schema_change = 4
push_worker_count_normal_priority = 6
push_worker_count_high_priority = 6
streaming_load_rpc_max_alive_time_sec = 2400
max_percentage_of_error_disk = 100
compact_threads = 2
datacache_mem_size = 40%
datacache_disk_size = 80%
EOF

sudo tee /etc/systemd/system/starrocks-cn.service > /dev/null << EOF
[Unit]
Description=StarRocks Compute Node
After=network.target

[Service]
Type=simple
Environment="JAVA_HOME=/usr/lib/jvm/$JAVA_PACKAGE.x86_64/" 
Environment="STARROCKS_HOME=${starrocks_data_path}"
Environment="LD_LIBRARY_PATH=/usr/lib/jvm/$JAVA_PACKAGE.x86_64/lib/server/"
Environment="JAVA_OPTS=-Djava.net.preferIPv4Stack=true -Xmx${java_heap_size_mb}m -XX:+UseG1GC -Djava.security.policy=${starrocks_data_path}/conf/udf_security.policy"
ExecStart=/opt/starrocks/cn/bin/start_cn.sh
ExecStop=/opt/starrocks/cn/bin/stop_cn.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable starrocks-cn
sudo systemctl start starrocks-cn

echo "Waiting for Frontend (FE) to be available..."
until echo "SELECT 1;" | mysql -h ${fe_host} -P ${fe_query_port} -uroot 2>/dev/null; do
  sleep 5
done

echo "Registering Backend with Frontend..."
echo "ALTER SYSTEM ADD COMPUTE NODE \"$(hostname -I | awk '{print $1}'):9050\";" | mysql -h ${fe_host} -P ${fe_query_port} -uroot

${additional_cn_user_data}