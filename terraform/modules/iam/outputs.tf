output "k3s_instance_profile_name" {
  value = aws_iam_instance_profile.k3s_node.name
}

output "ssm_instance_profile_name" {
  value = aws_iam_instance_profile.ssm_profile.name
}