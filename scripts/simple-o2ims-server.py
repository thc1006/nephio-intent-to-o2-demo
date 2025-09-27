#!/usr/bin/env python3
"""
Simple O2IMS Mock Server - Minimal implementation using only Python standard library
No external dependencies required (no FastAPI, uvicorn, pydantic)

This server provides basic O2IMS endpoints for testing and demo purposes.
"""

import json
import uuid
import logging
import sys
from datetime import datetime, timezone
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import socketserver
import threading

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('/tmp/o2ims-simple-server.log')
    ]
)
logger = logging.getLogger(__name__)

# Configuration
PORT = 32080
EDGE_SITE = "edge3"  # Will be customized per edge

class O2IMSHandler(BaseHTTPRequestHandler):
    """HTTP request handler for O2IMS endpoints"""

    def __init__(self, *args, **kwargs):
        self.edge_site = EDGE_SITE
        super().__init__(*args, **kwargs)

    def do_GET(self):
        """Handle GET requests"""
        try:
            parsed_path = urlparse(self.path)
            path = parsed_path.path
            query_params = parse_qs(parsed_path.query)

            logger.info(f"GET request: {path}")

            # Route to appropriate handler
            if path == "/health":
                self.handle_health()
            elif path == "/o2ims_infrastructureInventory/v1/status":
                self.handle_o2ims_status()
            elif path == "/o2ims_infrastructureInventory/v1/deploymentManagers":
                self.handle_deployment_managers(query_params)
            elif path == "/o2ims_infrastructureInventory/v1/resourcePools":
                self.handle_resource_pools(query_params)
            elif path.startswith("/o2ims_infrastructureInventory/v1/deploymentManagers/"):
                if path.endswith("/o2ims_infrastructureProvisioningRequest"):
                    dm_id = path.split("/")[-2]
                    self.handle_provisioning_requests(dm_id, query_params)
                else:
                    dm_id = path.split("/")[-1]
                    self.handle_deployment_manager_by_id(dm_id)
            elif path.startswith("/o2ims_infrastructureInventory/v1/resourcePools/"):
                pool_id = path.split("/")[-1]
                self.handle_resource_pool_by_id(pool_id)
            else:
                self.send_404()

        except Exception as e:
            logger.error(f"Error handling request: {e}", exc_info=True)
            self.send_500(str(e))

    def handle_health(self):
        """Health check endpoint"""
        response = {
            "status": "healthy",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "service": "O2IMS Mock Server",
            "version": "1.0.0",
            "edge_site": self.edge_site
        }
        self.send_json_response(response)

    def handle_o2ims_status(self):
        """O2IMS status endpoint"""
        response = {
            "global_cloud_id": {
                "value": f"nephio-intent-o2-demo-cloud-{self.edge_site}"
            },
            "description": f"O2IMS Mock Server for {self.edge_site.upper()}",
            "service_uri": f"http://localhost:{PORT}/o2ims_infrastructureInventory/v1",
            "supported_locales": ["en-US"],
            "supported_time_zones": ["UTC"]
        }
        self.send_json_response(response)

    def handle_deployment_managers(self, query_params):
        """List deployment managers"""
        managers = [{
            "deployment_manager_id": str(uuid.uuid4()),
            "name": f"Kubernetes-{self.edge_site.upper()}",
            "description": f"Kubernetes deployment manager for {self.edge_site.upper()} edge site",
            "deployment_manager_type": "KUBERNETES",
            "service_uri": f"https://kubernetes-{self.edge_site}.nephio.local:6443",
            "supported_locales": ["en-US"],
            "capabilities": {
                "helm_support": True,
                "cni_plugins": ["flannel", "calico"],
                "storage_classes": ["local-path", "nfs"],
                "monitoring": {
                    "prometheus": True,
                    "grafana": True
                }
            },
            "capacity": {
                "total_nodes": 4,
                "total_cpu_cores": 128,
                "total_memory_gb": 512,
                "total_storage_gb": 4000,
                "available_cpu_cores": 64,
                "available_memory_gb": 256,
                "available_storage_gb": 2000
            },
            "extensions": {
                "kubernetes_version": "v1.28.3",
                "container_runtime": "containerd",
                "cluster_cidr": "10.203.0.0/16",
                "service_cidr": "10.103.0.0/16",
                "edge_site": self.edge_site
            }
        }]

        self.send_json_response(managers)

    def handle_resource_pools(self, query_params):
        """List resource pools"""
        pools = [
            {
                "resource_pool_id": str(uuid.uuid4()),
                "name": f"{self.edge_site.upper()}-COMPUTE",
                "description": f"Compute resource pool for {self.edge_site.upper()} edge site",
                "location": f"Edge Site {self.edge_site} - Rack A",
                "resource_type_list": ["VIRTUAL_MACHINE", "CONTAINER"],
                "resource_pool_type": "COMPUTE",
                "global_location_id": f"global-location-{self.edge_site}",
                "extensions": {
                    "cpu_architecture": "x86_64",
                    "hypervisor": "KVM",
                    "total_nodes": 4,
                    "node_specifications": {
                        "cpu_cores_per_node": 32,
                        "memory_gb_per_node": 128,
                        "storage_gb_per_node": 1000
                    }
                }
            },
            {
                "resource_pool_id": str(uuid.uuid4()),
                "name": f"{self.edge_site.upper()}-STORAGE",
                "description": f"Storage resource pool for {self.edge_site.upper()} edge site",
                "location": f"Edge Site {self.edge_site} - Rack B",
                "resource_type_list": ["STORAGE_VOLUME"],
                "resource_pool_type": "STORAGE",
                "global_location_id": f"global-location-{self.edge_site}",
                "extensions": {
                    "storage_types": ["SSD", "NVMe"],
                    "total_capacity_tb": 40,
                    "available_capacity_tb": 20,
                    "iops_capability": 300000
                }
            },
            {
                "resource_pool_id": str(uuid.uuid4()),
                "name": f"{self.edge_site.upper()}-NETWORK",
                "description": f"Network resource pool for {self.edge_site.upper()} edge site",
                "location": f"Edge Site {self.edge_site} - Network Equipment",
                "resource_type_list": ["NETWORK_FUNCTION"],
                "resource_pool_type": "NETWORK",
                "global_location_id": f"global-location-{self.edge_site}",
                "extensions": {
                    "network_functions": ["UPF", "AMF", "SMF", "AUSF", "UDM"],
                    "bandwidth_gbps": 300,
                    "latency_ms": 1.3,
                    "supported_standards": ["5G-NR", "LTE", "WiFi-6"],
                    "slice_support": True,
                    "edge_computing": True
                }
            }
        ]

        self.send_json_response(pools)

    def handle_deployment_manager_by_id(self, dm_id):
        """Get specific deployment manager"""
        manager = {
            "deployment_manager_id": dm_id,
            "name": f"Kubernetes-{self.edge_site.upper()}",
            "description": f"Kubernetes deployment manager for {self.edge_site.upper()} edge site",
            "deployment_manager_type": "KUBERNETES",
            "service_uri": f"https://kubernetes-{self.edge_site}.nephio.local:6443",
            "supported_locales": ["en-US"],
            "capabilities": {
                "helm_support": True,
                "cni_plugins": ["flannel", "calico"]
            },
            "capacity": {
                "total_nodes": 4,
                "total_cpu_cores": 128,
                "total_memory_gb": 512
            }
        }
        self.send_json_response(manager)

    def handle_resource_pool_by_id(self, pool_id):
        """Get specific resource pool"""
        pool = {
            "resource_pool_id": pool_id,
            "name": f"{self.edge_site.upper()}-COMPUTE",
            "description": f"Compute resource pool for {self.edge_site.upper()} edge site",
            "location": f"Edge Site {self.edge_site} - Rack A",
            "resource_type_list": ["VIRTUAL_MACHINE", "CONTAINER"],
            "resource_pool_type": "COMPUTE"
        }
        self.send_json_response(pool)

    def handle_provisioning_requests(self, dm_id, query_params):
        """Get provisioning requests for deployment manager"""
        requests = [
            {
                "infrastructure_request_id": str(uuid.uuid4()),
                "name": f"5G-Core-{self.edge_site.upper()}",
                "description": f"5G Core Network Functions deployment for {self.edge_site.upper()}",
                "request_type": "NETWORK_FUNCTION_DEPLOYMENT",
                "request_status": "COMPLETED",
                "created_at": datetime.now(timezone.utc).isoformat(),
                "updated_at": datetime.now(timezone.utc).isoformat(),
                "requested_capacity": {
                    "cpu_cores": 16,
                    "memory_gb": 64,
                    "storage_gb": 200
                },
                "allocated_capacity": {
                    "cpu_cores": 16,
                    "memory_gb": 64,
                    "storage_gb": 200
                },
                "extensions": {
                    "deployment_manager_id": dm_id,
                    "edge_site": self.edge_site
                }
            }
        ]
        self.send_json_response(requests)

    def send_json_response(self, data, status_code=200):
        """Send JSON response"""
        response_body = json.dumps(data, indent=2)

        self.send_response(status_code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', len(response_body))
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

        self.wfile.write(response_body.encode('utf-8'))
        logger.info(f"Response sent: {status_code}")

    def send_404(self):
        """Send 404 Not Found"""
        error_response = {
            "error": {
                "status": 404,
                "title": "Not Found",
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "path": self.path
            }
        }
        self.send_json_response(error_response, 404)

    def send_500(self, message):
        """Send 500 Internal Server Error"""
        error_response = {
            "error": {
                "status": 500,
                "title": "Internal Server Error",
                "message": message,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "path": self.path
            }
        }
        self.send_json_response(error_response, 500)

    def log_message(self, format, *args):
        """Override to use our logger"""
        logger.info(format % args)

class ThreadedHTTPServer(socketserver.ThreadingMixIn, HTTPServer):
    """Multi-threaded HTTP server"""
    allow_reuse_address = True
    daemon_threads = True

def set_edge_site(site_name):
    """Set the edge site name"""
    global EDGE_SITE
    EDGE_SITE = site_name
    logger.info(f"Edge site set to: {site_name}")

def main():
    """Main server function"""
    import sys

    # Parse command line arguments
    if len(sys.argv) > 1:
        site_name = sys.argv[1]
        set_edge_site(site_name)

    # Create and start server
    server_address = ('0.0.0.0', PORT)
    httpd = ThreadedHTTPServer(server_address, O2IMSHandler)

    logger.info(f"Starting O2IMS Mock Server for {EDGE_SITE}")
    logger.info(f"Server listening on http://0.0.0.0:{PORT}")
    logger.info(f"Health endpoint: http://localhost:{PORT}/health")
    logger.info(f"O2IMS status: http://localhost:{PORT}/o2ims_infrastructureInventory/v1/status")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logger.info("Server shutting down...")
        httpd.shutdown()

if __name__ == "__main__":
    main()