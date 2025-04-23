resource "aws_secretsmanager_secret" "grafana_admin_pw" {
  name = "${var.project}-${var.environment}-grafana-admin-pw"

  tags = {
    Environment = "${var.environment}"
  }
}

resource "random_password" "initial_password" {
  length           = 16
  special          = false
}

# Replace manually with real password after deployment, may need to recreate
# Grafana instance to use new password
resource "aws_secretsmanager_secret_version" "grafana_admin_pw_version" {
  secret_id     = aws_secretsmanager_secret.grafana_admin_pw.id
  secret_string = random_password.initial_password.result
}