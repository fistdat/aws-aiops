output "policy_name" {
  description = "Name of the IoT Policy"
  value       = aws_iot_policy.this.name
}

output "policy_arn" {
  description = "ARN of the IoT Policy"
  value       = aws_iot_policy.this.arn
}
