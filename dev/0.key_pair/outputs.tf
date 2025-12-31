output "key_pair_name" {
  description = "Name of the EC2 Key Pair"
  value       = aws_key_pair.this.key_name
}

output "key_pair_id" {
  description = "ID of the EC2 Key Pair"
  value       = aws_key_pair.this.id
}

output "private_key_pem" {
  description = "Private key in PEM format"
  value       = tls_private_key.this.private_key_pem
  sensitive   = true
}

output "public_key_openssh" {
  description = "Public key in OpenSSH format"
  value       = tls_private_key.this.public_key_openssh
}

