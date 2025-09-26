# VM-1 Integrated LLM Architecture Design
## Intent-to-O2 with Claude Code CLI Integration

### Executive Summary

This document outlines the architectural redesign for integrating LLM capabilities directly into VM-1 using Claude Code CLI, eliminating the need for VM-3. The design includes service abstraction layers, API interfaces, frontend UI, and real-time monitoring capabilities.

---

## 1. Architecture Overview

### 1.1 Current vs. Proposed Architecture

**Current Architecture:**
```
User → VM-1 → VM-3 (LLM) → VM-1 → Edge Sites (VM-2/4)
```

**Proposed Integrated Architecture:**
```
User → [Frontend UI] → VM-1 [Integrated Stack] → Edge Sites (VM-2/4)
                            ├── LLM Service Layer
                            ├── Orchestration Layer
                            └── Monitoring Layer
```

### 1.2 Layered Architecture Design

```
┌─────────────────────────────────────────────────────────┐
│                   Presentation Layer                     │
│         (Web UI, CLI, API Clients, Mobile App)          │
└────────────────────────┬────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────┐
│                    API Gateway Layer                     │
│     (REST API, WebSocket, GraphQL, Authentication)      │
└────────────────────────┬────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────┐
│                  Service Abstraction Layer               │
├──────────────────┬──────────────┬───────────────────────┤
│   LLM Service    │ Orchestrator │   Monitor Service     │
│  (Claude Wrapper)│   Service    │  (Real-time Events)   │
└──────────────────┴──────────────┴───────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────┐
│                   Core Processing Layer                  │
├──────────────────┬──────────────┬───────────────────────┤
│  Claude Code CLI │  KRM Engine  │   GitOps Manager      │
│    (tmux/daemon) │ (kpt render) │  (Git Operations)     │
└──────────────────┴──────────────┴───────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────┐
│                  Infrastructure Layer                    │
│          (Kubernetes, Edge Sites, O2IMS)                │
└──────────────────────────────────────────────────────────┘
```

---

## 2. LLM Service Layer Design

### 2.1 Claude Code CLI Service Wrapper

We propose three implementation approaches:

#### Option A: Tmux Session Manager (Recommended)

```python
# claude_service.py
import subprocess
import json
import asyncio
from fastapi import FastAPI, WebSocket
from typing import Optional
import libtmux

class ClaudeSessionManager:
    def __init__(self):
        self.server = libtmux.Server()
        self.session_name = "claude-llm-service"
        self.window_name = "claude-cli"

    def initialize_session(self):
        """Create persistent tmux session with Claude CLI"""
        try:
            self.session = self.server.find_where(
                {"session_name": self.session_name}
            )
            if not self.session:
                self.session = self.server.new_session(
                    session_name=self.session_name,
                    window_name=self.window_name
                )
                # Start Claude CLI in the session
                self.window = self.session.attached_window
                self.pane = self.window.attached_pane
                self.pane.send_keys('claude', enter=True)
        except Exception as e:
            raise RuntimeError(f"Failed to initialize tmux session: {e}")

    async def send_prompt(self, prompt: str) -> str:
        """Send prompt to Claude CLI and capture response"""
        self.pane.send_keys(prompt, enter=True)
        # Wait and capture output
        await asyncio.sleep(2)  # Adjust based on response time
        output = self.pane.cmd('capture-pane', '-p').stdout
        return self._parse_claude_output(output)

    def _parse_claude_output(self, raw_output: list) -> str:
        """Parse Claude CLI output"""
        # Extract relevant response from raw terminal output
        return '\n'.join(raw_output)
```

#### Option B: Daemon Process with IPC

