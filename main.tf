data "aws_kms_key" "ebs_kms_key" {
  key_id = "alias/aws/ebs"
}

data "aws_caller_identity" "current" {}

data "aws_vpc" "target_vpc" {
  id = var.vpc_id
}


resource "aws_instance" "star_rocks_compute_nodes" {
  count = var.compute_node_instance_count
  ami                    = var.ami_id
  instance_type          = var.compute_node_instance_type
  user_data = templatefile("${path.module}/templates/compute_node_startup.sh.tpl", {
    starrocks_version        = var.star_rocks_version
    starrocks_data_path = var.starrocks_data_path
    fe_host = aws_route53_record.private_star_rocks_dns.fqdn
    fe_query_port = 9030
    vpc_cidr = data.aws_vpc.target_vpc.cidr_block
    java_heap_size_mb = var.compute_node_heap_size
  })
  iam_instance_profile   = aws_iam_instance_profile.star_rocks_instance_profile.name
  vpc_security_group_ids = [aws_security_group.star_rocks_sg.id]
  subnet_id              = var.subnet_id
  key_name               = var.ssh_key_name
  ebs_optimized          = true
  monitoring             = true
  volume_tags = {
    Name              = "${var.project}-cn-${var.environment}-volume"
    Application       = var.project
    Description       = "Instance for ${var.project}"
    Starrocks_Backup  = "true"
  }
  root_block_device {
    volume_type = "standard"
    volume_size = var.cn_volume_size_gb
    encrypted   = "true"
  }
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  tags = {
    Name                 = "${var.project}-cn-${var.environment}"
    Application          = "${var.project}-cn"
    Description          = "Instance for ${var.project}"
    Starrocks_Backup  = "true"
  }
}
### TODO: Move followers into a separate TF resource so they can reference the leader by IP
resource "aws_instance" "star_rocks_frontend" {
  count = var.frontend_instance_count
  ami                    = var.ami_id
  instance_type          = var.frontend_instance_type
  user_data = templatefile("${path.module}/templates/frontend_startup.sh.tpl", {
    # If upgrading, follower nodes will be upgraded first
    starrocks_version        = var.star_rocks_upgrade_version != "" && count.index != 0 ? var.star_rocks_upgrade_version : var.star_rocks_version
    starrocks_data_path = var.starrocks_data_path
    region = var.region
    bucket = "${var.starrocks_bucket}"
    vpc_cidr = data.aws_vpc.target_vpc.cidr_block
    java_heap_size_mb = var.frontend_heap_size
    is_follower = count.index == 0 ? "false" : "true"
    leader_ip = aws_route53_record.private_star_rocks_dns.fqdn
  })
  iam_instance_profile   = aws_iam_instance_profile.star_rocks_instance_profile.name
  vpc_security_group_ids = [aws_security_group.star_rocks_sg.id]
  subnet_id              = var.subnet_id
  key_name               = var.ssh_key_name
  ebs_optimized          = true
  monitoring             = true
  volume_tags = {
    Name              = "${var.project}-fe-${var.environment}-volume"
    Application       = var.project
    Description       = "Instance for ${var.project}"
    Starrocks_Backup  = "true"
  }
  root_block_device {
    volume_type = "standard"
    volume_size = var.frontend_volume_size_gb
    encrypted   = "true"
  }
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  tags = {
    Name                 = "${var.project}-fe-${var.environment}"
    Application          = "${var.project}-fe"
    Description          = "Instance for ${var.project}"
    Starrocks_Backup  = "true"
  }
}

resource "aws_instance" "star_rocks_grafana" {
  ami                    = var.ami_id
  instance_type          = var.monitoring_instance_type
  user_data = templatefile("${path.module}/templates/grafana_startup.sh.tpl", {
    prometheus_ip = aws_instance.star_rocks_prometheus.private_ip
    bucket = "${var.starrocks_bucket}"
    pw_secret = "${var.project}-${var.environment}-grafana-admin-pw"
  })
  iam_instance_profile   = aws_iam_instance_profile.monitoring_instance_profile.name
  vpc_security_group_ids = [aws_security_group.grafana_sg.id]
  subnet_id              = var.subnet_id
  key_name               = var.ssh_key_name
  ebs_optimized          = true
  monitoring             = true
  volume_tags = {
    Name              = "${var.project}-grafana-${var.environment}-volume"
    Application       = var.project
    Description       = "Instance for ${var.project}"
    Starrocks_Backup  = "false"
  }
  root_block_device {
    volume_type = "standard"
    volume_size = var.root_volume_size_gb
    encrypted   = "true"
  }
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  tags = {
    Name                 = "${var.project}-grafana-${var.environment}"
    Application          = var.project
    Description          = "Instance for ${var.project}"
    Starrocks_Backup  = "false"
  }
}


