#!/usr/bin/env python3
"""
Real-time Pipeline Monitoring and Visualization Service
Provides WebSocket-based real-time monitoring for Intent-to-O2 pipeline
"""

import asyncio
import json
import time
from datetime import datetime
from typing import Dict, List, Any, Optional
from enum import Enum
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
import subprocess
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Real-time Pipeline Monitor",
    version="1.0.0",
    description="Real-time monitoring and visualization for Intent-to-O2 pipeline"
)

# Add CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class PipelineStage(Enum):
    """Pipeline stages for monitoring"""
    IDLE = "idle"
    INPUT_RECEIVED = "input_received"
    INTENT_PARSING = "intent_parsing"
    INTENT_PARSED = "intent_parsed"
    KRM_GENERATING = "krm_generating"
    KRM_GENERATED = "krm_generated"
    GITOPS_PUSHING = "gitops_pushing"
    GITOPS_PUSHED = "gitops_pushed"
    EDGE_DEPLOYING = "edge_deploying"
    EDGE_DEPLOYED = "edge_deployed"
    SLO_VALIDATING = "slo_validating"
    COMPLETED = "completed"
    FAILED = "failed"
    ROLLBACK = "rollback"

class PipelineMonitor:
    """Monitors and tracks pipeline execution"""

    def __init__(self):
        self.current_pipeline = None
        self.pipeline_history = []
        self.active_connections: List[WebSocket] = []
        self.metrics = {
            "total_intents": 0,
            "successful_intents": 0,
            "failed_intents": 0,
            "avg_processing_time": 0,
            "current_stage": PipelineStage.IDLE,
            "last_update": None
        }
        self.edge_status = {
            "edge01": {"status": "unknown", "last_sync": None, "deployments": 0},
            "edge02": {"status": "unknown", "last_sync": None, "deployments": 0},
            "edge03": {"status": "unknown", "last_sync": None, "deployments": 0},
            "edge04": {"status": "unknown", "last_sync": None, "deployments": 0}
        }

    async def start_pipeline(self, intent_id: str, intent_text: str) -> Dict[str, Any]:
        """Start monitoring a new pipeline execution"""
        self.current_pipeline = {
            "intent_id": intent_id,
            "intent_text": intent_text,
            "start_time": datetime.utcnow().isoformat(),
            "stages": [],
            "current_stage": PipelineStage.INPUT_RECEIVED,
            "status": "running"
        }

        self.metrics["total_intents"] += 1
        self.metrics["current_stage"] = PipelineStage.INPUT_RECEIVED

        await self.broadcast_update({
            "type": "pipeline_started",
            "data": self.current_pipeline
        })

        return self.current_pipeline

    async def update_stage(self, stage: PipelineStage, metadata: Optional[Dict] = None):
        """Update the current pipeline stage"""
        if not self.current_pipeline:
            return

        stage_data = {
            "stage": stage.value,
            "timestamp": datetime.utcnow().isoformat(),
            "metadata": metadata or {}
        }

        self.current_pipeline["stages"].append(stage_data)
        self.current_pipeline["current_stage"] = stage
        self.metrics["current_stage"] = stage
        self.metrics["last_update"] = datetime.utcnow().isoformat()

        # Calculate processing time
        if stage in [PipelineStage.COMPLETED, PipelineStage.FAILED]:
            start_time = datetime.fromisoformat(self.current_pipeline["start_time"])
            duration = (datetime.utcnow() - start_time).total_seconds()
            self.current_pipeline["duration"] = duration

            if stage == PipelineStage.COMPLETED:
                self.metrics["successful_intents"] += 1
                self.current_pipeline["status"] = "completed"
            else:
                self.metrics["failed_intents"] += 1
                self.current_pipeline["status"] = "failed"

            # Update average processing time
            total = self.metrics["successful_intents"] + self.metrics["failed_intents"]
            self.metrics["avg_processing_time"] = (
                (self.metrics["avg_processing_time"] * (total - 1) + duration) / total
            )

            # Move to history
            self.pipeline_history.append(self.current_pipeline)
            if len(self.pipeline_history) > 100:  # Keep last 100
                self.pipeline_history.pop(0)

        await self.broadcast_update({
            "type": "stage_update",
            "data": {
                "pipeline": self.current_pipeline,
                "stage": stage_data
            }
        })

    async def update_edge_status(self, edge: str, status: str, metadata: Optional[Dict] = None):
        """Update edge site status"""
        if edge in self.edge_status:
            self.edge_status[edge]["status"] = status
            self.edge_status[edge]["last_sync"] = datetime.utcnow().isoformat()

            if metadata:
                if "deployments" in metadata:
                    self.edge_status[edge]["deployments"] = metadata["deployments"]

            await self.broadcast_update({
                "type": "edge_update",
                "data": {
                    "edge": edge,
                    "status": self.edge_status[edge]
                }
            })

    async def check_services(self) -> Dict[str, Any]:
        """Check status of all related services"""
        services = {}

        # Check Claude Headless Service
        try:
            result = subprocess.run(
                ["curl", "-s", "http://localhost:8002/health"],
                capture_output=True,
                text=True,
                timeout=2
            )
            services["claude_headless"] = "healthy" if result.returncode == 0 else "unhealthy"
        except:
            services["claude_headless"] = "offline"

        # Check Gitea
        try:
            result = subprocess.run(
                ["curl", "-s", "http://localhost:8888"],
                capture_output=True,
                text=True,
                timeout=2
            )
            services["gitea"] = "healthy" if result.returncode == 0 else "unhealthy"
        except:
            services["gitea"] = "offline"

        # Check Edge sites
        edge_sites = [
            ("172.16.4.45", "edge01"),
            ("172.16.4.176", "edge02"),
            ("172.16.5.81", "edge03"),
            ("172.16.1.252", "edge04")
        ]

        for edge_ip, edge_name in edge_sites:
            try:
                result = subprocess.run(
                    ["curl", "-s", f"http://{edge_ip}:31280"],
                    capture_output=True,
                    text=True,
                    timeout=2
                )
                services[edge_name] = "healthy" if result.returncode == 0 else "unhealthy"
            except:
                services[edge_name] = "offline"

        return services

    async def broadcast_update(self, message: Dict[str, Any]):
        """Broadcast update to all connected WebSocket clients"""
        dead_connections = []

        for connection in self.active_connections:
            try:
                await connection.send_json(message)
            except:
                dead_connections.append(connection)

        # Remove dead connections
        for conn in dead_connections:
            self.active_connections.remove(conn)

    async def connect(self, websocket: WebSocket):
        """Connect a new WebSocket client"""
        await websocket.accept()
        self.active_connections.append(websocket)

        # Send initial state
        await websocket.send_json({
            "type": "initial_state",
            "data": {
                "metrics": self.metrics,
                "edge_status": self.edge_status,
                "current_pipeline": self.current_pipeline,
                "services": await self.check_services()
            }
        })

    def disconnect(self, websocket: WebSocket):
        """Disconnect a WebSocket client"""
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

