resource "aws_dlm_lifecycle_policy" "ebs_snapshots" {
  description        = "Daily snapshot for StarRocks EBS root volumes"
  execution_role_arn = aws_iam_role.dlm_role.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]
    target_tags = {
      Starrocks_Backup = "true"
    }

    schedule {
      name = "daily-snapshot"

      tags_to_add = {
        Snapshot = "true"
      }

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["05:00"] # UTC time
      }

      retain_rule {
        count = 7  # Keep last 7 snapshots
      }

      copy_tags = true
    }
  }
}
