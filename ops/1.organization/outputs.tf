output "organization_id" {
  description = "ID of the AWS Organization"
  value       = aws_organizations_organization.main.id
}

output "organization_arn" {
  description = "ARN of the AWS Organization"
  value       = aws_organizations_organization.main.arn
}

output "dev_account_id" {
  description = "ID of the development account"
  value       = aws_organizations_account.dev.id
}

output "dev_account_arn" {
  description = "ARN of the development account"
  value       = aws_organizations_account.dev.arn
}

output "development_ou_id" {
  description = "ID of the Development Organizational Unit"
  value       = aws_organizations_organizational_unit.development.id
}

output "production_ou_id" {
  description = "ID of the Production Organizational Unit"
  value       = aws_organizations_organizational_unit.production.id
}
