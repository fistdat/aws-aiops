terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.10.0"
    }
  }
  backend "s3" {
    bucket = "aismc-platform-terraformstatefile-20251101-061100493617"
    key    = "aismc-dev/1.networking/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

provider "aws" {
  region = "ap-southeast-1"
  assume_role {
    role_arn = "arn:aws:iam::037776138283:role/aismc_dev_assume_role"
  }
}