```python
# claude_daemon.py
import asyncio
import json
from multiprocessing import Process, Queue
import subprocess

class ClaudeDaemon:
    def __init__(self):
        self.request_queue = Queue()
        self.response_queue = Queue()
        self.daemon_process = None

    def start_daemon(self):
        """Start Claude CLI as a daemon process"""
        self.daemon_process = Process(
            target=self._daemon_worker,
            args=(self.request_queue, self.response_queue)
        )
        self.daemon_process.start()

    def _daemon_worker(self, req_queue, resp_queue):
        """Worker process that maintains Claude CLI instance"""
        process = subprocess.Popen(
            ['claude'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=0
        )

        while True:
            request = req_queue.get()
            if request == "SHUTDOWN":
                break

            # Send to Claude CLI
            process.stdin.write(request + '\n')
            process.stdin.flush()

            # Read response
            response = self._read_until_prompt(process.stdout)
            resp_queue.put(response)
```

#### Option C: WebSocket-based Service

```python
# claude_websocket_service.py
from fastapi import FastAPI, WebSocket
import asyncio
import uuid

app = FastAPI()

class ClaudeWebSocketService:
    def __init__(self):
        self.active_connections = {}
        self.claude_sessions = {}

    async def connect(self, websocket: WebSocket) -> str:
        """Establish WebSocket connection and Claude session"""
        await websocket.accept()
        session_id = str(uuid.uuid4())
        self.active_connections[session_id] = websocket
        self.claude_sessions[session_id] = ClaudeSession()
        return session_id

    async def process_intent(self, session_id: str, intent: str):
        """Process natural language intent"""
        websocket = self.active_connections[session_id]
        claude_session = self.claude_sessions[session_id]

        # Send status updates via WebSocket
        await websocket.send_json({
            "stage": "parsing",
            "message": "Processing natural language input..."
        })

        # Process with Claude
        result = await claude_session.process(intent)

        await websocket.send_json({
            "stage": "complete",
            "result": result
        })
```

### 2.2 Abstraction Layers

#### Intent Abstraction Layer

```python
# intent_abstraction.py
from abc import ABC, abstractmethod
from typing import Dict, Any

class IntentProcessor(ABC):
    @abstractmethod
    async def parse_intent(self, natural_language: str) -> Dict[str, Any]:
        """Parse natural language to structured intent"""
        pass

class ClaudeIntentProcessor(IntentProcessor):
    def __init__(self, claude_service):
        self.claude_service = claude_service

    async def parse_intent(self, natural_language: str) -> Dict[str, Any]:
        """Implementation using Claude CLI"""
        prompt = f"""
        Convert this to TMF921 intent format:
        {natural_language}

        Return only valid JSON.
        """
        response = await self.claude_service.send_prompt(prompt)
        return json.loads(response)

class RuleBasedIntentProcessor(IntentProcessor):
    """Fallback processor using regex/rules"""
    async def parse_intent(self, natural_language: str) -> Dict[str, Any]:
        # Rule-based parsing logic
        pass
```

---

## 3. API Design

### 3.1 RESTful API Endpoints

```yaml
openapi: 3.0.0
info:
  title: VM-1 Integrated Intent API
  version: 1.0.0

paths:
  /api/v1/intents:
    post:
      summary: Process natural language intent
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                text:
                  type: string
                  example: "Deploy eMBB slice on edge1 with 200Mbps"
                context:
                  type: object
                  description: Optional context for intent processing
      responses:
        200:
          description: Intent processed successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Intent'

  /api/v1/intents/{intentId}/status:
    get:
      summary: Get intent execution status
      parameters:
        - name: intentId
          in: path
          required: true
          schema:
            type: string
      responses:
        200:
          description: Status retrieved

  /api/v1/deployments:
    get:
      summary: List active deployments
    post:
      summary: Create deployment from intent

  /api/v1/monitoring/pipeline:
    get:
      summary: Get real-time pipeline status

  /ws/monitoring:
    get:
      summary: WebSocket endpoint for real-time updates
```

### 3.2 WebSocket Events

