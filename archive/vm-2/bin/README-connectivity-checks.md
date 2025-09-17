# VM Connectivity Health Checks

## Overview
Daily smoke tests to ensure connectivity between VM-1 (SMO) and VM-2 (Edge) remains operational.

## Scripts

### VM-2 → VM-1 Check
**Location**: `~/bin/check-vm1.sh`

Checks from VM-2 to VM-1:
- ICMP ping to 172.16.0.78
- Gitea port 3000 (internal)
- Gitea port 8888 (external at 147.251.115.143)
- HTTP response from Gitea
- GitOps repository accessibility

### VM-1 → VM-2 Check (Reference)
**Location**: `~/bin/check-vm2.sh` (copy to VM-1)

Checks from VM-1 to VM-2:
- ICMP ping to 172.16.4.45
- Kubernetes API port 6443
- O2IMS API port 31280
- HTTP NodePort 31080
- HTTPS NodePort 31443
- API health endpoints

## Installation

### On VM-2 (Current Machine)
```bash
# Make scripts executable
chmod +x ~/bin/check-vm1.sh

# Test manually
~/bin/check-vm1.sh
```

### On VM-1
```bash
# Copy the check-vm2.sh script to VM-1
scp ~/bin/check-vm2.sh ubuntu@172.16.0.78:~/bin/

# On VM-1, make it executable
ssh ubuntu@172.16.0.78 'chmod +x ~/bin/check-vm2.sh'
```

## Manual Execution

### Quick Test
```bash
# On VM-2: Check VM-1 connectivity
~/bin/check-vm1.sh

# On VM-1: Check VM-2 connectivity
~/bin/check-vm2.sh
```

### Verbose Output
```bash
# Run with bash debug mode
bash -x ~/bin/check-vm1.sh
```

### Check Logs
```bash
# View connectivity logs
tail -f /var/log/vm-connectivity-check.log

# Check system logs
journalctl -t vm-connectivity -n 50
```

## Automated Execution (Cron)

### Setup Daily Checks
```bash
# Edit crontab
crontab -e

# Add daily check at 2:00 AM
@daily /home/ubuntu/bin/check-vm1.sh 2>&1 | logger -t vm-connectivity

# Or use specific time
0 2 * * * /home/ubuntu/bin/check-vm1.sh 2>&1 | logger -t vm-connectivity
```

### Verify Cron Setup
```bash
# List current crontab
crontab -l

# Check if cron is running
systemctl status cron

# Monitor cron execution
grep CRON /var/log/syslog
```

## Exit Codes

| Code | Meaning | Description |
|------|---------|-------------|
| 0 | SUCCESS | All checks passed |
| 1 | PING_FAILED | ICMP ping failed |
| 2 | PORT_FAILED | One service port check failed |
| 3 | MULTIPLE_FAILED | Multiple checks failed |

## Monitoring Integration

### With Systemd Timer (Alternative to Cron)
```bash
# Create service file
sudo tee /etc/systemd/system/vm-connectivity-check.service <<EOF
[Unit]
Description=VM Connectivity Health Check
After=network.target

[Service]
Type=oneshot
ExecStart=/home/ubuntu/bin/check-vm1.sh
User=ubuntu
StandardOutput=journal
StandardError=journal
EOF

# Create timer file
sudo tee /etc/systemd/system/vm-connectivity-check.timer <<EOF
[Unit]
Description=Daily VM Connectivity Check
Requires=vm-connectivity-check.service

[Timer]
OnCalendar=daily
AccuracySec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Enable and start timer
sudo systemctl daemon-reload
sudo systemctl enable vm-connectivity-check.timer
sudo systemctl start vm-connectivity-check.timer

# Check timer status
systemctl list-timers | grep vm-connectivity
```

### Email Notifications
```bash
# Install mail utilities
sudo apt-get install -y mailutils

# Add to crontab with email on failure
@daily /home/ubuntu/bin/check-vm1.sh || echo "VM connectivity check failed" | mail -s "Alert: VM Connectivity" admin@example.com
```

### Slack/Discord Notifications
```bash
# Create notification wrapper
cat > ~/bin/notify-on-failure.sh <<'EOF'
#!/bin/bash
/home/ubuntu/bin/check-vm1.sh
if [ $? -ne 0 ]; then
    # Send to Slack webhook
    curl -X POST -H 'Content-type: application/json' \
        --data '{"text":"⚠️ VM connectivity check failed!"}' \
        YOUR_WEBHOOK_URL
fi
EOF

chmod +x ~/bin/notify-on-failure.sh

# Use in crontab
@daily /home/ubuntu/bin/notify-on-failure.sh
```

## Troubleshooting

### Common Issues

#### Script Permission Denied
```bash
chmod +x ~/bin/check-vm1.sh
```

#### Log File Permission Issues
```bash
sudo touch /var/log/vm-connectivity-check.log
sudo chown ubuntu:ubuntu /var/log/vm-connectivity-check.log
```

#### Network Unreachable
```bash
# Check routing
ip route
route -n

# Check firewall
sudo iptables -L -n

# Test specific port
nc -zv 172.16.0.78 3000
```

#### Cron Not Running
```bash
# Check cron service
sudo systemctl status cron
sudo systemctl restart cron

# Check cron logs
grep CRON /var/log/syslog

# Test cron environment
* * * * * env > /tmp/cronenv.txt
```

## Service Dependencies

### VM-1 Services
- Gitea: ports 3000, 8888
- SSH: port 22 (for SCP operations)

### VM-2 Services  
- Kubernetes API: port 6443
- O2IMS: port 31280
- NodePorts: 31080, 31443

## Metrics and Alerting

### Parse Logs for Metrics
```bash
# Count successful checks
grep "SUCCESS" /var/log/vm-connectivity-check.log | wc -l

# Count failures
grep "ERROR\|FAILED" /var/log/vm-connectivity-check.log | wc -l

# Last check status
tail -1 /var/log/vm-connectivity-check.log
```

### Generate Daily Report
```bash
#!/bin/bash
# daily-report.sh
echo "VM Connectivity Report - $(date)"
echo "=========================="
echo "Total Checks: $(grep 'Starting' /var/log/vm-connectivity-check.log | wc -l)"
echo "Successful: $(grep 'All connectivity checks passed' /var/log/vm-connectivity-check.log | wc -l)"
echo "Failed: $(grep 'FAILED' /var/log/vm-connectivity-check.log | wc -l)"
echo ""
echo "Last 5 checks:"
grep "Summary" /var/log/vm-connectivity-check.log | tail -5
```

## Best Practices

1. **Run checks at different times** on each VM to avoid simultaneous load
2. **Rotate logs** weekly to prevent disk space issues
3. **Set up alerts** for critical failures only
4. **Test manually** after any network changes
5. **Keep timeout values** reasonable (5-10 seconds)
6. **Document** any permanent failures as known issues

---

*Created: 2025-09-07*  
*Version: 1.0.0*  
*Location: VM-2 (172.16.4.45)*