.PHONY: help venv install run stop restart status logs health clean test systemd-install systemd-enable

# Default target
help:
	@echo "LLM Adapter Service Management"
	@echo "=============================="
	@echo ""
	@echo "Available targets:"
	@echo "  make venv          - Create Python virtual environment"
	@echo "  make install       - Install dependencies"
	@echo "  make run           - Start the service"
	@echo "  make stop          - Stop the service"
	@echo "  make restart       - Restart the service"
	@echo "  make status        - Check service status"
	@echo "  make logs          - View service logs (last 50 lines)"
	@echo "  make logs-follow   - Follow service logs in real-time"
	@echo "  make health        - Check service health"
	@echo "  make test          - Run tests"
	@echo "  make clean         - Clean up generated files"
	@echo "  make systemd-install - Install systemd service"
	@echo "  make systemd-enable  - Enable service auto-start"

# Virtual environment setup
venv:
	@if [ ! -d ".venv" ]; then \
		echo "Creating virtual environment..."; \
		python3 -m venv .venv; \
		echo "✓ Virtual environment created"; \
	else \
		echo "Virtual environment already exists"; \
	fi

# Install dependencies
install: venv
	@echo "Installing dependencies..."
	@. .venv/bin/activate && pip install --upgrade pip
	@. .venv/bin/activate && pip install -r requirements.txt
	@echo "✓ Dependencies installed"

# Run the service
run:
	@./scripts/start.sh

# Stop the service
stop:
	@./scripts/stop.sh

# Restart the service
restart: stop
	@sleep 2
	@$(MAKE) run

# Check service status
status:
	@echo "=== Service Status ==="
	@if systemctl is-active --quiet llm-adapter; then \
		echo "✓ Systemd service is running"; \
		systemctl status llm-adapter --no-pager; \
	elif [ -f service.pid ] && ps -p $$(cat service.pid) > /dev/null 2>&1; then \
		echo "✓ Manual process is running (PID: $$(cat service.pid))"; \
	else \
		echo "✗ Service is not running"; \
	fi
	@echo ""
	@echo "=== Port Status ==="
	@if sudo lsof -i:8000 > /dev/null 2>&1; then \
		echo "✓ Port 8000 is in use"; \
		sudo lsof -i:8000; \
	else \
		echo "✗ Port 8000 is not in use"; \
	fi

# View logs
logs:
	@./scripts/logs.sh -n 50

# Follow logs in real-time
logs-follow:
	@./scripts/logs.sh -f

# Health check
health:
	@./scripts/health.sh

# Run tests
test: venv
	@echo "Running tests..."
	@. .venv/bin/activate && python -m pytest tests/ -v

# Clean up
clean:
	@echo "Cleaning up..."
	@rm -rf __pycache__ .pytest_cache
	@rm -rf app/__pycache__ tests/__pycache__
	@rm -f service.pid
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@echo "✓ Cleanup complete"

# Install systemd service
systemd-install:
	@echo "Installing systemd service..."
	@sudo cp llm-adapter.service /etc/systemd/system/
	@sudo systemctl daemon-reload
	@echo "✓ Systemd service installed"

# Enable auto-start
systemd-enable: systemd-install
	@echo "Enabling auto-start..."
	@sudo systemctl enable llm-adapter
	@echo "✓ Auto-start enabled"

# Development mode with auto-reload
dev: venv
	@echo "Starting in development mode with auto-reload..."
	@. .venv/bin/activate && uvicorn main:app --host 0.0.0.0 --port 8000 --reload

# Quick test of the API
api-test:
	@echo "Testing /health endpoint..."
	@curl -s http://localhost:8000/health | python3 -m json.tool
	@echo ""
	@echo "Testing /generate_intent endpoint..."
	@curl -s -X POST http://localhost:8000/generate_intent \
		-H "Content-Type: application/json" \
		-d '{"text": "Create a network slice for IoT devices with low latency"}' \
		| python3 -m json.tool || echo "Note: This endpoint requires Claude API to be configured"