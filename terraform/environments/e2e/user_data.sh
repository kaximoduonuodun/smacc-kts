
#!/bin/bash
set -e

echo "=== User data script started at $(date) ===" > /var/log/user-data.log

# 更新系统
dnf update -y >> /var/log/user-data.log 2>&1

# 安装 Java 21
dnf install -y java-21-amazon-corretto-headless >> /var/log/user-data.log 2>&1

# 验证
java -version >> /var/log/user-data.log 2>&1

# 占位：你的 Java 应用启动逻辑
mkdir -p /opt/app
echo "Java installed, waiting for app deployment" > /opt/app/status.txt

echo "=== User data script finished at $(date) ===" >> /var/log/user-data.log