# VM-1 重要網路行為更新 🔄

**發現日期**: $(date)
**重要性**: ⚠️ 必須閱讀 - 影響 VM-1 連接配置

---

## 🔍 重要發現：ping 失敗但 curl 成功的原因

經過詳細測試，我們發現了一個重要的網路行為模式：

### ✅ **實際可用的連接方式**
```bash
# 這些方式都能正常工作：
curl http://172.16.0.89:30090/health          # ✅ 成功
curl http://172.16.0.89:30090/metrics/api/v1/slo  # ✅ 成功
nc -z 172.16.0.89 30090                       # ✅ 成功
telnet 172.16.0.89 30090                      # ✅ 成功
```

### ❌ **不可用的連接方式**
```bash
# 這些方式會失敗：
ping 172.16.0.89                              # ❌ 失敗 (ICMP 被阻擋)
ping 147.251.115.193                          # ❌ 失敗 (外網 IP 問題)
curl http://147.251.115.193:30090/health      # ❌ 失敗 (外網路由問題)
```

---

## 📋 **VM-1 正確的連接配置**

### 更新 postcheck.sh 配置
```bash
# ✅ 正確配置 (使用內網 IP)
declare -A SITES=(
    [edge1]="172.16.4.45:30090/metrics/api/v1/slo"
    [edge2]="172.16.0.89:30090/metrics/api/v1/slo"    # 使用內網 IP
)

declare -A O2IMS_SITES=(
    [edge1]="http://172.16.4.45:31280/o2ims/measurement/v1/slo"
    [edge2]="http://172.16.0.89:31280/o2ims/measurement/v1/slo"  # 使用內網 IP
)
```

### VM-1 驗證腳本更新
```bash
# 更新測試腳本以反映實際網路行為
cat > ~/vm1_verify_edge2.sh << 'EOF'
#!/bin/bash
EDGE2_IP="172.16.0.89"  # 使用內網 IP
EDGE2_PORT="30090"

echo "🧪 VM-1 到 VM-4 Edge2 連通性測試"
echo "目標: ${EDGE2_IP}:${EDGE2_PORT}"
echo ""

# 跳過 ping 測試 (已知會失敗)
echo "⏩ 跳過 ping 測試 (ICMP 被防火牆阻擋，這是正常的)"

# 直接測試 HTTP 連接
echo "🔗 測試 HTTP 連接..."
if curl -s --max-time 10 http://${EDGE2_IP}:${EDGE2_PORT}/health >/dev/null; then
    echo "   ✅ HTTP 連接成功"
else
    echo "   ❌ HTTP 連接失敗"
    exit 1
fi

# 測試 SLO 數據獲取
echo "📊 測試 SLO 數據獲取..."
SLO_DATA=$(curl -s --max-time 10 http://${EDGE2_IP}:${EDGE2_PORT}/metrics/api/v1/slo)
if echo "$SLO_DATA" | jq . >/dev/null 2>&1; then
    echo "   ✅ SLO 數據獲取成功"
    echo "   📈 當前指標預覽:"
    echo "$SLO_DATA" | jq '.slo | {latency_p95_ms, success_rate, site: .site}'
else
    echo "   ❌ SLO 數據獲取失敗"
    exit 1
fi

echo ""
echo "🎉 VM-4 Edge2 連通性驗證通過！"
echo "📝 建議：更新 postcheck.sh 使用內網 IP: ${EDGE2_IP}"
EOF

chmod +x ~/vm1_verify_edge2.sh
EOF