resource "aws_iam_role" "star_rocks_role" {
  name        = "${var.project}-${var.environment}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "s3_policy" {
  name        = "${var.project}-${var.environment}-s3-policy"
  description = "Allows Star Rocks EC2 instances to access S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject",
          "s3:GetBucketTagging",
          "s3:PutBucketTagging",
          "s3:GetObjectTagging",
          "s3:PutObjectTagging",
          "s3:DeleteObjectTagging",
          "s3:GetObjectVersion",
          "s3:DeleteObjectVersion",
          "s3:ListBucketVersions"
        ]
        Resource = [
          "arn:aws:s3:::${var.starrocks_bucket}",
          "arn:aws:s3:::${var.starrocks_bucket}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_attach" {
  role       = aws_iam_role.star_rocks_role.name
  policy_arn = aws_iam_policy.s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role = aws_iam_role.star_rocks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "additional_policy_attachments" {
  for_each = toset(var.additional_policy_arns)

  role       = aws_iam_role.star_rocks_role.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "star_rocks_instance_profile" {
  name = "${var.project}-${var.environment}-ip"
  role = aws_iam_role.star_rocks_role.name
}

resource "aws_iam_role" "monitoring_role" {
  name        = "${var.project}-${var.environment}-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "monitoring_policy" {
  name        = "${var.project}-${var.environment}-monitoring-policy"
  description = "Allows Star Rocks monitoring"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:GetMetricData",
          "ec2:DescribeTags",
          "ec2:DescribeInstances",
          "ec2:DescribeRegions"
        ]
        Resource = [
          "*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectTagging",
          "s3:GetObjectVersion",
          "s3:GetBucketTagging"
        ]
        Resource = [
          "arn:aws:s3:::${var.starrocks_bucket}",
          "arn:aws:s3:::${var.starrocks_bucket}/dashboards/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${aws_secretsmanager_secret.grafana_admin_pw.name}*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "monitoring_attach" {
  role       = aws_iam_role.monitoring_role.name
  policy_arn = aws_iam_policy.monitoring_policy.arn
}

resource "aws_iam_role_policy_attachment" "monitoring_ssm_attach" {
  role = aws_iam_role.monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "monitoring_instance_profile" {
  name = "${var.project}-${var.environment}-monitoring-ip"
  role = aws_iam_role.monitoring_role.name
}

resource "aws_iam_role" "dlm_role" {
  name = "dlm-snapshot-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "dlm.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "dlm_attach" {
  role       = aws_iam_role.dlm_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
}
