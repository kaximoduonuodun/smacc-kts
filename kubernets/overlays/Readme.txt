#更新k3s.yaml
#1：进入server节点，得到k3s的yaml，
sudo cat /etc/rancher/k3s/k3s.yaml

#2：copy ec2的k3s.yaml到当前目录的k3s.yaml里并且替换127.0.0.1为server的公网IP
cd D:\scripts\smacc-kts\kubernets\overlays

#3：替换windows本地的文件
kubectl 实际读的是config文件
cat .\k3s.yaml > "$env:USERPROFILE\.kube\config"
cat .\k3s.yaml > "$env:USERPROFILE\.kube\k3s.yaml"

#重启 DaemonSet（让新配置生效）
kubectl rollout restart daemonset/e2e-nuodun-otel-collector-agent -n observability

# 方式一：让 Collector 自己把默认配置结构打印出来（最权威）
kubectl run otel-check --rm -it --restart=Never \
  --image=otel/opentelemetry-collector-contrib:0.114.0 \
  --command -- sh -c 'cat /etc/otel-collector/... 2>/dev/null; \
  otelcol-contrib --help 2>&1 | head -40'

# 方式二（推荐）：用 Collector 的 validate 功能验证配置，
# 它会把错误定位到具体字段
kubectl run otel-validate --rm -it --restart=Never \
  --image=otel/opentelemetry-collector-contrib:0.114.0 \
  --volume=/tmp/check:/cfg \
  --command -- sh -c 'otelcol-contrib validate --config=/cfg/config.yaml'
# 把你当前的 config.yaml 挂进去，它会给出精确的字段错误

# 方式三：直接看这个版本的源码里的 config.go（最准）
# https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.114.0/receiver/hostmetricsreceiver/config.go

#持续监控耨个ns下的某个daemonset的pod状态
kubectl get pods -n observability -l app=otel-collector-agent -w

#造一条测试日志验证采集链路
kubectl run test-logger --image=busybox --restart=Never -- sh -c 'echo "TEST_LOG_$(date +%s)" && sleep 60'
# 等几秒后看 Collector 日志
kubectl logs -n observability -l app=otel-collector-agent | Select-String "TEST_LOG"
# 能看到说明采集链路完全通了

#设置默认namespace
kubectl config set-context --current --namespace=smc


#4：报错可以试试如下排查
环境变量有没有设：
$env:KUBECONFIG
应该输出C:\Users\nuodun\.kube\k3s.yaml
如果为空，就
$env:KUBECONFIG = "$env:USERPROFILE\.kube\k3s.yaml"

文件里 server 地址对不对：
Select-String -Path "$env:USERPROFILE\.kube\k3s.yaml" -Pattern "server:"

#powershell加别名
function kk { kubectl $args }


#看这次更新了什么内容
kubectl apply -k e2e --dry-run=client -o yaml
kubectl.exe kustomize e2e



#如何更新？   PyCharm 里改完 YAML，PowerShell 里：
kubectl kustomize ./k8s/overlays/dev        # 先看渲染出来长啥样
kubectl diff -k ./k8s/overlays/dev          # 和集群现有状态比一下
kubectl apply -k ./k8s/overlays/dev         # 应用
kubectl get pods

#秘决：先 kustomize 看渲染，再 diff，再 apply。
#Secret 别写明文进 git，用
kubectl create secret generic x --from-literal=... --dry-run=client -o yaml > base/secret.yaml。

核心逻辑链：
#base/configmap-agent.yaml
  → 生成 ConfigMap: otel-collector-agent-config
  → 里面 data.config.yaml 是 Collector 配置

base/daemonset-agent.yaml
  → volume "config" 引用这个 ConfigMap
  → mountPath: /etc/otel
  → Collector 启动参数: --config=/etc/otel/config.yaml
  → Collector 读到配置，开始按配置采集