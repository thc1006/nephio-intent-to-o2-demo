#!/usr/bin/env python3
"""
LLM Adapter Web UI
Natural Language → Intent → KRM → GitOps → O2IMS
"""

from flask import Flask, render_template, request, jsonify
import json
import subprocess
import yaml
import os
import requests
from datetime import datetime

app = Flask(__name__)

# Configuration
INTENT_COMPILER = "/home/ubuntu/nephio-intent-to-o2-demo/tools/intent-compiler/translate.py"
OPERATOR_API = "http://localhost:8080"  # Operator webhook

class LLMAdapter:
    """Processes natural language to intent and triggers deployment"""

    def nl_to_intent(self, natural_language):
        """Convert natural language to intent JSON"""
        # Simple NL processing (in production, use real LLM)
        intent = {
            "service": "user-service",
            "site": "edge1",
            "environment": "production",
            "replicas": 2,
            "resources": {
                "cpu": "200m",
                "memory": "256Mi"
            },
            "timestamp": datetime.utcnow().isoformat()
        }

        # Parse keywords from NL
        nl_lower = natural_language.lower()

        if "edge1" in nl_lower:
            intent["site"] = "edge1"
        elif "edge2" in nl_lower:
            intent["site"] = "edge2"
        elif "both" in nl_lower:
            intent["site"] = "both"

        if "analytics" in nl_lower:
            intent["service"] = "edge-analytics"
            intent["resources"]["memory"] = "1Gi"
        elif "ml" in nl_lower or "inference" in nl_lower:
            intent["service"] = "ml-inference"
            intent["resources"]["memory"] = "2Gi"
            intent["resources"]["gpu"] = "1"
        elif "o2ims" in nl_lower:
            intent["service"] = "o2ims"
            intent["nodePort"] = 31280

        if "high availability" in nl_lower or "ha" in nl_lower:
            intent["replicas"] = 3

        if "test" in nl_lower or "dev" in nl_lower:
            intent["environment"] = "development"
            intent["replicas"] = 1

        return intent

    def intent_to_krm(self, intent):
        """Convert intent to KRM using intent compiler"""
        try:
            # Call intent compiler
            process = subprocess.run(
                ["python3", INTENT_COMPILER, "-"],
                input=json.dumps(intent),
                capture_output=True,
                text=True
            )

            if process.returncode == 0:
                return process.stdout
            else:
                return None
        except Exception as e:
            print(f"Error compiling intent: {e}")
            return None

    def deploy_via_operator(self, intent):
        """Deploy using IntentDeployment CR"""
        site = intent.get("site", "edge1")

        cr = {
            "apiVersion": "tna.tna.ai/v1alpha1",
            "kind": "IntentDeployment",
            "metadata": {
                "name": f"{intent['service']}-{site}-deployment",
                "namespace": "default"
            },
            "spec": {
                "intent": json.dumps(intent),
                "compileConfig": {
                    "engine": "kpt",
                    "renderTimeout": "5m"
                },
                "deliveryConfig": {
                    "targetSite": site,
                    "gitOpsRepo": "https://github.com/thc1006/nephio-intent-to-o2-demo",
                    "syncWaitTimeout": "10m"
                },
                "gatesConfig": {
                    "enabled": True,
                    "sloThresholds": {
                        "error_rate": "0.1",
                        "latency_p99": "100ms",
                        "availability": "99.9"
                    }
                },
                "rollbackConfig": {
                    "autoRollback": True,
                    "maxRetries": 3
                }
            }
        }

        # Apply CR via kubectl
        try:
            process = subprocess.run(
                ["kubectl", "--context", "kind-nephio-demo", "apply", "-f", "-"],
                input=yaml.dump(cr),
                capture_output=True,
                text=True
            )
            return process.returncode == 0, process.stdout
        except Exception as e:
            return False, str(e)

adapter = LLMAdapter()

@app.route('/')
def index():
    """Main UI page"""
    return render_template('index.html')

@app.route('/api/process', methods=['POST'])
def process_nl():
    """Process natural language input"""
    data = request.json
    nl_input = data.get('natural_language', '')

    # Step 1: NL to Intent
    intent = adapter.nl_to_intent(nl_input)

    # Step 2: Intent to KRM
    krm = adapter.intent_to_krm(intent)

    # Step 3: Deploy via Operator
    success, message = adapter.deploy_via_operator(intent)

    response = {
        'natural_language': nl_input,
        'intent': intent,
        'krm': krm,
        'deployment_status': 'success' if success else 'failed',
        'message': message
    }

    return jsonify(response)

@app.route('/api/status/<deployment_name>')
def get_status(deployment_name):
    """Get deployment status"""
    try:
        process = subprocess.run(
            ["kubectl", "--context", "kind-nephio-demo", "get",
             "intentdeployment", deployment_name, "-o", "json"],
            capture_output=True,
            text=True
        )

        if process.returncode == 0:
            deployment = json.loads(process.stdout)
            return jsonify({
                'name': deployment_name,
                'phase': deployment.get('status', {}).get('phase', 'Unknown'),
                'message': deployment.get('status', {}).get('message', '')
            })
    except:
        pass

    return jsonify({'error': 'Deployment not found'}), 404

if __name__ == '__main__':
    os.makedirs('templates', exist_ok=True)
    app.run(host='0.0.0.0', port=8090, debug=True)