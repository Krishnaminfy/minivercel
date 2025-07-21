output "public_ip" {
  value       = aws_instance.app_ec2.public_ip
  description = "Public IP of the EC2 instance"
}

output "url" {
  value       = "http://${aws_instance.app_ec2.public_ip}"
  description = "Application public access URL"
}
