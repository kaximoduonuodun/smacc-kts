output "server_ip" {
  value = aws_instance.server.public_ip
}

output "agent_ips" {
  value = aws_instance.agent[*].public_ip
}
