# Terraform 模块化项目

把原来的单文件 `main.tf` 拆成 `modules/` + `envs/{e2e,prod}/` 结构，
state 存进 S3（KMS 加密 + DynamoDB 锁），权限走 IAM AssumeRole。

## 目录结构

```
terraform-infra/
├── bootstrap/                    # 一次性引导：建 S3 state 桶 + KMS + 锁表 + IAM 角色
│   ├── main.tf
│   ├── variables.tf
│   └── terraform.tfvars
├── modules/                      # 可复用资源模块
│   ├── vpc/
│   ├── iam/
│   ├── ecr/
│   └── k3s-cluster/
├── envs/
│   ├── e2e/                      # e2e 环境
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── e2e.tfvars
│   │   └── backend.conf
│   └── prod/                     # prod 环境（规格更高，多告警）
│       ├── main.tf
│       ├── variables.tf
│       ├── prod.tfvars
│       └── backend.conf
├── .gitignore
└── README.md
```

## 第一次使用：按顺序执行

### 第 1 步：配置本地 AWS profile（只做一次）

编辑 `~/.aws/credentials` 和 `~/.aws/config`，配好 AssumeRole。
确认能代入 `TerraformAdmin` 和 `TerraformStateAdmin` 两个角色。

### 第 2 步：跑 bootstrap（建 state 基础设施）

```bash
cd bootstrap

# 修改 terraform.tfvars 里的三行：
#   aws_profile         -> 本地 profile 名
#   state_bucket_name   -> 改成全球唯一的桶名
#   terraform_user_arn  -> 本地 IAM 用户 ARN

terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

执行完会输出：
- S3 桶名
- DynamoDB 锁表名
- KMS key ARN
- 两个角色 ARN

**把输出的桶名和锁表名填进 `envs/e2e/backend.conf` 和 `envs/prod/backend.conf`。**

### 第 3 步：部署 e2e 环境

```bash
cd envs/e2e

# 修改 e2e.tfvars 里的 key_name，改成你 AWS 上的 key pair 名
# 确保 aws_profile = "terraform-admin"

terraform init -backend-config=backend.conf
terraform plan -var-file=e2e.tfvars
terraform apply -var-file=e2e.tfvars
```

### 第 4 步：部署 prod 环境

```bash
cd ../prod

# 同样修改 prod.tfvars 的 key_name

terraform init -backend-config=backend.conf
terraform plan -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars
```

## 日常使用

```bash
# 只做 plan（本地，安全）
cd envs/e2e
terraform plan -var-file=e2e.tfvars

# 真正变更（apply 建议通过 CI 执行，本地角色无 state 桶权限）
terraform apply -var-file=e2e.tfvars
```

## 注意事项

1. `key_name` 必须改成你 AWS 账号上真实存在的 Key Pair 名称，否则 apply 会报错
2. `state_bucket_name` 必须全球唯一，别人用过就不行
3. `terraform_user_arn` 必须和你本地 IAM 用户 ARN 一致
4. bootstrap 建完之后，日常不要再动它
5. K3s token 现在存在 SSM Parameter Store 里（SecureString），不再明文写在代码里
