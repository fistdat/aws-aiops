provider "aws" {
  alias   = "aismc-devops"
  #profile = "aismc-devops"
  region  = "ap-southeast-1"
}

provider "aws" {
  alias   = "aismc-dev"
  #profile = "aismc-dev"
  region  = "ap-southeast-1"
}

data "aws_caller_identity" "aismc_devops" {
  provider = aws.aismc-devops
}

data "aws_iam_policy" "aismc_dev_policy" {
  provider = aws.aismc-dev
  name     = "AdministratorAccess"
}

data "aws_iam_policy_document" "aismc_dev_assume_role" {
  provider = aws.aismc-dev
  statement {
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
      "sts:SetSourceIdentity"
    ]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.aismc_devops.account_id}:root"]
    }
  }
}

resource "aws_iam_role" "aismc_dev_assume_role" {
  provider           = aws.aismc-dev
  name               = "aismc_dev_assume_role"
  assume_role_policy = data.aws_iam_policy_document.aismc_dev_assume_role.json
  tags               = {}
}

# Gắn policy vào role (mỗi policy một attachment)
resource "aws_iam_role_policy_attachment" "aismc_dev_attach" {
  provider   = aws.aismc-dev
  role       = aws_iam_role.aismc_dev_assume_role.name
  policy_arn = data.aws_iam_policy.aismc_dev_policy.arn
}

