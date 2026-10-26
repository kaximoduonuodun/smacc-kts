$ErrorActionPreference = "Stop"

Write-Host "=== 备份 state ===" -ForegroundColor Cyan
Copy-Item terraform.tfstate terraform.tfstate.backup -Force

Write-Host "=== 开始 mv VPC ===" -ForegroundColor Green
terraform state mv aws_vpc.this module.vpc.aws_vpc.this
terraform state mv 'aws_subnet.public[0]' 'module.vpc.aws_subnet.public[0]'
terraform state mv 'aws_subnet.public[1]' 'module.vpc.aws_subnet.public[1]'
terraform state mv 'aws_subnet.public[2]' 'module.vpc.aws_subnet.public[2]'
terraform state mv aws_internet_gateway.this module.vpc.aws_internet_gateway.this
terraform state mv aws_route_table.public module.vpc.aws_route_table.public
terraform state mv aws_route.public_internet module.vpc.aws_route.public_internet
terraform state mv 'aws_route_table_association.public[0]' 'module.vpc.aws_route_table_association.public[0]'
terraform state mv 'aws_route_table_association.public[1]' 'module.vpc.aws_route_table_association.public[1]'
terraform state mv 'aws_route_table_association.public[2]' 'module.vpc.aws_route_table_association.public[2]'

Write-Host "=== 开始 mv Security Groups ===" -ForegroundColor Green
terraform state mv aws_security_group.k3s module.security_groups.aws_security_group.k3s

Write-Host "=== 开始 mv IAM ===" -ForegroundColor Green
terraform state mv aws_iam_role.k3s_node module.iam.aws_iam_role.k3s_node
terraform state mv aws_iam_role_policy.k3s_node_ecr module.iam.aws_iam_role_policy.k3s_node_ecr
terraform state mv aws_iam_instance_profile.k3s_node module.iam.aws_iam_instance_profile.k3s_node
terraform state mv aws_iam_role.ssm_role module.iam.aws_iam_role.ssm_role
terraform state mv aws_iam_role_policy_attachment.ssm_managed_core module.iam.aws_iam_role_policy_attachment.ssm_managed_core
terraform state mv aws_iam_instance_profile.ssm_profile module.iam.aws_iam_instance_profile.ssm_profile

Write-Host "=== 开始 mv ECR ===" -ForegroundColor Green
terraform state mv aws_ecr_repository.java_base module.ecr.aws_ecr_repository.java_base
terraform state mv 'aws_ecr_repository.smc-kts' 'module.ecr.aws_ecr_repository.smc_kts'
terraform state mv aws_ecr_lifecycle_policy.keep_recent module.ecr.aws_ecr_lifecycle_policy.keep_recent

Write-Host "=== 开始 mv Cluster (如果 aws_instance 存在) ===" -ForegroundColor Green
$state = terraform state list
if ($state -match "aws_instance.server") {
    terraform state mv aws_instance.server module.cluster.aws_instance.server
}
if ($state -match "aws_instance.agent\[0\]") {
    terraform state mv 'aws_instance.agent[0]' 'module.cluster.aws_instance.agent[0]'
}
if ($state -match "aws_instance.agent\[1\]") {
    terraform state mv 'aws_instance.agent[1]' 'module.cluster.aws_instance.agent[1]'
}

Write-Host "=== 开始 mv Data Sources ===" -ForegroundColor Green
if ($state -match "data.aws_ami.ubuntu") {
    terraform state mv data.aws_ami.ubuntu module.cluster.data.aws_ami.ubuntu
}
if ($state -match "data.aws_caller_identity.current") {
    terraform state mv data.aws_caller_identity.current module.iam.data.aws_caller_identity.current
}

Write-Host "=== mv 完成，验证 ===" -ForegroundColor Cyan
terraform state list

Write-Host "=== 跑 plan 验证 ===" -ForegroundColor Cyan
terraform plan