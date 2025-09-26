# Three-VM Integration Implementation Plan
## VM-1, VM-2, VM-4 Unified Architecture

**Date:** 2025-09-25
**Status:** EXECUTION READY

---

## 🎯 Mission Objectives

Transform the current multi-VM architecture into a unified, Claude-driven orchestration platform:
- **VM-1**: Central orchestrator with integrated Claude CLI headless mode
- **VM-2**: Edge1 site with GitOps pull and local SLO validation
- **VM-4**: Edge2 site with GitOps pull and local SLO validation
- **Eliminate VM-3**: Integrate LLM capabilities directly into VM-1

---

## 📊 Current State Analysis

### VM Status
| VM | Role | IP | Claude | Templates | CLAUDE.md | Status |
|----|------|-----|--------|-----------|-----------|--------|
| VM-1 | Orchestrator | 172.16.0.78 | ✅ Installed | ✅ Present | ✅ Orchestrator version | Ready |
| VM-2 | Edge1 | 172.16.4.45 | ❌ Not installed | ✅ Present | ✅ Edge version | Partial |
| VM-4 | Edge2 | 172.16.4.176 | ❌ Not installed | ❌ Missing | ❌ Missing | Not Ready |

### Key Findings
1. VM-2 has Edge-specific CLAUDE.md with GitOps pull configuration
2. VM-4 lacks the entire nephio-intent-to-o2-demo directory
3. Claude CLI needs to be installed on edge sites
4. Templates are consistent between VM-1 and VM-2

---

## 🏗️ Architecture Design

```
┌─────────────────────────────────────────────────────┐
│                    VM-1 (172.16.0.78)               │
│                 Central Orchestrator                 │
│                                                      │
│  ┌─────────────────────────────────────────────┐   │
│  │ Claude CLI Headless Service                  │   │
│  │ claude -p "{prompt}" --output-format json    │   │
│  └─────────────────────────────────────────────┘   │
│                        ↓                            │
│  ┌─────────────────────────────────────────────┐   │
│  │ Intent → KRM Pipeline                        │   │
│  │ kpt render + Porch PackageVariant            │   │
│  └─────────────────────────────────────────────┘   │
│                        ↓                            │
│  ┌─────────────────────────────────────────────┐   │
│  │ Gitea Repository (port 8888)                 │   │
│  │ /clusters/edge01/ and /clusters/edge02/      │   │
│  └─────────────────────────────────────────────┘   │
│                        ↓                            │
│  ┌─────────────────────────────────────────────┐   │
│  │ Thanos Receive / VictoriaMetrics             │   │
│  │ Central TSDB for all edge metrics            │   │
│  └─────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
                         ↓
        ┌────────────────┴────────────────┐
        ↓                                  ↓
┌───────────────────────┐         ┌───────────────────────┐
│   VM-2 (172.16.4.45)  │         │  VM-4 (172.16.4.176)  │
│       Edge1 Site      │         │      Edge2 Site       │
├───────────────────────┤         ├───────────────────────┤
│ Config Sync Agent     │         │ Config Sync Agent     │
│ ↓ Pull from Gitea     │         │ ↓ Pull from Gitea     │
│ Flagger Canary        │         │ Flagger Canary        │
│ Prometheus + Remote   │         │ Prometheus + Remote   │
│ Claude (validation)   │         │ Claude (validation)   │
└───────────────────────┘         └───────────────────────┘
```

---

## 📋 Implementation Tasks

### Phase 1: VM-4 Bootstrap [Immediate]

```bash
# 1.1 Create project directory on VM-4
ssh ubuntu@172.16.4.176 "mkdir -p /home/ubuntu/nephio-intent-to-o2-demo"

# 1.2 Copy essential files from VM-1 to VM-4
scp -r /home/ubuntu/nephio-intent-to-o2-demo/templates ubuntu@172.16.4.176:/home/ubuntu/nephio-intent-to-o2-demo/

# 1.3 Create VM-4 specific CLAUDE.md
cat > /tmp/CLAUDE_VM4.md << 'EOF'
# VM-4／Edge2 站點：CLAUDE.md（完整版）

## 角色與邊界
- 從 Gitea 指定目錄拉取宣告式設定（GitOps Pull）
- 本地 Prometheus 蒐集指標；以 remote_write 匯出到 VM-1（Thanos/VM）
- 以 Flagger 或 Argo Rollouts 做 Canary/自動回滾（SLO 守門）

## 必裝組件
- GitOps Agent（Config Sync 或 Argo/Flux）
- Prometheus + exporters（node/kube/cAdvisor/UPF/SMF 等）
- Flagger（或 Argo Rollouts）
- （可選）Alertmanager

## 檔案對照
- `templates/configsync-root.yaml`：若採用 Config Sync，請改 `dir=clusters/edge02`
- `templates/flagger-canary.yaml`：Flagger Canary 例
- `templates/analysis-template.yaml`：Argo Rollouts AnalysisTemplate 例
- `templates/prometheus-remote-write.yaml`：Prometheus 匯出設定

## Claude Code（headless）提示詞

### E0｜初始化站點
```bash
claude -p '產出一份 Config Sync RootSync：
repo=https://172.16.0.78:8888/nephio/deployments.git
branch=main
dir=clusters/edge02
只輸出 YAML。'
```
EOF

scp /tmp/CLAUDE_VM4.md ubuntu@172.16.4.176:/home/ubuntu/nephio-intent-to-o2-demo/CLAUDE.md
```

