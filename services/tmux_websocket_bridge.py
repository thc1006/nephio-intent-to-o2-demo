#!/usr/bin/env python3
"""
TMux-WebSocket Bridge for Claude Code CLI
Captures tmux session output and streams to WebSocket frontend
"""

import asyncio
import json
import subprocess
import time
from datetime import datetime
from pathlib import Path
from typing import Optional, Dict, Any

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
import uvicorn

app = FastAPI(title="TMux-WebSocket Bridge")

# CORS 設定
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 全局變數存儲 tmux session
TMUX_SESSION = "claude-intent"
connected_clients = set()

class TMuxManager:
    """管理 TMux session 和 Claude CLI 交互"""

    def __init__(self):
        self.session_name = TMUX_SESSION
        self.claude_pane = None

    async def create_session(self) -> bool:
        """創建新的 tmux session"""
        try:
            # 檢查 session 是否已存在
            result = subprocess.run(
                ["tmux", "has-session", "-t", self.session_name],
                capture_output=True
            )

            if result.returncode != 0:
                # 創建新 session
                subprocess.run([
                    "tmux", "new-session", "-d", "-s", self.session_name,
                    "-n", "claude-cli"
                ])

                # 設置 pane - 使用 dangerously-skip-permissions
                subprocess.run([
                    "tmux", "send-keys", "-t", f"{self.session_name}:0",
                    "claude --dangerously-skip-permissions", "C-m"
                ])

                await asyncio.sleep(2)  # 等待 Claude CLI 啟動

            return True
        except Exception as e:
            print(f"Error creating tmux session: {e}")
            return False

    async def send_command(self, command: str) -> None:
        """發送命令到 tmux session"""
        try:
            subprocess.run([
                "tmux", "send-keys", "-t", f"{self.session_name}:0",
                command, "C-m"
            ])
        except Exception as e:
            print(f"Error sending command: {e}")

    async def capture_output(self) -> str:
        """捕獲 tmux pane 輸出"""
        try:
            result = subprocess.run([
                "tmux", "capture-pane", "-t", f"{self.session_name}:0",
                "-p", "-S", "-100"  # 捕獲最後 100 行
            ], capture_output=True, text=True)

            return result.stdout
        except Exception as e:
            print(f"Error capturing output: {e}")
            return ""

    async def clear_pane(self) -> None:
        """清空 tmux pane"""
        try:
            subprocess.run([
                "tmux", "send-keys", "-t", f"{self.session_name}:0",
                "C-l"
            ])
        except Exception as e:
            print(f"Error clearing pane: {e}")

tmux_manager = TMuxManager()