```javascript
// WebSocket event types
const WS_EVENTS = {
  // Intent Processing Events
  INTENT_RECEIVED: 'intent.received',
  INTENT_PARSING: 'intent.parsing',
  INTENT_PARSED: 'intent.parsed',

  // Deployment Pipeline Events
  KRM_GENERATING: 'krm.generating',
  KRM_GENERATED: 'krm.generated',
  GITOPS_PUSHING: 'gitops.pushing',
  GITOPS_PUSHED: 'gitops.pushed',

  // Edge Site Events
  EDGE_DEPLOYING: 'edge.deploying',
  EDGE_DEPLOYED: 'edge.deployed',
  EDGE_FAILED: 'edge.failed',

  // Monitoring Events
  METRICS_UPDATE: 'metrics.update',
  ALERT_TRIGGERED: 'alert.triggered',
  ROLLBACK_INITIATED: 'rollback.initiated'
};
```

---

## 4. Frontend Design

### 4.1 Technology Stack

- **Framework**: React 18 with TypeScript
- **UI Library**: Material-UI or Ant Design
- **State Management**: Redux Toolkit with RTK Query
- **Real-time**: Socket.io-client or native WebSocket
- **Visualization**: D3.js for pipeline flow, Recharts for metrics
- **Build Tool**: Vite

### 4.2 Component Architecture

```typescript
// Main Application Structure
src/
├── components/
│   ├── IntentInput/
│   │   ├── NaturalLanguageInput.tsx
│   │   ├── QuickTemplates.tsx      // Pre-defined intent buttons
│   │   └── IntentHistory.tsx
│   ├── Pipeline/
│   │   ├── PipelineVisualization.tsx
│   │   ├── StageStatus.tsx
│   │   └── FlowAnimation.tsx
│   ├── Monitoring/
│   │   ├── Dashboard.tsx
│   │   ├── MetricsChart.tsx
│   │   ├── EdgeSiteStatus.tsx
│   │   └── AlertsPanel.tsx
│   └── Deployment/
│       ├── DeploymentList.tsx
│       ├── DeploymentDetails.tsx
│       └── RollbackControls.tsx
├── services/
│   ├── api.ts                      // REST API client
│   ├── websocket.ts                // WebSocket manager
│   └── intentProcessor.ts
├── store/
│   ├── intentSlice.ts
│   ├── pipelineSlice.ts
│   └── monitoringSlice.ts
└── App.tsx
```

### 4.3 UI Mockup

```
┌──────────────────────────────────────────────────────────┐
│  Intent-to-O2 Control Center         [●] Connected       │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌─────────────────────────────────────────────────┐    │
│  │ 💬 Natural Language Input                       │    │
│  │ ┌─────────────────────────────────────────────┐ │    │
│  │ │ Deploy eMBB slice on edge1 with 200Mbps... │ │    │
│  │ └─────────────────────────────────────────────┘ │    │
│  │ [Send] [Clear]                                  │    │
│  │                                                 │    │
│  │ Quick Templates:                                │    │
│  │ [Deploy eMBB] [Deploy URLLC] [Deploy mMTC]     │    │
│  │ [Check Status] [Rollback] [Scale Up]           │    │
│  └─────────────────────────────────────────────────┘    │
│                                                          │
│  ┌─────────────────────────────────────────────────┐    │
│  │ 🔄 Pipeline Flow                                │    │
│  │                                                 │    │
│  │  [User Input]  ✅                               │    │
│  │       ↓                                         │    │
│  │  [LLM Parse]   🔄 Processing...                 │    │
│  │       ↓                                         │    │
│  │  [KRM Generate] ⏸️ Waiting                      │    │
│  │       ↓                                         │    │
│  │  [GitOps Push]  ⏸️ Waiting                      │    │
│  │       ↓                                         │    │
│  │  [Edge Deploy]  ⏸️ Waiting                      │    │
│  │     ├→ Edge1 (VM-2): ⏸️                        │    │
│  │     └→ Edge2 (VM-4): ⏸️                        │    │
│  └─────────────────────────────────────────────────┘    │
│                                                          │
│  ┌─────────────────────────────────────────────────┐    │
│  │ 📊 Real-time Monitoring                         │    │
│  │ ┌───────────────┐ ┌───────────────┐            │    │
│  │ │ Latency       │ │ Throughput    │            │    │
│  │ │ 📈 25ms       │ │ 📊 187 Mbps   │            │    │
│  │ └───────────────┘ └───────────────┘            │    │
│  │ ┌───────────────┐ ┌───────────────┐            │    │
│  │ │ Success Rate  │ │ Active Slices │            │    │
│  │ │ ✅ 99.9%     │ │ 🔢 3          │            │    │
│  │ └───────────────┘ └───────────────┘            │    │
│  └─────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────┘
```

