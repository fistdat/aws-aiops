output "thing_group_name" {
  description = "Name of the Thing Group"
  value       = aws_iot_thing_group.this.name
}

output "thing_group_arn" {
  description = "ARN of the Thing Group"
  value       = aws_iot_thing_group.this.arn
}

output "thing_group_id" {
  description = "ID of the Thing Group"
  value       = aws_iot_thing_group.this.id
}
