#!/bin/bash
PROMETHEUS_VERSION="2.45.0"

wget https://github.com/prometheus/prometheus/releases/download/v$PROMETHEUS_VERSION/prometheus-$PROMETHEUS_VERSION.linux-amd64.tar.gz
tar xvf prometheus-$PROMETHEUS_VERSION.linux-amd64.tar.gz
mv prometheus-$PROMETHEUS_VERSION.linux-amd64 /opt/prometheus
mkdir /opt/prometheus/data

sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus service
After=network.target

[Service]
User=root
Type=simple
ExecReload=/bin/sh -c "/bin/kill -1 `/usr/bin/pgrep prometheus`"
ExecStop=/bin/sh -c "/bin/kill -9 `/usr/bin/pgrep prometheus`"
ExecStart=/opt/prometheus/prometheus --config.file=/opt/prometheus/prometheus.yml --storage.tsdb.path=/opt/prometheus/data --storage.tsdb.retention.time=30d --storage.tsdb.retention.size=30GB

[Install]
WantedBy=multi-user.target
EOF

sudo tee /opt/prometheus/prometheus.yml > /dev/null <<EOF
global:
  scrape_interval: 15s 
  evaluation_interval: 15s 
scrape_configs:
  - job_name: 'StarRocks_Backends' 
    metrics_path: '/metrics'
    ec2_sd_configs:
      - region: us-east-1
        profile: 
        port: 8040
        filters:
          - name: "tag:Application"
            values: ["${cn_tag}"]
    relabel_configs:
      - source_labels: [__meta_ec2_tag_Name]
        target_label: instance
      - source_labels: [__meta_ec2_private_ip]
        target_label: ip
      - target_label: group
        replacement: be
  - job_name: 'StarRocks_Frontends'
    metrics_path: '/metrics'
    ec2_sd_configs:
      - region: us-east-1
        profile: 
        port: 8030
        filters:
          - name: "tag:Application"
            values: ["${fe_tag}"]
    relabel_configs:
      - source_labels: [__meta_ec2_tag_Name]
        target_label: instance
      - source_labels: [__meta_ec2_private_ip]
        target_label: ip
      - target_label: group
        replacement: fe
EOF

systemctl daemon-reload
systemctl start prometheus.service
systemctl enable prometheus.service