### Phase 2: Claude CLI Installation [All VMs]

```bash
# 2.1 Install Claude on VM-2
ssh ubuntu@172.16.4.45 << 'EOF'
npm install -g @anthropic-ai/claude-cli
claude --dangerously-skip-permissions
EOF

# 2.2 Install Claude on VM-4
ssh ubuntu@172.16.4.176 << 'EOF'
npm install -g @anthropic-ai/claude-cli
claude --dangerously-skip-permissions
EOF

# 2.3 Verify Claude on VM-1 headless mode
claude -p 'echo "test"' --output-format stream-json
```

### Phase 3: VM-1 Claude Headless Integration

```python
# 3.1 Create Claude Headless Service
cat > /home/ubuntu/nephio-intent-to-o2-demo/services/claude_headless.py << 'EOF'
#!/usr/bin/env python3
import subprocess
import json
import asyncio
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Dict, Any, Optional
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Claude Headless Service")

class IntentRequest(BaseModel):
    text: str
    context: Optional[Dict[str, Any]] = None

class ClaudeHeadlessService:
    def __init__(self):
        self.claude_path = "/home/ubuntu/.npm-global/bin/claude"
        self.timeout = 30

    async def process_intent(self, prompt: str) -> Dict[str, Any]:
        """Process intent using Claude CLI in headless mode"""

        # Build headless command
        cmd = [
            self.claude_path,
            "-p", prompt,
            "--output-format", "stream-json",
            "--dangerously-skip-permissions"
        ]

        try:
            # Execute Claude CLI
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )

            stdout, stderr = await asyncio.wait_for(
                process.communicate(),
                timeout=self.timeout
            )

            if process.returncode != 0:
                logger.error(f"Claude CLI error: {stderr.decode()}")
                raise HTTPException(status_code=500, detail="Claude processing failed")

            # Parse JSON response
            response = json.loads(stdout.decode())
            return response

        except asyncio.TimeoutError:
            raise HTTPException(status_code=408, detail="Claude processing timeout")
        except json.JSONDecodeError as e:
            logger.error(f"JSON parse error: {e}")
            raise HTTPException(status_code=500, detail="Invalid JSON response")

service = ClaudeHeadlessService()

@app.post("/api/v1/intent")
async def process_intent(request: IntentRequest):
    """Process natural language intent"""

    # Build TMF921 prompt
    prompt = f"""
    Convert to TMF921 intent format:
    {request.text}

    Context: {json.dumps(request.context) if request.context else 'None'}

    Return only valid JSON with fields:
    - intentId
    - intentType (eMBB/URLLC/mMTC)
    - targetSites (list of edge01/edge02)
    - parameters (bandwidth, latency, etc.)
    - sloRequirements
    """

    result = await service.process_intent(prompt)
    return result

@app.get("/health")
def health_check():
    return {"status": "healthy", "mode": "headless", "claude": "integrated"}
EOF

# 3.2 Create systemd service
sudo tee /etc/systemd/system/claude-headless.service << 'EOF'
[Unit]
Description=Claude Headless Intent Service
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/nephio-intent-to-o2-demo
ExecStart=/usr/bin/python3 /home/ubuntu/nephio-intent-to-o2-demo/services/claude_headless.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable claude-headless
sudo systemctl start claude-headless
```

### Phase 4: GitOps Configuration for Edge Sites

```bash
# 4.1 Create edge1 Config Sync (VM-2)
ssh ubuntu@172.16.4.45 << 'EOF'
cat > /tmp/rootsync-edge1.yaml << 'YAML'
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: edge1-sync
  namespace: config-management-system
spec:
  sourceFormat: unstructured
  git:
    repo: http://172.16.0.78:8888/nephio/deployments.git
    branch: main
    dir: clusters/edge01
    auth: token
    secretRef:
      name: gitea-token
YAML

kubectl apply -f /tmp/rootsync-edge1.yaml
EOF

# 4.2 Create edge2 Config Sync (VM-4)
ssh ubuntu@172.16.4.176 << 'EOF'
cat > /tmp/rootsync-edge2.yaml << 'YAML'
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: edge2-sync
  namespace: config-management-system
spec:
  sourceFormat: unstructured
  git:
    repo: http://172.16.0.78:8888/nephio/deployments.git
    branch: main
    dir: clusters/edge02
    auth: token
    secretRef:
      name: gitea-token
YAML

kubectl apply -f /tmp/rootsync-edge2.yaml
EOF
```

### Phase 5: Prometheus Remote Write Configuration