---

## 5. Real-time Monitoring System

### 5.1 Event Stream Architecture

```python
# event_stream.py
from typing import Dict, Any, Callable
import asyncio
from enum import Enum

class PipelineStage(Enum):
    INPUT_RECEIVED = "input_received"
    LLM_PROCESSING = "llm_processing"
    INTENT_PARSED = "intent_parsed"
    KRM_GENERATING = "krm_generating"
    KRM_GENERATED = "krm_generated"
    GITOPS_PUSHING = "gitops_pushing"
    GITOPS_PUSHED = "gitops_pushed"
    EDGE_DEPLOYING = "edge_deploying"
    EDGE_DEPLOYED = "edge_deployed"
    COMPLETED = "completed"
    FAILED = "failed"

class PipelineMonitor:
    def __init__(self):
        self.stages = {}
        self.subscribers = []
        self.metrics = {
            "total_processed": 0,
            "success_rate": 0.0,
            "avg_latency": 0.0,
            "current_stage": None
        }

    async def update_stage(self, intent_id: str, stage: PipelineStage, metadata: Dict[str, Any] = None):
        """Update pipeline stage and notify subscribers"""
        self.stages[intent_id] = {
            "stage": stage,
            "timestamp": asyncio.get_event_loop().time(),
            "metadata": metadata or {}
        }

        # Notify all subscribers
        await self._notify_subscribers({
            "intent_id": intent_id,
            "stage": stage.value,
            "metadata": metadata
        })

    async def _notify_subscribers(self, event: Dict[str, Any]):
        """Send event to all WebSocket subscribers"""
        for subscriber in self.subscribers:
            try:
                await subscriber.send_json(event)
            except Exception as e:
                # Remove disconnected subscribers
                self.subscribers.remove(subscriber)
```

### 5.2 Metrics Collection

```python
# metrics_collector.py
import prometheus_client
from prometheus_client import Counter, Histogram, Gauge
import time

class MetricsCollector:
    def __init__(self):
        # Prometheus metrics
        self.intent_counter = Counter(
            'intent_total',
            'Total number of intents processed',
            ['service_type', 'status']
        )

        self.processing_time = Histogram(
            'intent_processing_seconds',
            'Time spent processing intents',
            ['stage']
        )

        self.active_deployments = Gauge(
            'active_deployments',
            'Number of active deployments',
            ['edge_site']
        )

        self.slo_metrics = {
            'availability': Gauge('slo_availability', 'Service availability percentage'),
            'latency': Gauge('slo_latency_ms', 'Service latency in milliseconds'),
            'throughput': Gauge('slo_throughput_mbps', 'Service throughput in Mbps')
        }

    def record_intent(self, service_type: str, status: str):
        """Record intent processing"""
        self.intent_counter.labels(service_type=service_type, status=status).inc()

    def record_stage_time(self, stage: str, duration: float):
        """Record processing time for a pipeline stage"""
        self.processing_time.labels(stage=stage).observe(duration)
```

---

## 6. Deployment Architecture

### 6.1 Service Deployment on VM-1

