# 保存为 check-otel.ps1

Write-Host "===== DaemonSet 状态 =====" -ForegroundColor Cyan
kubectl get daemonset -n observability

Write-Host "`n===== Pod 分布（确认每个节点一个）=====" -ForegroundColor Cyan
kubectl get pods -n observability -l app=otel-collector-agent -o wide

Write-Host "`n===== 节点资源使用 =====" -ForegroundColor Cyan
kubectl top nodes

Write-Host "`n===== Collector Pod 资源使用 =====" -ForegroundColor Cyan
kubectl top pods -n observability -l app=otel-collector-agent

Write-Host "`n===== Collector 日志（最近 20 行）=====" -ForegroundColor Cyan
kubectl logs -n observability -l app=otel-collector-agent --tail=20