```bash
# 5.1 Configure VM-2 Prometheus
ssh ubuntu@172.16.4.45 << 'EOF'
cat >> /etc/prometheus/prometheus.yml << 'YAML'

remote_write:
  - url: http://172.16.0.78:10908/api/v1/receive
    queue_config:
      max_samples_per_send: 1000
      max_shards: 10
    metadata_config:
      send: true
      send_interval: 30s
    write_relabel_configs:
      - source_labels: [__name__]
        regex: '.*'
        target_label: edge_site
        replacement: 'edge01'
YAML

systemctl restart prometheus
EOF

# 5.2 Configure VM-4 Prometheus
ssh ubuntu@172.16.4.176 << 'EOF'
cat >> /etc/prometheus/prometheus.yml << 'YAML'

remote_write:
  - url: http://172.16.0.78:10908/api/v1/receive
    queue_config:
      max_samples_per_send: 1000
      max_shards: 10
    metadata_config:
      send: true
      send_interval: 30s
    write_relabel_configs:
      - source_labels: [__name__]
        regex: '.*'
        target_label: edge_site
        replacement: 'edge02'
YAML

systemctl restart prometheus
EOF
```

### Phase 6: Flagger Installation for Progressive Delivery

```bash
# 6.1 Install Flagger on VM-2
ssh ubuntu@172.16.4.45 << 'EOF'
kubectl apply -k github.com/fluxcd/flagger//kustomize/kubernetes
kubectl -n flagger-system set image deployment/flagger flagger=ghcr.io/fluxcd/flagger:1.33.0

# Apply Flagger webhook for SLO validation
kubectl apply -f /home/ubuntu/nephio-intent-to-o2-demo/templates/flagger-canary.yaml
EOF

# 6.2 Install Flagger on VM-4
ssh ubuntu@172.16.4.176 << 'EOF'
kubectl apply -k github.com/fluxcd/flagger//kustomize/kubernetes
kubectl -n flagger-system set image deployment/flagger flagger=ghcr.io/fluxcd/flagger:1.33.0

# Apply Flagger webhook for SLO validation
kubectl apply -f /home/ubuntu/nephio-intent-to-o2-demo/templates/flagger-canary.yaml
EOF
```

---

## 🧪 Validation Tests

### Test 1: Claude Headless on VM-1
```bash
curl -X POST http://localhost:8000/api/v1/intent \
  -H "Content-Type: application/json" \
  -d '{"text": "Deploy eMBB on edge1 and edge2 with 200Mbps"}'
```

### Test 2: GitOps Sync Verification
```bash
# Check VM-2 sync status
ssh ubuntu@172.16.4.45 "kubectl get rootsync -n config-management-system"

# Check VM-4 sync status
ssh ubuntu@172.16.4.176 "kubectl get rootsync -n config-management-system"
```

### Test 3: Prometheus Remote Write
```bash
# Query Thanos on VM-1 for edge metrics
curl http://172.16.0.78:10902/api/v1/query?query=up{edge_site="edge01"}
curl http://172.16.0.78:10902/api/v1/query?query=up{edge_site="edge02"}
```

### Test 4: End-to-End Intent Deployment
```bash
# Submit intent on VM-1
./scripts/nl_interface.sh << 'EOF'
deploy eMBB slice on all edges with 200Mbps bandwidth and 30ms latency
EOF

# Monitor deployment progress
watch kubectl get deployments -A --context=edge1
watch kubectl get deployments -A --context=edge2
```

---

## 🚦 Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Claude Response Time | < 2s | Time from prompt to JSON |
| GitOps Sync Interval | < 1min | Config change to edge apply |
| Prometheus Scrape | 100% | All edge metrics in Thanos |
| Canary Success Rate | > 95% | Successful promotions |
| E2E Intent Deploy | < 5min | Intent to running workload |

---

## 📅 Timeline

| Phase | Duration | Status |
|-------|----------|--------|
| VM-4 Bootstrap | 30 min | 🔄 Starting |
| Claude Installation | 1 hour | ⏸️ Pending |
| Headless Integration | 2 hours | ⏸️ Pending |
| GitOps Setup | 1 hour | ⏸️ Pending |
| Monitoring Config | 1 hour | ⏸️ Pending |
| Testing & Validation | 2 hours | ⏸️ Pending |
| **Total** | **7.5 hours** | **In Progress** |

---

## 🎯 Expected Outcomes

1. **Unified Control Plane**: VM-1 orchestrates all edge sites via GitOps
2. **Automated Intent Processing**: Natural language → KRM → Edge deployment
3. **Progressive Delivery**: Automatic canary with SLO-based promotion
4. **Centralized Observability**: All metrics flow to VM-1 Thanos
5. **Zero-Touch Edge**: Edge sites self-manage via GitOps pull

---

## 🚨 Rollback Plan

If any phase fails:
1. Stop the failed service/component
2. Restore previous configuration from backup
3. Verify system stability
4. Document failure reason
5. Adjust plan and retry

---

*This plan integrates all three VMs into a cohesive, Claude-driven orchestration platform with GitOps, progressive delivery, and centralized monitoring.*