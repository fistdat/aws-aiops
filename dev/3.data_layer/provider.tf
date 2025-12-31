terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "aismc-platform-terraformstatefile-20251101-061100493617"
    key    = "aismc-dev/3.data_layer/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

provider "aws" {
  region = "ap-southeast-1"

  default_tags {
    tags = local.tags
  }
}
