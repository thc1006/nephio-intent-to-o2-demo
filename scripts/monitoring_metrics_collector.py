#!/usr/bin/env python3

"""
monitoring_metrics_collector.py - Collect metrics from edge sites and GitOps system
This script collects metrics from multiple sources and provides them to Prometheus
"""

import time
import requests
import json
import subprocess
import logging
from datetime import datetime
from typing import Dict, List, Optional
from prometheus_client import start_http_server, Gauge, Counter, Histogram
import yaml

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Prometheus metrics
edge_site_up = Gauge('edge_site_up', 'Edge site availability', ['site'])
slo_service_up = Gauge('slo_service_up', 'SLO service availability', ['site'])
o2ims_service_up = Gauge('o2ims_service_up', 'O2IMS service availability', ['site'])
gitops_sync_status = Gauge('gitops_sync_status', 'GitOps sync status', ['repository'])
gitops_sync_failures = Counter('gitops_sync_failures_total', 'GitOps sync failures', ['repository'])
response_time = Histogram('service_response_time_seconds', 'Service response time', ['service', 'site'])

class MetricsCollector:
    def __init__(self, config_file: str = '/home/ubuntu/nephio-intent-to-o2-demo/configs/monitoring-config.yaml'):
        self.config = self.load_config(config_file)
        self.edge_sites = self.config.get('edge_sites', {})
        self.gitops_config = self.config.get('gitops', {})

    def load_config(self, config_file: str) -> Dict:
        """Load monitoring configuration"""
        try:
            with open(config_file, 'r') as f:
                return yaml.safe_load(f)
        except FileNotFoundError:
            logger.warning(f"Config file {config_file} not found, using defaults")
            return self.default_config()

    def default_config(self) -> Dict:
        """Default configuration if config file is not found"""
        return {
            'edge_sites': {
                'edge1': {
                    'ip': '172.16.4.45',
                    'slo_port': 30090,
                    'o2ims_port': 31280
                },
                'edge2': {
                    'ip': '172.16.4.176',
                    'slo_port': 30090,
                    'o2ims_port': 31280
                }
            },
            'gitops': {
                'gitea_url': 'http://172.16.0.78:8888',
                'repositories': ['edge1-config', 'edge2-config']
            },
            'collection_interval': 30
        }

    def check_edge_site_connectivity(self, site: str, config: Dict) -> bool:
        """Check if edge site is reachable"""
        try:
            # Simple ping check
            result = subprocess.run(
                ['ping', '-c', '1', '-W', '3', config['ip']],
                capture_output=True,
                timeout=5
            )
            return result.returncode == 0
        except Exception as e:
            logger.error(f"Error checking connectivity to {site}: {e}")
            return False

    def check_slo_service(self, site: str, config: Dict) -> bool:
        """Check SLO service availability"""
        try:
            start_time = time.time()
            url = f"http://{config['ip']}:{config['slo_port']}/health"
            response = requests.get(url, timeout=5)
            response_time.labels(service='slo', site=site).observe(time.time() - start_time)
            return response.status_code == 200
        except Exception as e:
            logger.error(f"Error checking SLO service on {site}: {e}")
            return False

    def check_o2ims_service(self, site: str, config: Dict) -> bool:
        """Check O2IMS service availability"""
        try:
            start_time = time.time()
            url = f"http://{config['ip']}:{config['o2ims_port']}/metrics"
            response = requests.get(url, timeout=5)
            response_time.labels(service='o2ims', site=site).observe(time.time() - start_time)
            return response.status_code == 200
        except Exception as e:
            logger.error(f"Error checking O2IMS service on {site}: {e}")
            return False

    def check_gitops_sync_status(self) -> Dict[str, bool]:
        """Check GitOps synchronization status"""
        sync_status = {}

        try:
            for repo in self.gitops_config.get('repositories', []):
                try:
                    # Check if RootSync is healthy via kubectl
                    result = subprocess.run([
                        'kubectl', 'get', 'rootsync', '-n', 'config-management-system',
                        '-o', 'jsonpath={.items[*].status.sync.lastUpdate}'
                    ], capture_output=True, text=True, timeout=10)

                    if result.returncode == 0 and result.stdout.strip():
                        # If we get a timestamp, sync is working
                        sync_status[repo] = True
                        gitops_sync_status.labels(repository=repo).set(1)
                    else:
                        sync_status[repo] = False
                        gitops_sync_status.labels(repository=repo).set(0)
                        gitops_sync_failures.labels(repository=repo).inc()

                except Exception as e:
                    logger.error(f"Error checking sync status for {repo}: {e}")
                    sync_status[repo] = False
                    gitops_sync_status.labels(repository=repo).set(0)

        except Exception as e:
            logger.error(f"Error checking GitOps sync: {e}")

        return sync_status

    def collect_all_metrics(self):
        """Collect all metrics from configured sources"""
        logger.info("Starting metrics collection cycle")

        # Check edge sites
        for site, config in self.edge_sites.items():
            logger.info(f"Checking {site} ({config['ip']})")

            # Site connectivity
            site_up = self.check_edge_site_connectivity(site, config)
            edge_site_up.labels(site=site).set(1 if site_up else 0)

            if site_up:
                # SLO service
                slo_up = self.check_slo_service(site, config)
                slo_service_up.labels(site=site).set(1 if slo_up else 0)

                # O2IMS service
                o2ims_up = self.check_o2ims_service(site, config)
                o2ims_service_up.labels(site=site).set(1 if o2ims_up else 0)

                logger.info(f"  {site}: Site={site_up}, SLO={slo_up}, O2IMS={o2ims_up}")
            else:
                logger.warning(f"  {site}: Site unreachable")
                slo_service_up.labels(site=site).set(0)
                o2ims_service_up.labels(site=site).set(0)

        # Check GitOps sync
        sync_status = self.check_gitops_sync_status()
        logger.info(f"GitOps sync status: {sync_status}")

        logger.info("Metrics collection cycle completed")

    def run(self, port: int = 8000):
        """Start the metrics collector server"""
        logger.info(f"Starting Prometheus metrics server on port {port}")
        start_http_server(port)

        collection_interval = self.config.get('collection_interval', 30)
        logger.info(f"Starting metrics collection with {collection_interval}s interval")

        while True:
            try:
                self.collect_all_metrics()
                time.sleep(collection_interval)
            except KeyboardInterrupt:
                logger.info("Metrics collector stopped by user")
                break
            except Exception as e:
                logger.error(f"Error in metrics collection: {e}")
                time.sleep(collection_interval)

