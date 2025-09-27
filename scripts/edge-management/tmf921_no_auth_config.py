#!/usr/bin/env python3
"""
TMF921 Adapter - No Authentication Configuration
Configures the adapter to work without authentication for automation
"""

import os
import json
from pathlib import Path


def disable_claude_authentication():
    """Configure Claude CLI to skip authentication for automation"""
    claude_config_dir = Path.home() / '.claude'
    claude_config_dir.mkdir(exist_ok=True)

    # Create config that skips authentication prompts
    config = {
        "dangerously_skip_permissions": True,
        "non_interactive": True,
        "default_model": "claude-3-sonnet-20240229",
        "timeout": 30
    }

    config_file = claude_config_dir / 'config.json'
    with open(config_file, 'w') as f:
        json.dump(config, f, indent=2)

    print(f"✅ Claude configuration updated: {config_file}")
    return True


def create_environment_config():
    """Create environment configuration for passwordless operation"""
    env_vars = {
        'CLAUDE_SKIP_AUTH': 'true',
        'TMF921_ADAPTER_MODE': 'automated',
        'TMF921_FALLBACK_ENABLED': 'true',
        'PYTHONPATH': '/home/ubuntu/nephio-intent-to-o2-demo/adapter/app'
    }

    # Create .env file for the adapter
    adapter_dir = Path('/home/ubuntu/nephio-intent-to-o2-demo/adapter')
    env_file = adapter_dir / '.env'

    with open(env_file, 'w') as f:
        for key, value in env_vars.items():
            f.write(f"{key}={value}\n")

    print(f"✅ Environment configuration created: {env_file}")

    # Also create a shell script for easy sourcing
    shell_script = adapter_dir / 'set_automation_env.sh'
    with open(shell_script, 'w') as f:
        f.write("#!/bin/bash\n")
        f.write("# TMF921 Adapter Automation Environment\n\n")
        for key, value in env_vars.items():
            f.write(f"export {key}={value}\n")
        f.write("\necho '✅ TMF921 automation environment set'\n")

    os.chmod(shell_script, 0o755)
    print(f"✅ Shell environment script created: {shell_script}")

    return env_vars


def create_systemd_service():
    """Create systemd service for automated TMF921 adapter"""
    service_content = """[Unit]
Description=TMF921 Intent Adapter Service
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/nephio-intent-to-o2-demo/adapter
Environment=CLAUDE_SKIP_AUTH=true
Environment=TMF921_ADAPTER_MODE=automated
Environment=TMF921_FALLBACK_ENABLED=true
Environment=PYTHONPATH=/home/ubuntu/nephio-intent-to-o2-demo/adapter/app
ExecStart=/usr/bin/python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8889
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
"""

    service_file = Path('/home/ubuntu/nephio-intent-to-o2-demo/scripts/edge-management/tmf921-adapter.service')
    with open(service_file, 'w') as f:
        f.write(service_content)

    print(f"✅ Systemd service file created: {service_file}")
    print("To install the service:")
    print(f"  sudo cp {service_file} /etc/systemd/system/")
    print("  sudo systemctl daemon-reload")
    print("  sudo systemctl enable tmf921-adapter")
    print("  sudo systemctl start tmf921-adapter")

    return service_file


def create_docker_config():
    """Create Docker configuration for containerized deployment"""
    dockerfile_content = """FROM python:3.9-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY app/ ./app/
COPY *.py ./

# Set environment for automation
ENV CLAUDE_SKIP_AUTH=true
ENV TMF921_ADAPTER_MODE=automated
ENV TMF921_FALLBACK_ENABLED=true
ENV PYTHONPATH=/app

EXPOSE 8889

CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8889"]
"""

    adapter_dir = Path('/home/ubuntu/nephio-intent-to-o2-demo/adapter')
    dockerfile = adapter_dir / 'Dockerfile.automated'

    with open(dockerfile, 'w') as f:
        f.write(dockerfile_content)

    # Create docker-compose for easy deployment
    compose_content = """version: '3.8'

services:
  tmf921-adapter:
    build:
      context: .
      dockerfile: Dockerfile.automated
    ports:
      - "8889:8889"
    environment:
      - CLAUDE_SKIP_AUTH=true
      - TMF921_ADAPTER_MODE=automated
      - TMF921_FALLBACK_ENABLED=true
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8889/health"]
      interval: 30s
      timeout: 10s
      retries: 3
"""

    compose_file = adapter_dir / 'docker-compose.automated.yml'
    with open(compose_file, 'w') as f:
        f.write(compose_content)

    print(f"✅ Docker configuration created:")
    print(f"   Dockerfile: {dockerfile}")
    print(f"   Compose: {compose_file}")
    print("To deploy with Docker:")
    print("  docker-compose -f docker-compose.automated.yml up -d")

    return dockerfile, compose_file


def create_startup_script():
    """Create startup script for automated deployment"""
    script_content = """#!/bin/bash
set -e

# TMF921 Adapter Automated Startup Script

echo "🚀 Starting TMF921 Adapter in Automated Mode"

# Change to adapter directory
cd /home/ubuntu/nephio-intent-to-o2-demo/adapter

# Source environment
if [ -f "set_automation_env.sh" ]; then
    source set_automation_env.sh
fi

# Check if Claude CLI is available (optional)
if command -v claude &> /dev/null; then
    echo "✅ Claude CLI available"
else
    echo "⚠️  Claude CLI not found - using fallback mode only"
fi

# Install Python dependencies
if [ -f "requirements.txt" ]; then
    echo "📦 Installing Python dependencies..."
    pip3 install -r requirements.txt
fi

# Kill any existing adapter process
pkill -f "uvicorn.*main:app" || true
sleep 2

# Start the adapter service
echo "🔄 Starting TMF921 adapter service..."
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8889 --reload &

# Wait for service to start
sleep 5

# Test the service
echo "🧪 Testing service health..."
if curl -s http://localhost:8889/health > /dev/null; then
    echo "✅ TMF921 adapter is running and healthy"
    echo "📍 Service available at: http://localhost:8889"
    echo "📍 API endpoint: http://localhost:8889/api/v1/intent/transform"
    echo "📍 Web UI: http://localhost:8889/"
else
    echo "❌ Service health check failed"
    exit 1
fi

echo "🎉 TMF921 adapter started successfully in automated mode"
"""

    script_file = Path('/home/ubuntu/nephio-intent-to-o2-demo/scripts/edge-management/start_tmf921_automated.sh')
    with open(script_file, 'w') as f:
        f.write(script_content)

    os.chmod(script_file, 0o755)
    print(f"✅ Startup script created: {script_file}")

    return script_file


def main():
    """Configure TMF921 adapter for automated operation"""
    print("🔧 Configuring TMF921 Adapter for Automated Operation")
    print("=" * 60)

    try:
        # Disable Claude authentication
        disable_claude_authentication()

        # Create environment configuration
        env_vars = create_environment_config()

        # Create systemd service
        create_systemd_service()

        # Create Docker configuration
        create_docker_config()

        # Create startup script
        startup_script = create_startup_script()

        print("\n✅ TMF921 Adapter configured for automated operation!")
        print("\nQuick Start Options:")
        print(f"1. Manual start: {startup_script}")
        print("2. Docker: docker-compose -f docker-compose.automated.yml up -d")
        print("3. Systemd: sudo systemctl start tmf921-adapter")

        print("\nThe adapter will now work fully automated without passwords!")

    except Exception as e:
        print(f"❌ Configuration failed: {e}")
        return False

    return True


if __name__ == "__main__":
    main()