resource "aws_instance" "star_rocks_prometheus" {
  ami                    = var.ami_id
  instance_type          = var.monitoring_instance_type
  user_data              = templatefile("${path.module}/templates/prometheus_startup.sh.tpl", {
    cn_tag = "${var.project}-cn"
    fe_tag = "${var.project}-fe"
  })
  iam_instance_profile   = aws_iam_instance_profile.monitoring_instance_profile.name
  vpc_security_group_ids = [aws_security_group.prometheus_sg.id]
  subnet_id              = var.subnet_id
  key_name               = var.ssh_key_name
  ebs_optimized          = true
  monitoring             = true
  volume_tags = {
    Name              = "${var.project}-${var.environment}-volume"
    Application       = var.project
    Description       = "Instance for ${var.project}"
    Starrocks_Backup  = "false"
  }
  root_block_device {
    volume_type = "standard"
    volume_size = var.root_volume_size_gb
    encrypted   = "true"
  }
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  tags = {
    Name                 = "${var.project}-prometheus-${var.environment}"
    Application          = var.project
    Description          = "Instance for ${var.project}"
    Starrocks_Backup  = "false"
  }
}

resource "aws_instance" "upgrade_compute_nodes" {
  count = var.star_rocks_upgrade_version != "" ? 1 : 0
  ami                    = var.ami_id
  instance_type          = var.monitoring_instance_type
  user_data = templatefile("${path.module}/templates/compute_node_startup.sh.tpl", {
    starrocks_version        = var.star_rocks_upgrade_version
    starrocks_data_path = var.starrocks_data_path
    fe_host = aws_route53_record.private_star_rocks_dns.fqdn
    fe_query_port = 9030
    vpc_cidr = data.aws_vpc.target_vpc.cidr_block
    java_heap_size_mb = var.compute_node_heap_size
  })
  iam_instance_profile   = aws_iam_instance_profile.star_rocks_instance_profile.name
  vpc_security_group_ids = [aws_security_group.star_rocks_sg.id]
  subnet_id              = var.subnet_id
  key_name               = var.ssh_key_name
  ebs_optimized          = true
  monitoring             = true
  volume_tags = {
    Name              = "${var.project}-cn-${var.environment}-volume"
    Application       = var.project
    Description       = "Instance for ${var.project}"
    Starrocks_Backup  = "true"
  }
  root_block_device {
    volume_type = "standard"
    volume_size = var.cn_volume_size_gb
    encrypted   = "true"
  }
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  tags = {
    Name                 = "${var.project}-cn-${var.environment}-upgrade"
    Application          = "${var.project}-cn"
    Description          = "Instance for ${var.project}"
    Starrocks_Backup  = "true"
  }
}

# resource "aws_instance" "star_rocks_frontend_followers" {
#   count =  var.frontend_instance_count - 1 # Subtract the leader
#   ami                    = var.ami_id
#   instance_type          = var.monitoring_instance_type
#   user_data = templatefile("${path.module}/templates/frontend_startup.sh.tpl", {
#     starrocks_version        = var.star_rocks_upgrade_version != "" ? var.star_rocks_upgrade_version : var.star_rocks_version
#     starrocks_data_path = var.starrocks_data_path
#     region = var.region
#     bucket = "${var.starrocks_bucket}"
#     vpc_cidr = data.aws_vpc.target_vpc.cidr_block
#     java_heap_size_mb = var.frontend_heap_size
#     is_follower = "true"
#     leader_ip = aws_instance.star_rocks_frontend[0].private_ip
#   })
#   iam_instance_profile   = aws_iam_instance_profile.star_rocks_instance_profile.name
#   vpc_security_group_ids = [aws_security_group.star_rocks_sg.id]
#   subnet_id              = var.subnet_id
#   key_name               = var.ssh_key_name
#   ebs_optimized          = true
#   monitoring             = true
#   volume_tags = {
#     Name              = "${var.project}-fe-${var.environment}-volume"
#     Application       = var.project
#     Description       = "Instance for ${var.project}"
#     Starrocks_Backup  = "true"
#   }
#   root_block_device {
#     volume_type = "standard"
#     volume_size = var.frontend_volume_size_gb
#     encrypted   = "true"
#   }
#   metadata_options {
#     http_endpoint = "enabled"
#     http_tokens   = "required"
#   }
#   tags = {
#     Name                 = "${var.project}-fe-${var.environment}-upgrade"
#     Application          = "${var.project}-fe"
#     Description          = "Instance for ${var.project}"
#     Starrocks_Backup  = "true"
#   }
# }