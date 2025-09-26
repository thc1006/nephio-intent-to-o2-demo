# Intent-to-O2 Access Guide

## 🌐 External Access URLs

All services are accessible from: **http://147.251.115.143**

### 1. **Gitea (Git Server)** - Port 8888
- **URL**: http://147.251.115.143:8888
- **Purpose**: Git repository management for GitOps
- **Login**:
  - First visit: Create admin account
  - Suggested: `admin` / `admin123456`

### 2. **Claude Headless API** - Port 8002
- **URL**: http://147.251.115.143:8002
- **Endpoints**:
  - `GET /health` - Health check
  - `POST /api/v1/intent` - Process natural language intent
- **Example**:
  ```bash
  curl -X POST http://147.251.115.143:8002/api/v1/intent \
    -H 'Content-Type: application/json' \
    -d '{"text": "Deploy eMBB service on edge01 with 100Mbps"}'
  ```

### 3. **Real-time Monitor** - Port 8001
- **URL**: http://147.251.115.143:8001
- **Purpose**: Real-time pipeline visualization with WebSocket
- **Features**:
  - 11-stage pipeline visualization
  - WebSocket live updates
  - Service health monitoring

### 4. **TMux Terminal Interface** - Port 8004 ✅
- **URL**: http://147.251.115.143:8004
- **Purpose**: Claude CLI in browser via tmux
- **Features**:
  - Claude running with `--dangerously-skip-permissions`
  - Direct natural language input
  - Real-time terminal output via WebSocket
  - TMux session: `claude-intent`

### 5. **Web Frontend** - Port 8005
- **URL**: http://147.251.115.143:8005
- **Purpose**: Advanced terminal UI with pipeline visualization
- **Features**:
  - Xterm.js terminal emulation
  - Pipeline stage tracking
  - Real-time metrics dashboard
  - Quick action buttons

## 🔧 TMux Session Details

The Claude CLI is running in a tmux session:
- **Session Name**: `claude-intent`
- **Mode**: `--dangerously-skip-permissions` ✅
- **Attach**: `tmux attach -t claude-intent`
- **Detach**: `Ctrl+B, D`

## 🚀 Quick Start

1. **Access the Web Terminal**:
   ```
   http://147.251.115.143:8004
   ```

2. **Try Natural Language Commands**:
   - "Deploy eMBB service on edge01"
   - "Deploy URLLC with 1ms latency"
   - "Show pipeline status"

3. **Monitor Real-time Progress**:
   ```
   http://147.251.115.143:8001
   ```

## ✅ Service Status

| Service | Port | Status | Purpose |
|---------|------|--------|---------|
| Gitea | 8888 | ✅ Running | Git Server |
| Claude API | 8002 | ✅ Running | Intent Processing |
| Monitor | 8001 | ✅ Running | Real-time Visualization |
| TMux Bridge | 8004 | ✅ Running | Terminal Interface |
| Web UI | 8005 | ✅ Running | Frontend |

## 🔍 Verification

Test Claude CLI integration:
```bash
# Check tmux session
tmux capture-pane -t claude-intent:0 -p

# Send command via WebSocket
curl http://147.251.115.143:8004/health

# Test intent processing
curl -X POST http://147.251.115.143:8002/api/v1/intent \
  -H 'Content-Type: application/json' \
  -d '{"text": "Deploy eMBB on edge01"}'
```

## 📝 Notes

- All services are configured for external access
- No firewall rules blocking the ports
- Claude CLI is running with permissions bypass
- WebSocket connections enabled for real-time updates
- TMux session persists even if you disconnect