```yaml
# docker-compose.yml
version: '3.8'

services:
  claude-service:
    build: ./claude-service
    container_name: claude-llm-service
    environment:
      - CLAUDE_CLI_PATH=/usr/local/bin/claude
      - TMUX_SESSION=claude-service
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./claude-config:/root/.claude
    ports:
      - "8001:8001"
    restart: unless-stopped

  api-gateway:
    build: ./api-gateway
    container_name: intent-api-gateway
    environment:
      - CLAUDE_SERVICE_URL=http://claude-service:8001
      - ORCHESTRATOR_URL=http://orchestrator:8002
      - MONITOR_URL=http://monitor:8003
    ports:
      - "8000:8000"
      - "8080:8080"  # WebSocket port
    depends_on:
      - claude-service
      - orchestrator
      - monitor
    restart: unless-stopped

  orchestrator:
    build: ./orchestrator
    container_name: intent-orchestrator
    volumes:
      - ./kpt-packages:/app/kpt-packages
      - ./gitops:/app/gitops
    environment:
      - GIT_REPO_URL=http://localhost:8888/nephio/o2ims.git
      - EDGE1_URL=http://172.16.4.45:31280
      - EDGE2_URL=http://172.16.4.176:31280
    ports:
      - "8002:8002"
    restart: unless-stopped

  monitor:
    build: ./monitor
    container_name: intent-monitor
    environment:
      - PROMETHEUS_URL=http://prometheus:9090
      - GRAFANA_URL=http://grafana:3000
    ports:
      - "8003:8003"
    volumes:
      - ./metrics:/app/metrics
    restart: unless-stopped

  frontend:
    build: ./frontend
    container_name: intent-ui
    environment:
      - REACT_APP_API_URL=http://localhost:8000
      - REACT_APP_WS_URL=ws://localhost:8080
    ports:
      - "3000:3000"
    restart: unless-stopped

  prometheus:
    image: prom/prometheus:latest
    container_name: intent-prometheus
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"
    restart: unless-stopped

volumes:
  prometheus_data:
```

### 6.2 Systemd Service Configuration

```ini
# /etc/systemd/system/claude-llm.service
[Unit]
Description=Claude LLM Service for Intent Processing
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/nephio-intent-to-o2-demo
ExecStart=/usr/bin/python3 /home/ubuntu/nephio-intent-to-o2-demo/services/claude_service.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
Environment="PYTHONUNBUFFERED=1"
Environment="CLAUDE_CLI=/home/ubuntu/.npm-global/bin/claude"

[Install]
WantedBy=multi-user.target
```

---

## 7. Integration Points

### 7.1 Claude Code CLI Integration

```bash
#!/bin/bash
# claude_integration.sh

# Function to call Claude CLI with structured prompt
call_claude() {
    local prompt=$1
    local timeout=${2:-30}

    # Use timeout to prevent hanging
    timeout $timeout claude -p "$prompt" 2>/dev/null | \
        jq -r '.response' 2>/dev/null || echo "{}"
}

# Function to convert natural language to TMF921 intent
nl_to_intent() {
    local nl_text=$1

    local prompt="Convert this natural language request to TMF921 intent format:
    '$nl_text'

    Return only valid JSON with these fields:
    - intentType (eMBB/URLLC/mMTC)
    - targetSite (edge1/edge2/all)
    - parameters (bandwidth, latency, etc.)

    Example format:
    {
      'intentType': 'eMBB',
      'targetSite': 'edge1',
      'parameters': {
        'bandwidth': '200Mbps',
        'latency': '30ms'
      }
    }"

    call_claude "$prompt"
}
```

### 7.2 Pipeline Integration

