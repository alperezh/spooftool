resource "aws_s3_bucket" "backups" {
  bucket = "dmarcdefense-backups-${var.environment}"

  tags = {
    Name        = "DMARCDefense Backups"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "backups_lifecycle" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "daily-backups"
    status = "Enabled"

    filter {
      prefix = "daily/"
    }

    expiration {
      days = 30
    }
  }

  rule {
    id     = "weekly-backups"
    status = "Enabled"

    filter {
      prefix = "weekly/"
    }

    expiration {
      days = 90
    }
  }

  rule {
    id     = "monthly-backups"
    status = "Enabled"

    filter {
      prefix = "monthly/"
    }

    expiration {
      days = 365
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups_encryption" {
  bucket = aws_s3_bucket.backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
