output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "k3s_server_ip" {
  value = module.cluster.server_ip
}

output "k3s_agent_ips" {
  value = module.cluster.agent_ips
}