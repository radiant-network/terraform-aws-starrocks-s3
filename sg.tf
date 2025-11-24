resource "aws_security_group" "star_rocks_sg" {
  name        = "${var.project}-${var.environment}-sg"
  description = "Security group allowing inbound from the Bastion SG and all outbound"
  vpc_id      = var.vpc_id

  # Frontend Query Port
  ingress {
    from_port = 9030
    to_port         = 9030
    protocol        = "tcp"
    cidr_blocks = [data.aws_vpc.target_vpc.cidr_block] 
  }

  # Frontend Edit Log Port (internal FE communications)
  ingress {
    from_port = 9010
    to_port         = 9010
    protocol        = "tcp"
    cidr_blocks = [data.aws_vpc.target_vpc.cidr_block] 
  }

  # Let Bastion access backend HTTP stats
  ingress {
    from_port = 8030
    to_port         = 8030
    protocol        = "tcp"
    cidr_blocks = [data.aws_vpc.target_vpc.cidr_block] 
  }

  ingress {
    from_port = 8040
    to_port         = 8040
    protocol        = "tcp"
    security_groups = [aws_security_group.prometheus_sg.id] 
  }

  ingress {
    from_port = 8030
    to_port         = 8030
    protocol        = "tcp"
    security_groups = [aws_security_group.prometheus_sg.id] 
  }

  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    self = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.environment}-sg"
  }
}

resource "aws_security_group" "grafana_sg" {
  name        = "${var.project}-${var.environment}-grafana-sg"
  description = "Allow Grafana access from Bastion and VPC for Prometheus"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 3000
    to_port         = 3000
    protocol        = "tcp"
    cidr_blocks = [data.aws_vpc.target_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.environment}-grafana-sg"
  }
}

resource "aws_security_group" "prometheus_sg" {
  name        = "${var.project}-${var.environment}-prometheus-sg"
  description = "Allow Prometheus access from Grafana"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 9090
    to_port         = 9090
    protocol        = "tcp"
    security_groups = [aws_security_group.grafana_sg.id] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.environment}-prometheus-sg"
  }
}