def create_monitoring_config():
    """Create default monitoring configuration file"""
    config = {
        'edge_sites': {
            'edge1': {
                'ip': '172.16.4.45',
                'slo_port': 30090,
                'o2ims_port': 31280
            },
            'edge2': {
                'ip': '172.16.4.176',
                'slo_port': 30090,
                'o2ims_port': 31280
            }
        },
        'gitops': {
            'gitea_url': 'http://172.16.0.78:8888',
            'repositories': ['edge1-config', 'edge2-config']
        },
        'collection_interval': 30,
        'metrics_port': 8000
    }

    config_file = '/home/ubuntu/nephio-intent-to-o2-demo/configs/monitoring-config.yaml'
    with open(config_file, 'w') as f:
        yaml.dump(config, f, default_flow_style=False)

    logger.info(f"Created monitoring configuration at {config_file}")

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description='Nephio Monitoring Metrics Collector')
    parser.add_argument('--port', type=int, default=8000, help='Metrics server port')
    parser.add_argument('--config', type=str,
                       default='/home/ubuntu/nephio-intent-to-o2-demo/configs/monitoring-config.yaml',
                       help='Configuration file path')
    parser.add_argument('--create-config', action='store_true', help='Create default config file')

    args = parser.parse_args()

    if args.create_config:
        create_monitoring_config()
        exit(0)

    collector = MetricsCollector(args.config)
    collector.run(args.port)