```python
# pipeline_integration.py
class IntegratedPipeline:
    def __init__(self, claude_service, orchestrator, monitor):
        self.claude = claude_service
        self.orchestrator = orchestrator
        self.monitor = monitor

    async def process_intent(self, natural_language: str) -> Dict[str, Any]:
        """End-to-end intent processing pipeline"""
        intent_id = str(uuid.uuid4())

        try:
            # Stage 1: Parse with Claude
            await self.monitor.update_stage(intent_id, PipelineStage.LLM_PROCESSING)
            intent = await self.claude.parse_intent(natural_language)
            await self.monitor.update_stage(intent_id, PipelineStage.INTENT_PARSED, intent)

            # Stage 2: Generate KRM
            await self.monitor.update_stage(intent_id, PipelineStage.KRM_GENERATING)
            krm = await self.orchestrator.generate_krm(intent)
            await self.monitor.update_stage(intent_id, PipelineStage.KRM_GENERATED)

            # Stage 3: GitOps Push
            await self.monitor.update_stage(intent_id, PipelineStage.GITOPS_PUSHING)
            commit_id = await self.orchestrator.push_to_gitops(krm)
            await self.monitor.update_stage(intent_id, PipelineStage.GITOPS_PUSHED)

            # Stage 4: Deploy to Edges
            await self.monitor.update_stage(intent_id, PipelineStage.EDGE_DEPLOYING)
            deployment_result = await self.orchestrator.deploy_to_edges(intent)
            await self.monitor.update_stage(intent_id, PipelineStage.EDGE_DEPLOYED)

            # Complete
            await self.monitor.update_stage(intent_id, PipelineStage.COMPLETED)

            return {
                "intent_id": intent_id,
                "status": "success",
                "deployment": deployment_result
            }

        except Exception as e:
            await self.monitor.update_stage(
                intent_id,
                PipelineStage.FAILED,
                {"error": str(e)}
            )
            raise
```

---

## 8. Benefits of Integrated Architecture

### 8.1 Performance Improvements

- **Latency Reduction**: ~50% reduction by eliminating VM-3 network calls
- **Single Point of Processing**: All logic in VM-1 reduces coordination overhead
- **Direct Claude Access**: No intermediate API translation

### 8.2 Operational Benefits

- **Simplified Maintenance**: Single VM to monitor and maintain
- **Reduced Failure Points**: Eliminates VM-3 as potential failure point
- **Unified Logging**: All logs centralized in VM-1
- **Resource Efficiency**: VM-3 resources can be repurposed

### 8.3 Development Benefits

- **Faster Iteration**: Changes only needed in one place
- **Better Debugging**: Complete stack trace available locally
- **Simplified Testing**: No need for inter-service testing

---

## 9. Migration Strategy

### Phase 1: Parallel Operation (Week 1-2)
- Deploy integrated service on VM-1
- Keep VM-3 running as fallback
- Route 10% traffic to new service

### Phase 2: Gradual Migration (Week 3-4)
- Increase traffic to 50%
- Monitor performance metrics
- Fix any issues discovered

### Phase 3: Full Migration (Week 5)
- Route 100% traffic to VM-1
- Keep VM-3 in standby mode
- Monitor for 1 week

### Phase 4: Decommission (Week 6)
- Shutdown VM-3 services
- Repurpose VM-3 for other uses
- Document lessons learned

---

## 10. Future Enhancements

### 10.1 Advanced Features

1. **Multi-Model Support**
   - Add support for local LLMs (Ollama)
   - Implement model A/B testing
   - Model performance comparison

2. **Intent Learning**
   - Learn from user corrections
   - Build intent pattern database
   - Improve accuracy over time

3. **Advanced Monitoring**
   - ML-based anomaly detection
   - Predictive failure analysis
   - Automated remediation

### 10.2 Scalability Options

1. **Horizontal Scaling**
   - Multiple Claude CLI instances
   - Load balancing across instances
   - Session affinity management

2. **Edge Processing**
   - Deploy lightweight intent processors at edge
   - Reduce central processing load
   - Enable offline capabilities

---

## Conclusion

The integrated architecture on VM-1 provides a cleaner, more efficient, and more maintainable solution. By leveraging Claude Code CLI directly and implementing proper abstraction layers, we achieve the same functionality with reduced complexity and improved performance.

The proposed architecture includes:
- ✅ Service-wrapped Claude CLI
- ✅ RESTful and WebSocket APIs
- ✅ Modern React frontend with real-time updates
- ✅ Comprehensive monitoring and visualization
- ✅ Clear migration path from current architecture

This design positions VM-1 as a true integrated orchestrator, eliminating unnecessary complexity while providing enhanced user experience and operational efficiency.