# Create global monitor instance
monitor = PipelineMonitor()

@app.get("/")
async def get_visualization_ui():
    """Serve the visualization UI"""
    html_content = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Intent-to-O2 Pipeline Monitor</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                font-family: 'Segoe UI', Arial, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: #333;
                min-height: 100vh;
                padding: 20px;
            }
            .container {
                max-width: 1400px;
                margin: 0 auto;
            }
            h1 {
                color: white;
                text-align: center;
                margin-bottom: 30px;
                text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
            }
            .grid {
                display: grid;
                grid-template-columns: 2fr 1fr;
                gap: 20px;
                margin-bottom: 20px;
            }
            .card {
                background: white;
                border-radius: 10px;
                padding: 20px;
                box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            }
            .pipeline-stages {
                display: flex;
                flex-direction: column;
                gap: 10px;
            }
            .stage {
                display: flex;
                align-items: center;
                padding: 10px;
                border-radius: 5px;
                background: #f5f5f5;
                transition: all 0.3s ease;
            }
            .stage.active {
                background: #4CAF50;
                color: white;
                animation: pulse 1s infinite;
            }
            .stage.completed {
                background: #2196F3;
                color: white;
            }
            .stage.failed {
                background: #f44336;
                color: white;
            }
            @keyframes pulse {
                0% { opacity: 1; }
                50% { opacity: 0.7; }
                100% { opacity: 1; }
            }
            .metrics {
                display: grid;
                grid-template-columns: repeat(2, 1fr);
                gap: 15px;
            }
            .metric {
                padding: 15px;
                background: #f8f9fa;
                border-radius: 5px;
                text-align: center;
            }
            .metric-value {
                font-size: 24px;
                font-weight: bold;
                color: #667eea;
            }
            .metric-label {
                font-size: 12px;
                color: #666;
                margin-top: 5px;
            }
            .status-indicator {
                width: 12px;
                height: 12px;
                border-radius: 50%;
                display: inline-block;
                margin-right: 8px;
            }
            .status-healthy { background: #4CAF50; }
            .status-unhealthy { background: #ff9800; }
            .status-offline { background: #f44336; }
            .edge-status {
                display: flex;
                gap: 20px;
                margin-top: 20px;
            }
            .edge-card {
                flex: 1;
                padding: 15px;
                background: #f8f9fa;
                border-radius: 5px;
            }
            .log-entries {
                max-height: 200px;
                overflow-y: auto;
                font-family: monospace;
                font-size: 12px;
                background: #1e1e1e;
                color: #0f0;
                padding: 10px;
                border-radius: 5px;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 Intent-to-O2 Real-time Pipeline Monitor</h1>

            <div class="grid">
                <div class="card">
                    <h2>Pipeline Execution</h2>
                    <div id="current-intent" style="margin: 10px 0; padding: 10px; background: #f0f0f0; border-radius: 5px;">
                        <strong>Current Intent:</strong> <span id="intent-text">Waiting for input...</span>
                    </div>
                    <div class="pipeline-stages" id="pipeline-stages">
                        <div class="stage" data-stage="input_received">📥 Input Received</div>
                        <div class="stage" data-stage="intent_parsing">🔍 Parsing Intent</div>
                        <div class="stage" data-stage="intent_parsed">✅ Intent Parsed</div>
                        <div class="stage" data-stage="krm_generating">🔧 Generating KRM</div>
                        <div class="stage" data-stage="krm_generated">📦 KRM Generated</div>
                        <div class="stage" data-stage="gitops_pushing">📤 Pushing to GitOps</div>
                        <div class="stage" data-stage="gitops_pushed">🔄 GitOps Updated</div>
                        <div class="stage" data-stage="edge_deploying">🌐 Deploying to Edges</div>
                        <div class="stage" data-stage="edge_deployed">✨ Deployed</div>
                        <div class="stage" data-stage="slo_validating">📊 Validating SLO</div>
                        <div class="stage" data-stage="completed">🎉 Completed</div>
                    </div>
                </div>

                <div>
                    <div class="card">
                        <h2>Metrics</h2>
                        <div class="metrics">
                            <div class="metric">
                                <div class="metric-value" id="total-intents">0</div>
                                <div class="metric-label">Total Intents</div>
                            </div>
                            <div class="metric">
                                <div class="metric-value" id="success-rate">0%</div>
                                <div class="metric-label">Success Rate</div>
                            </div>
                            <div class="metric">
                                <div class="metric-value" id="avg-time">0s</div>
                                <div class="metric-label">Avg Time</div>
                            </div>
                            <div class="metric">
                                <div class="metric-value" id="active-deployments">0</div>
                                <div class="metric-label">Active</div>
                            </div>
                        </div>
                    </div>

                    <div class="card" style="margin-top: 20px;">
                        <h2>Service Status</h2>
                        <div id="service-status">
                            <div><span class="status-indicator status-offline"></span>Claude Headless</div>
                            <div><span class="status-indicator status-offline"></span>Gitea</div>
                            <div><span class="status-indicator status-offline"></span>Edge1 (VM-2)</div>
                            <div><span class="status-indicator status-offline"></span>Edge2 (VM-4)</div>
                            <div><span class="status-indicator status-offline"></span>Edge3 (New)</div>
                            <div><span class="status-indicator status-offline"></span>Edge4 (New)</div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="card">
                <h2>Edge Sites (4-Site Support)</h2>
                <div class="edge-status" style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 15px;">
                    <div class="edge-card">
                        <h3>Edge01 (VM-2)</h3>
                        <div>Status: <span id="edge01-status">Unknown</span></div>
                        <div>Last Sync: <span id="edge01-sync">Never</span></div>
                        <div>Deployments: <span id="edge01-deployments">0</span></div>
                    </div>
                    <div class="edge-card">
                        <h3>Edge02 (VM-4)</h3>
                        <div>Status: <span id="edge02-status">Unknown</span></div>
                        <div>Last Sync: <span id="edge02-sync">Never</span></div>
                        <div>Deployments: <span id="edge02-deployments">0</span></div>
                    </div>
                    <div class="edge-card">
                        <h3>Edge03 (New Site)</h3>
                        <div>Status: <span id="edge03-status">Unknown</span></div>
                        <div>Last Sync: <span id="edge03-sync">Never</span></div>
                        <div>Deployments: <span id="edge03-deployments">0</span></div>
                    </div>
                    <div class="edge-card">
                        <h3>Edge04 (New Site)</h3>
                        <div>Status: <span id="edge04-status">Unknown</span></div>
                        <div>Last Sync: <span id="edge04-sync">Never</span></div>
                        <div>Deployments: <span id="edge04-deployments">0</span></div>
                    </div>
                </div>
            </div>

            <div class="card">
                <h2>Live Logs</h2>
                <div class="log-entries" id="logs"></div>
            </div>
        </div>

        <script>
            const ws = new WebSocket('ws://localhost:8003/ws');
            const logs = document.getElementById('logs');

            function addLog(message) {
                const timestamp = new Date().toLocaleTimeString();
                logs.innerHTML += `[${timestamp}] ${message}\\n`;
                logs.scrollTop = logs.scrollHeight;
            }

            ws.onopen = () => {
                addLog('Connected to monitoring service');
            };

            ws.onmessage = (event) => {
                const data = JSON.parse(event.data);

                switch(data.type) {
                    case 'initial_state':
                        updateMetrics(data.data.metrics);
                        updateServices(data.data.services);
                        updateEdgeStatus(data.data.edge_status);
                        break;

                    case 'pipeline_started':
                        document.getElementById('intent-text').textContent = data.data.intent_text;
                        addLog(`Pipeline started: ${data.data.intent_id}`);
                        resetStages();
                        break;

                    case 'stage_update':
                        updateStage(data.data.stage);
                        addLog(`Stage: ${data.data.stage.stage}`);
                        break;

                    case 'edge_update':
                        updateEdge(data.data.edge, data.data.status);
                        break;
                }
            };

            function resetStages() {
                document.querySelectorAll('.stage').forEach(s => {
                    s.classList.remove('active', 'completed', 'failed');
                });
            }

            function updateStage(stageData) {
                const stageElement = document.querySelector(`[data-stage="${stageData.stage}"]`);
                if (stageElement) {
                    if (stageData.stage === 'completed') {
                        document.querySelectorAll('.stage').forEach(s => s.classList.add('completed'));
                    } else if (stageData.stage === 'failed') {
                        stageElement.classList.add('failed');
                    } else {
                        stageElement.classList.add('active');
                        // Mark previous stages as completed
                        let prev = stageElement.previousElementSibling;
                        while (prev) {
                            prev.classList.remove('active');
                            prev.classList.add('completed');
                            prev = prev.previousElementSibling;
                        }
                    }
                }
            }

            function updateMetrics(metrics) {
                document.getElementById('total-intents').textContent = metrics.total_intents;
                const successRate = metrics.total_intents > 0
                    ? Math.round((metrics.successful_intents / metrics.total_intents) * 100)
                    : 0;
                document.getElementById('success-rate').textContent = successRate + '%';
                document.getElementById('avg-time').textContent = Math.round(metrics.avg_processing_time) + 's';
            }

            function updateServices(services) {
                const statusMap = {
                    'healthy': 'status-healthy',
                    'unhealthy': 'status-unhealthy',
                    'offline': 'status-offline'
                };

                const serviceElements = document.getElementById('service-status').children;
                if (services.claude_headless) {
                    serviceElements[0].querySelector('.status-indicator').className =
                        'status-indicator ' + statusMap[services.claude_headless];
                }
                if (services.gitea) {
                    serviceElements[1].querySelector('.status-indicator').className =
                        'status-indicator ' + statusMap[services.gitea];
                }
                if (services.edge01) {
                    serviceElements[2].querySelector('.status-indicator').className =
                        'status-indicator ' + statusMap[services.edge01];
                }
                if (services.edge02) {
                    serviceElements[3].querySelector('.status-indicator').className =
                        'status-indicator ' + statusMap[services.edge02];
                }
                if (services.edge03) {
                    serviceElements[4].querySelector('.status-indicator').className =
                        'status-indicator ' + statusMap[services.edge03];
                }
                if (services.edge04) {
                    serviceElements[5].querySelector('.status-indicator').className =
                        'status-indicator ' + statusMap[services.edge04];
                }
            }

            function updateEdgeStatus(edgeStatus) {
                for (const [edge, status] of Object.entries(edgeStatus)) {
                    document.getElementById(`${edge}-status`).textContent = status.status;
                    document.getElementById(`${edge}-sync`).textContent =
                        status.last_sync ? new Date(status.last_sync).toLocaleString() : 'Never';
                    document.getElementById(`${edge}-deployments`).textContent = status.deployments;
                }
            }

            function updateEdge(edge, status) {
                document.getElementById(`${edge}-status`).textContent = status.status;
                document.getElementById(`${edge}-sync`).textContent =
                    new Date(status.last_sync).toLocaleString();
                document.getElementById(`${edge}-deployments`).textContent = status.deployments;
            }

            ws.onerror = (error) => {
                addLog(`Error: ${error}`);
            };

            ws.onclose = () => {
                addLog('Disconnected from monitoring service');
            };
        </script>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for real-time updates"""
    await monitor.connect(websocket)
    try:
        while True:
            # Keep connection alive and handle incoming messages
            data = await websocket.receive_text()
            # Process commands if needed
            if data == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        monitor.disconnect(websocket)

@app.post("/api/v1/pipeline/start")
async def start_pipeline(intent_id: str, intent_text: str):
    """Start monitoring a new pipeline"""
    result = await monitor.start_pipeline(intent_id, intent_text)
    return {"status": "started", "pipeline": result}

@app.post("/api/v1/pipeline/update")
async def update_pipeline(stage: str, metadata: Optional[Dict] = None):
    """Update pipeline stage"""
    try:
        stage_enum = PipelineStage(stage)
        await monitor.update_stage(stage_enum, metadata)
        return {"status": "updated", "stage": stage}
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid stage: {stage}")

@app.post("/api/v1/edge/update")
async def update_edge(edge: str, status: str, metadata: Optional[Dict] = None):
    """Update edge site status"""
    await monitor.update_edge_status(edge, status, metadata)
    return {"status": "updated", "edge": edge}

@app.get("/api/v1/metrics")
async def get_metrics():
    """Get current metrics"""
    return {
        "metrics": monitor.metrics,
        "edge_status": monitor.edge_status,
        "services": await monitor.check_services()
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "active_connections": len(monitor.active_connections),
        "current_pipeline": monitor.current_pipeline is not None
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8003, log_level="info")