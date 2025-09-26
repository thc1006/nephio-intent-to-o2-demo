# VM-1 LLM Adapter Operations Guide (Phase 16)

## Service Information

**Endpoint**: `http://<VM1_IP>:8888`
**Service**: TMF921 Intent Generator with targetSite field
**Claude CLI**: Subscription-based (no API key required)

## Deployment

### Prerequisites
- Python 3.9+
- Claude CLI authenticated (`claude login`)
- Network access to Claude services

### Installation
```bash
cd adapter
pip install -r requirements.txt
python app/main.py
```

### Headless Mode
```bash
# After initial login, run headless
export CLAUDE_HEADLESS=true
claude --dangerously-skip-permissions --allowedTools Bash,Read,Write,Python -p "..."
```

## API Endpoints

| Endpoint | Method | Purpose | Phase |
|----------|--------|---------|-------|
| `/generate_intent` | POST | Convert NL to TMF921 JSON | 12 |
| `/mock/slo` | GET | Mock SLO metrics for testing | 13 |
| `/health` | GET | Health check | - |
| `/` | GET | Web UI with targetSite selector | 17 |

## Risk Management

### Common Errors and Mitigations

| Error Type | Cause | Impact | Mitigation |
|------------|-------|---------|------------|
| **Timeout** | Claude CLI > 20s | Request fails | • Fallback intent generated<br>• Retry with simpler prompt |
| **Empty Output** | CLI returns nothing | No JSON | • Return fallback intent<br>• Log for debugging |
| **Format Error** | Invalid JSON | Schema violation | • JSON extraction regex<br>• Multiple parse attempts |
| **Invalid targetSite** | Wrong enum value | Routing fails | • Enforce valid values<br>• Default to "both" |
| **CLI Not Found** | Claude not installed | Service down | • Check installation<br>• Verify PATH |

### Error Response Format
```json
{
  "detail": "Error description",
  "status_code": 400/500/504
}
```

## targetSite Field Handling

### Valid Values
- `edge1` - Route to Edge Site 1
- `edge2` - Route to Edge Site 2
- `both` - Route to both sites

### Inference Rules
1. Check explicit `target_site` parameter
2. Parse natural language for keywords:
   - "edge1", "edge 1", "site 1" → `edge1`
   - "edge2", "edge 2", "site 2" → `edge2`
   - "both", "all", "multiple" → `both`
3. Default to `both` if ambiguous

### Enforcement
```python
# Always ensure targetSite is present and valid
if "targetSite" not in intent or intent["targetSite"] not in ["edge1", "edge2", "both"]:
    intent["targetSite"] = determined_site
```

## Monitoring

### Health Check
```bash
curl http://localhost:8002/health
# {"status": "healthy", "timestamp": 1234567890.123}
```

### SLO Metrics (Mock)
```bash
curl http://localhost:8002/mock/slo
# {
#   "status": "operational",
#   "metrics": {
#     "latency_p50": 150.23,
#     "latency_p95": 350.67,
#     "latency_p99": 750.89,
#     "success_rate": 0.975,
#     "requests_per_minute": 125
#   }
# }
```

## Performance Optimization

### Prompt Engineering
- Start with "Output only JSON. No text before or after."
- Show exact JSON structure in prompt
- Include targetSite value twice for emphasis

### JSON Extraction
1. Remove markdown code blocks
2. Find first `{` and last `}`
3. Parse extracted string
4. Fallback to direct parse

### Caching (Optional)
- Cache successful intents by NL text hash
- TTL: 5 minutes
- Max entries: 100

## Testing

### Unit Tests
```bash
# Schema validation
pytest tests/test_intent_schema.py -v

# CLI call and extraction
pytest tests/test_cli_call.py -v

# All tests
pytest tests/ -v
```

### Golden Tests
Located in `tests/golden/`:
- `*.in` - Natural language inputs
- `*.json` - Expected JSON outputs

### E2E Test
```bash
# Start service
python services/tmf921_processor.py &

# Test endpoints
curl -X POST http://localhost:8002/generate_intent \
  -H "Content-Type: application/json" \
  -d '{"natural_language": "Deploy 5G slice at edge1"}'
```

## Troubleshooting

### Claude CLI Issues

**Problem**: "Claude CLI not found"
```bash
# Check installation
which claude
# Install if missing
pip install claude-cli
```

**Problem**: "Claude timeout"
```bash
# Check network
ping api.anthropic.com
# Verify authentication
claude --version
```

**Problem**: "No output from Claude"
```bash
# Test manually
claude --dangerously-skip-permissions -p "Output only JSON: {\"test\": true}"
# Check logs
tail -f /var/log/claude.log
```

### JSON Extraction Issues

**Problem**: "No valid JSON found"
- Check Claude output in logs
- Verify prompt template
- Test with simpler input

**Problem**: "Invalid targetSite"
- Check schema enum values
- Verify inference logic
- Review enforcement function

## Demo Preparation (Phase 17)

### Pre-Demo Checklist
1. ✅ Service running on port 8888
2. ✅ Claude CLI authenticated
3. ✅ Test all golden examples
4. ✅ Verify UI loads correctly
5. ✅ Check targetSite selector works
6. ✅ Test each site value (edge1, edge2, both)

### Demo Script
```bash
# 1. Show UI
open http://localhost:8002

# 2. Demo targetSite auto-detection
"Deploy 5G slice at edge1" → targetSite: edge1

# 3. Demo explicit override
Select "Edge Site 2" → targetSite: edge2

# 4. Show JSON output with hash
Point out intentId, targetSite, hash fields

# 5. Show SLO metrics
curl http://localhost:8002/mock/slo
```

## Security Considerations

- No API keys stored (subscription-based)
- Input sanitization for NL text
- JSON schema validation
- Timeout protection (20s)
- Error messages don't expose internals

## Maintenance

### Log Rotation
```bash
# Application logs
/var/log/llm-adapter/*.log {
    daily
    rotate 7
    compress
    missingok
}
```

### Updates
```bash
# Update dependencies
pip install -r requirements.txt --upgrade

# Update Claude CLI
claude update
```

## Contact

For issues or questions about VM-1 LLM Adapter:
- Check logs: `journalctl -u llm-adapter`
- Review this guide
- Contact: [VM-1 Administrator]