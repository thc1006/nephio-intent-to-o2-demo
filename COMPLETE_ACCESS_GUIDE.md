# 🌐 Complete Access Guide - Intent-to-O2 Demo

## 📍 VM-1 (Orchestrator) - Primary Access Point

### Public IP: 147.251.115.143
### Local IP: 172.16.0.78

---

## 🚀 Service Access URLs & Credentials

### 1️⃣ **Gitea (Git Server)**
- **URL**: http://147.251.115.143:8888
- **Purpose**: GitOps repository management
- **Login Credentials**:
  - **Username**: `admin`
  - **Password**: `admin123456`
  - **Email**: admin@summit-demo.local
- **First-time Setup**:
  - If not initialized, visit the URL and click "Register"
  - Create admin account with above credentials

### 2️⃣ **Claude Terminal Interface (TMux Bridge)** ✨
- **URL**: http://147.251.115.143:8004
- **Purpose**: Claude CLI in browser with TMux
- **Features**:
  - ✅ Claude running with `--dangerously-skip-permissions`
  - ✅ Natural language input directly in browser
  - ✅ Real-time terminal output via WebSocket
  - ✅ TMux session persistence
- **TMux Session**:
  - Session Name: `claude-intent`
  - Access via SSH: `tmux attach -t claude-intent`

### 3️⃣ **Web Frontend (Advanced UI)**
- **URL**: http://147.251.115.143:8005
- **Purpose**: Advanced terminal UI with pipeline visualization
- **Features**:
  - Xterm.js terminal emulation
  - 6-stage pipeline visualization
  - Real-time metrics dashboard
  - Quick action buttons for common intents

### 4️⃣ **Real-time Monitor**
- **URL**: http://147.251.115.143:8001
- **Purpose**: Real-time pipeline visualization
- **Features**:
  - 11-stage pipeline monitoring
  - WebSocket live updates
  - Service health checks

### 5️⃣ **Claude Headless API**
- **URL**: http://147.251.115.143:8002
- **Endpoints**:
  - `GET /health` - Health check
  - `POST /api/v1/intent` - Process natural language
- **Example Request**:
  ```bash
  curl -X POST http://147.251.115.143:8002/api/v1/intent \
    -H 'Content-Type: application/json' \
    -d '{"text": "Deploy eMBB service on edge01 with 100Mbps"}'
  ```

---

## 🖥️ Edge VM Access

### VM-2 (Edge01) - 172.16.4.45
- **SSH Access**:
  ```bash
  ssh ubuntu@172.16.4.45
  ```
- **Gitea (if running)**:
  - URL: http://172.16.4.45:3000
  - Credentials: Same as VM-1 (admin/admin123456)
- **Config Sync Status**:
  - ✅ CLAUDE.md E0 executed successfully
  - ✅ Generated configs at: `/home/ubuntu/configs-edge01-kpt/`

### VM-4 (Edge02) - 172.16.4.176
- **SSH Access**:
  ```bash
  ssh ubuntu@172.16.4.176
  ```
- **Gitea (if running)**:
  - URL: http://172.16.4.176:3000
  - Credentials: Same as VM-1 (admin/admin123456)
- **Config Sync Status**:
  - ✅ CLAUDE.md E0 executed successfully
  - ✅ Generated configs at: `/home/ubuntu/configs-edge02-kpt/`

---

## 🔐 Default Credentials Summary

| Service | Username | Password | Notes |
|---------|----------|----------|-------|
| Gitea (All VMs) | admin | admin123456 | Create on first visit |
| SSH (All VMs) | ubuntu | (key-based) | Use SSH key |
| Claude CLI | N/A | N/A | No auth needed |

---

## 🎯 Quick Start Guide

### Step 1: Access Claude Terminal Interface
Open in browser: http://147.251.115.143:8004

### Step 2: Try Natural Language Commands
Type directly in the terminal:
- "Deploy eMBB service on edge01 with 100Mbps"
- "Deploy URLLC with 1ms latency on edge02"
- "Deploy mMTC for 10000 IoT devices on both edges"

### Step 3: Monitor Progress
Open monitoring dashboard: http://147.251.115.143:8001

### Step 4: Check Git Repository
Access Gitea: http://147.251.115.143:8888
- Login with: admin / admin123456

---

## 🛠️ Troubleshooting

### Check Service Status
```bash
# On VM-1
./scripts/test_external_access.sh
```

### Restart Services
```bash
# TMux WebSocket Bridge
pkill -f tmux_websocket_bridge
nohup python3 /home/ubuntu/nephio-intent-to-o2-demo/services/tmux_websocket_bridge.py &

# Claude Headless API
systemctl restart claude-headless

# Real-time Monitor
pkill -f realtime_monitor
nohup python3 /home/ubuntu/nephio-intent-to-o2-demo/services/realtime_monitor.py &
```

### Access TMux Session Directly
```bash
# Attach to Claude session
tmux attach -t claude-intent

# Detach: Ctrl+B, D
# List sessions: tmux ls
```

---

## 📊 Service Architecture

```
Internet
    │
    ├── :8888 ─→ Gitea (Git Server)
    ├── :8004 ─→ TMux/Claude Terminal ✨
    ├── :8005 ─→ Web Frontend UI
    ├── :8001 ─→ Real-time Monitor
    └── :8002 ─→ Claude API

VM-1 (Orchestrator)
    ├── Claude CLI (--dangerously-skip-permissions)
    ├── TMux Session (claude-intent)
    └── WebSocket Bridges

VM-2 (Edge01)          VM-4 (Edge02)
    │                      │
    └── Config Sync ────── └── Config Sync
```

---

## 📝 Important Notes

1. **Claude CLI Mode**: Running with `--dangerously-skip-permissions` for demo purposes
2. **TMux Persistence**: Session persists even if you disconnect
3. **WebSocket Support**: All UIs support real-time updates
4. **Cross-VM Communication**: VM-1 can SSH to VM-2 and VM-4
5. **GitOps Ready**: Gitea configured for Config Sync

---

## 🔗 Related Documentation

- [ULTIMATE_DEVELOPMENT_PLAN.md](./ULTIMATE_DEVELOPMENT_PLAN.md)
- [VM1_INTEGRATED_ARCHITECTURE.md](./VM1_INTEGRATED_ARCHITECTURE.md)
- [THREE_VM_INTEGRATION_PLAN.md](./THREE_VM_INTEGRATION_PLAN.md)
- [ACCESS_GUIDE.md](./ACCESS_GUIDE.md)

---

**Last Updated**: 2025-09-25
**Version**: 1.0.0
**Status**: ✅ All Services Operational