@app.on_event("startup")
async def startup_event():
    """啟動時創建 tmux session"""
    await tmux_manager.create_session()

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket 端點處理客戶端連接"""
    await websocket.accept()
    connected_clients.add(websocket)

    # 發送初始連接消息
    await websocket.send_json({
        "type": "connection",
        "status": "connected",
        "timestamp": datetime.now().isoformat(),
        "session": TMUX_SESSION
    })

    # 開始輸出監控
    output_task = asyncio.create_task(monitor_output(websocket))

    try:
        while True:
            # 接收客戶端消息
            data = await websocket.receive_json()

            if data["type"] == "command":
                # 處理自然語言命令
                command = data["content"]

                # 發送到 tmux session
                await tmux_manager.send_command(command)

                # 確認收到命令
                await websocket.send_json({
                    "type": "command_received",
                    "command": command,
                    "timestamp": datetime.now().isoformat()
                })

            elif data["type"] == "clear":
                # 清空終端
                await tmux_manager.clear_pane()

            elif data["type"] == "ping":
                # 心跳檢測
                await websocket.send_json({
                    "type": "pong",
                    "timestamp": datetime.now().isoformat()
                })

    except WebSocketDisconnect:
        connected_clients.remove(websocket)
        output_task.cancel()
    except Exception as e:
        print(f"WebSocket error: {e}")
        if websocket in connected_clients:
            connected_clients.remove(websocket)
        output_task.cancel()

async def monitor_output(websocket: WebSocket):
    """持續監控 tmux 輸出並發送到 WebSocket"""
    last_output = ""

    while websocket in connected_clients:
        try:
            # 捕獲當前輸出
            current_output = await tmux_manager.capture_output()

            # 檢查是否有新內容
            if current_output != last_output:
                # 計算差異
                new_lines = get_new_lines(last_output, current_output)

                if new_lines:
                    # 發送新輸出
                    await websocket.send_json({
                        "type": "output",
                        "content": new_lines,
                        "timestamp": datetime.now().isoformat()
                    })

                    # 檢查特殊模式（如進度、錯誤等）
                    await check_patterns(new_lines, websocket)

                last_output = current_output

            await asyncio.sleep(0.5)  # 每 500ms 檢查一次

        except Exception as e:
            print(f"Monitor error: {e}")
            break

def get_new_lines(old: str, new: str) -> str:
    """計算新增的行"""
    old_lines = old.split('\n')
    new_lines = new.split('\n')

    # 找出新增的行
    if len(new_lines) > len(old_lines):
        return '\n'.join(new_lines[len(old_lines):])
    elif new_lines != old_lines:
        # 內容改變但行數相同
        return '\n'.join(new_lines)

    return ""

async def check_patterns(content: str, websocket: WebSocket):
    """檢查特殊模式並發送事件"""
    patterns = {
        "processing": ["Processing", "Analyzing", "Compiling"],
        "success": ["✓", "Success", "Completed"],
        "error": ["Error", "Failed", "Exception"],
        "warning": ["Warning", "Deprecated"],
        "intent": ["Intent:", "TMF921", "Service Profile"],
        "deployment": ["Deploying", "Applied", "Rolling out"]
    }

    for event_type, keywords in patterns.items():
        if any(keyword in content for keyword in keywords):
            await websocket.send_json({
                "type": "event",
                "event": event_type,
                "timestamp": datetime.now().isoformat()
            })

@app.get("/")
async def get_index():
    """提供 Web UI"""
    return HTMLResponse(content="""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Claude Intent Terminal</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'SF Mono', 'Monaco', 'Inconsolata', monospace;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            padding: 20px;
        }

        .container {
            width: 100%;
            max-width: 1200px;
            background: #1a1a2e;
            border-radius: 15px;
            box-shadow: 0 25px 50px rgba(0, 0, 0, 0.5);
            overflow: hidden;
        }

        .header {
            background: linear-gradient(90deg, #667eea, #764ba2);
            padding: 15px 25px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .title {
            color: white;
            font-size: 18px;
            font-weight: 600;
        }

        .status {
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .status-dot {
            width: 10px;
            height: 10px;
            border-radius: 50%;
            background: #4ade80;
            animation: pulse 2s infinite;
        }

        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }

        .terminal {
            background: #0f0f23;
            color: #00ff00;
            padding: 20px;
            height: 500px;
            overflow-y: auto;
            font-size: 14px;
            line-height: 1.6;
        }

        .terminal::-webkit-scrollbar {
            width: 8px;
        }

        .terminal::-webkit-scrollbar-track {
            background: #1a1a2e;
        }

        .terminal::-webkit-scrollbar-thumb {
            background: #667eea;
            border-radius: 4px;
        }

        .output-line {
            margin: 2px 0;
            white-space: pre-wrap;
            word-wrap: break-word;
        }

        .output-line.error {
            color: #ef4444;
        }

        .output-line.success {
            color: #4ade80;
        }

        .output-line.warning {
            color: #fbbf24;
        }

        .output-line.processing {
            color: #60a5fa;
        }

        .input-area {
            background: #1a1a2e;
            padding: 20px;
            border-top: 1px solid #333;
        }

        .input-wrapper {
            display: flex;
            gap: 10px;
        }

        .prompt {
            color: #667eea;
            display: flex;
            align-items: center;
        }

        .input {
            flex: 1;
            background: #0f0f23;
            color: #00ff00;
            border: 1px solid #667eea;
            padding: 12px 15px;
            border-radius: 8px;
            font-family: inherit;
            font-size: 14px;
            outline: none;
            transition: border-color 0.3s;
        }

        .input:focus {
            border-color: #764ba2;
            box-shadow: 0 0 0 2px rgba(102, 126, 234, 0.1);
        }

        .send-btn {
            background: linear-gradient(90deg, #667eea, #764ba2);
            color: white;
            border: none;
            padding: 12px 25px;
            border-radius: 8px;
            cursor: pointer;
            font-weight: 600;
            transition: transform 0.2s;
        }

        .send-btn:hover {
            transform: translateY(-2px);
        }

        .send-btn:active {
            transform: translateY(0);
        }

        .shortcuts {
            display: flex;
            gap: 10px;
            margin-top: 15px;
            flex-wrap: wrap;
        }

        .shortcut {
            background: #2a2a3e;
            color: #a0a0b0;
            padding: 8px 15px;
            border-radius: 5px;
            font-size: 12px;
            cursor: pointer;
            transition: all 0.3s;
        }

        .shortcut:hover {
            background: #667eea;
            color: white;
        }

        .pipeline-status {
            background: #1a1a2e;
            padding: 15px 25px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-top: 1px solid #333;
        }

        .stage {
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .stage-icon {
            width: 30px;
            height: 30px;
            border-radius: 50%;
            background: #2a2a3e;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 12px;
        }

        .stage.active .stage-icon {
            background: linear-gradient(90deg, #667eea, #764ba2);
            animation: rotate 2s linear infinite;
        }

        .stage.completed .stage-icon {
            background: #4ade80;
        }

        @keyframes rotate {
            from { transform: rotate(0deg); }
            to { transform: rotate(360deg); }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="title">🚀 Claude Intent Terminal - TMux Bridge</div>
            <div class="status">
                <span style="color: white; font-size: 14px;">Session: claude-intent</span>
                <div class="status-dot"></div>
                <span style="color: white; font-size: 14px;">Connected</span>
            </div>
        </div>

        <div class="terminal" id="terminal"></div>

        <div class="pipeline-status">
            <div class="stage" id="stage-input">
                <div class="stage-icon">📝</div>
                <span>Input</span>
            </div>
            <div class="stage" id="stage-parse">
                <div class="stage-icon">🔍</div>
                <span>Parse</span>
            </div>
            <div class="stage" id="stage-validate">
                <div class="stage-icon">✅</div>
                <span>Validate</span>
            </div>
            <div class="stage" id="stage-compile">
                <div class="stage-icon">⚙️</div>
                <span>Compile</span>
            </div>
            <div class="stage" id="stage-deploy">
                <div class="stage-icon">🚀</div>
                <span>Deploy</span>
            </div>
            <div class="stage" id="stage-monitor">
                <div class="stage-icon">📊</div>
                <span>Monitor</span>
            </div>
        </div>

        <div class="input-area">
            <div class="input-wrapper">
                <span class="prompt">intent&gt;</span>
                <input
                    type="text"
                    id="commandInput"
                    class="input"
                    placeholder="Enter natural language intent (e.g., 'Deploy eMBB service on edge01 with 100Mbps')"
                    autofocus
                />
                <button class="send-btn" onclick="sendCommand()">Send</button>
            </div>

            <div class="shortcuts">
                <div class="shortcut" onclick="setCommand('Deploy eMBB service on edge01')">eMBB Edge01</div>
                <div class="shortcut" onclick="setCommand('Deploy URLLC with 1ms latency')">URLLC Low Latency</div>
                <div class="shortcut" onclick="setCommand('Deploy mMTC for 10000 IoT devices')">mMTC IoT</div>
                <div class="shortcut" onclick="setCommand('Show pipeline status')">Status</div>
                <div class="shortcut" onclick="setCommand('Check SLO compliance')">Check SLO</div>
                <div class="shortcut" onclick="clearTerminal()">Clear</div>
            </div>
        </div>
    </div>

    <script>
        let ws;
        const terminal = document.getElementById('terminal');
        const input = document.getElementById('commandInput');

        function connectWebSocket() {
            ws = new WebSocket('ws://localhost:8003/ws');

            ws.onopen = () => {
                console.log('Connected to TMux bridge');
                addOutput('System: Connected to Claude Intent Terminal', 'success');
            };

            ws.onmessage = (event) => {
                const data = JSON.parse(event.data);

                switch(data.type) {
                    case 'output':
                        addOutput(data.content);
                        break;
                    case 'event':
                        handleEvent(data.event);
                        break;
                    case 'command_received':
                        addOutput(`> ${data.command}`, 'processing');
                        break;
                    case 'connection':
                        addOutput(`Connected to session: ${data.session}`, 'success');
                        break;
                }
            };

            ws.onerror = (error) => {
                console.error('WebSocket error:', error);
                addOutput('Connection error. Retrying...', 'error');
                setTimeout(connectWebSocket, 3000);
            };

            ws.onclose = () => {
                addOutput('Disconnected. Reconnecting...', 'warning');
                setTimeout(connectWebSocket, 3000);
            };
        }

        function sendCommand() {
            const command = input.value.trim();
            if (!command) return;

            if (ws && ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({
                    type: 'command',
                    content: command
                }));
                input.value = '';

                // Update pipeline stages
                updateStage('input', 'active');
                setTimeout(() => updateStage('parse', 'active'), 500);
            } else {
                addOutput('Not connected. Please wait...', 'error');
            }
        }

        function setCommand(cmd) {
            input.value = cmd;
            input.focus();
        }

        function clearTerminal() {
            terminal.innerHTML = '';
            if (ws && ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({ type: 'clear' }));
            }
        }

        function addOutput(text, className = '') {
            const line = document.createElement('div');
            line.className = 'output-line ' + className;
            line.textContent = text;
            terminal.appendChild(line);
            terminal.scrollTop = terminal.scrollHeight;
        }

        function handleEvent(eventType) {
            switch(eventType) {
                case 'processing':
                    updateStage('compile', 'active');
                    break;
                case 'success':
                    updateStage('deploy', 'completed');
                    break;
                case 'error':
                    resetStages();
                    break;
                case 'deployment':
                    updateStage('deploy', 'active');
                    break;
            }
        }

        function updateStage(stageId, status) {
            const stage = document.getElementById(`stage-${stageId}`);
            if (stage) {
                stage.className = `stage ${status}`;
            }
        }

        function resetStages() {
            ['input', 'parse', 'validate', 'compile', 'deploy', 'monitor'].forEach(stage => {
                updateStage(stage, '');
            });
        }

        // Keyboard shortcuts
        input.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                sendCommand();
            }
        });

        // Heartbeat
        setInterval(() => {
            if (ws && ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({ type: 'ping' }));
            }
        }, 30000);

        // Connect on load
        connectWebSocket();
    </script>
</body>
</html>
    """)

@app.get("/health")
async def health_check():
    """健康檢查端點"""
    try:
        # 檢查 tmux session
        result = subprocess.run(
            ["tmux", "has-session", "-t", TMUX_SESSION],
            capture_output=True
        )

        return {
            "status": "healthy",
            "tmux_session": TMUX_SESSION,
            "session_active": result.returncode == 0,
            "connected_clients": len(connected_clients),
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import sys

    # 確保 tmux 已安裝
    try:
        subprocess.run(["tmux", "-V"], capture_output=True, check=True)
    except:
        print("Error: tmux is not installed. Please install tmux first.")
        sys.exit(1)

    # 啟動服務
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8004,
        log_level="info"
    )