#!/bin/bash
wget -q -O gpg.key https://rpm.grafana.com/gpg.key
sudo rpm --import gpg.key

sudo tee /etc/yum.repos.d/grafana.repo > /dev/null <<EOF
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

sudo dnf install -y grafana aws-cli || (sleep 120; sudo dnf install -y grafana aws-cli)

mkdir -p /etc/grafana/provisioning/datasources/
mkdir -p /etc/grafana/provisioning/dashboards/

cat <<EOF > /etc/grafana/provisioning/datasources/datasource.yml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://${prometheus_ip}:9090
    isDefault: true
    jsonData:
      timeInterval: "5s"
EOF

cat <<EOF > /etc/grafana/provisioning/dashboards/starrocks.yaml
apiVersion: 1
providers:
  - name: 'StarRocks Dashboards'
    folder: ''
    type: file
    options:
      path: /var/lib/grafana/dashboards
EOF

mkdir -p /var/lib/grafana/dashboards/
aws s3 cp s3://${bucket}/dashboards/overview.json /var/lib/grafana/dashboards/overview.json

# Get Grafana password from AWS Secrets Manager
GRAFANA_ADMIN_PASSWORD=$(aws secretsmanager get-secret-value --secret-id ${pw_secret} --query 'SecretString' --output text)

# Set Grafana admin credentials
export GF_SECURITY_ADMIN_USER=admin
export GF_SECURITY_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD

# Add credentials to the Grafana systemd service
mkdir -p /etc/systemd/system/grafana-server.service.d
cat <<EOF > /etc/systemd/system/grafana-server.service.d/env.conf
[Service]
Environment=GF_SECURITY_ADMIN_USER=$GF_SECURITY_ADMIN_USER
Environment=GF_SECURITY_ADMIN_PASSWORD=$GF_SECURITY_ADMIN_PASSWORD
EOF


sudo systemctl daemon-reload
sudo systemctl start grafana-server
sudo systemctl enable grafana-server.service