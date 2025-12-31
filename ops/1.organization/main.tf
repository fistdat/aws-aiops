resource "aws_organizations_organization" "main" {
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "iot.amazonaws.com"
  ]

  feature_set = "ALL"

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
  ]
}

# Development Account
resource "aws_organizations_account" "dev" {
  name      = "${local.product_name}-dev"
  email     = var.dev_account_email
  role_name = "OrganizationAccountAccessRole"

  tags = merge(local.tags, {
    Environment = "dev"
    Purpose     = "Development and Testing"
  })

  lifecycle {
    prevent_destroy = true
  }
}

# Production Account (for future use)
# Uncomment when ready to create prod account
# resource "aws_organizations_account" "prod" {
#   name      = "${local.product_name}-prod"
#   email     = var.prod_account_email
#   role_name = "OrganizationAccountAccessRole"
#
#   tags = merge(local.tags, {
#     Environment = "prod"
#     Purpose     = "Production Workloads"
#   })
#
#   lifecycle {
#     prevent_destroy = true
#   }
# }

# Organizational Unit for Development
resource "aws_organizations_organizational_unit" "development" {
  name      = "Development"
  parent_id = aws_organizations_organization.main.roots[0].id

  tags = local.tags
}

# Organizational Unit for Production (future)
resource "aws_organizations_organizational_unit" "production" {
  name      = "Production"
  parent_id = aws_organizations_organization.main.roots[0].id

  tags = local.tags
}

# Service Control Policy - Prevent account leaving organization
resource "aws_organizations_policy" "prevent_leave" {
  name        = "PreventAccountLeaving"
  description = "Prevent accounts from leaving the organization"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Deny"
        Action   = "organizations:LeaveOrganization"
        Resource = "*"
      }
    ]
  })

  tags = local.tags
}

# Attach SCP to organization root
resource "aws_organizations_policy_attachment" "prevent_leave_root" {
  policy_id = aws_organizations_policy.prevent_leave.id
  target_id = aws_organizations_organization.main.roots[0].id
}
