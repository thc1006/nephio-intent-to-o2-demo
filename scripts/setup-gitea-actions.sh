#!/bin/bash

echo "========================================="
echo "Setting up Gitea Actions Runner"
echo "========================================="

# Variables
GITEA_URL="http://172.16.0.78:8888"
GITEA_USER="admin"
GITEA_PASS="admin123456"
RUNNER_NAME="vm1-runner"
RUNNER_DIR="/home/ubuntu/gitea-runner"

# Install act_runner
echo "Installing act_runner..."
mkdir -p $RUNNER_DIR
cd $RUNNER_DIR

# Download latest act_runner
RUNNER_VERSION="0.2.10"
wget -q https://github.com/nektos/act/releases/download/v${RUNNER_VERSION}/act_Linux_x86_64.tar.gz
tar -xzf act_Linux_x86_64.tar.gz
rm act_Linux_x86_64.tar.gz

# Get registration token from Gitea
echo "Getting registration token from Gitea..."
# First, we need to enable Actions in Gitea config
docker exec gitea bash -c "echo '[actions]' >> /data/gitea/conf/app.ini"
docker exec gitea bash -c "echo 'ENABLED = true' >> /data/gitea/conf/app.ini"
docker exec gitea bash -c "echo 'DEFAULT_ACTIONS_URL = https://github.com' >> /data/gitea/conf/app.ini"

# Restart Gitea to apply changes
echo "Restarting Gitea to enable Actions..."
docker restart gitea
sleep 10

# Create runner configuration
cat > $RUNNER_DIR/config.yaml <<EOF
log:
  level: info

runner:
  name: ${RUNNER_NAME}
  file: .runner
  capacity: 1
  env_file: .env
  timeout: 3h
  insecure: false
  fetch_timeout: 5s
  fetch_interval: 2s
  labels:
    - "ubuntu-latest:docker://node:16-bullseye"
    - "ubuntu-22.04:docker://node:16-bullseye"
    - "ubuntu-20.04:docker://node:16-bullseye"

cache:
  enabled: true
  dir: ""
  host: ""
  port: 0
  external_server: ""

container:
  network: bridge
  privileged: false
  options: ""
  workdir_parent: ""
  valid_volumes: []
  docker_host: ""
  force_pull: true

host:
  workdir_parent: ""
EOF

# Create systemd service for the runner
sudo tee /etc/systemd/system/gitea-runner.service > /dev/null <<EOF
[Unit]
Description=Gitea Actions Runner
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=ubuntu
WorkingDirectory=$RUNNER_DIR
ExecStart=$RUNNER_DIR/act daemon
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Note: Manual registration will be needed via Gitea UI
echo ""
echo "========================================="
echo "Gitea Actions Setup Complete!"
echo "========================================="
echo ""
echo "Actions have been enabled in Gitea configuration."
echo ""
echo "Next steps:"
echo "1. Visit http://172.16.0.78:8888 and login as admin/admin123456"
echo "2. Go to Site Administration > Actions > Runners"
echo "3. Click 'Create new Runner'"
echo "4. Copy the registration token"
echo "5. Run: cd $RUNNER_DIR && ./act register --no-interactive --instance $GITEA_URL --token <TOKEN>"
echo "6. Start the runner: sudo systemctl start gitea-runner"
echo ""