# terraform/backup.tf

resource "aws_s3_bucket" "backups" {
  bucket = "dmarcdefense-backups-${var.environment}"

  tags = {
    Name        = "DMARCDefense Backups"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_ownership_controls" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "backups" {
  depends_on = [aws_s3_bucket_ownership_controls.backups]
  bucket     = aws_s3_bucket.backups.id
  acl        = "private"
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
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
    // Los mensuales se guardan por un año
    expiration {
      days = 365
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
