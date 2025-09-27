#!/usr/bin/env python3
"""
TDD Test Suite for Edge3/Edge4 Multi-Site Integration
Following Test-Driven Development methodology

Test Coverage:
1. Edge site SSH connectivity
2. Kubernetes cluster health
3. GitOps RootSync deployment
4. Prometheus monitoring
5. VictoriaMetrics remote_write
6. O2IMS API availability
"""

import pytest
import subprocess
import requests
import yaml
import json
import time
from typing import Dict, List
from dataclasses import dataclass


@dataclass
class EdgeSite:
    name: str
    ip: str
    user: str
    ssh_alias: str
    k8s_api_port: int = 6443
    prometheus_port: int = 30090
    o2ims_port: int = 31280


class TestEdgeSiteConnectivity:
    """Test Phase 1: Basic connectivity to edge sites"""

    @pytest.fixture
    def edge_sites(self) -> List[EdgeSite]:
        """Load edge sites from authoritative config"""
        with open('/home/ubuntu/nephio-intent-to-o2-demo/config/edge-sites-config.yaml') as f:
            config = yaml.safe_load(f)

        sites = []
        for site_name, site_config in config['sites'].items():
            sites.append(EdgeSite(
                name=site_name,
                ip=site_config['network']['internal_ip'],
                user=site_config['network'].get('ssh_access', '').split('@')[0],
                ssh_alias=site_name,
                prometheus_port=site_config['endpoints']['slo_metrics']['port'],
                o2ims_port=site_config['endpoints']['o2ims_api']['port']
            ))
        return sites

    def test_edge3_ssh_connectivity(self, edge_sites):
        """Test: Edge3 SSH connection should succeed"""
        edge3 = next((s for s in edge_sites if s.name == 'edge3'), None)
        assert edge3 is not None, "Edge3 not found in config"

        result = subprocess.run(
            ['ssh', '-o', 'ConnectTimeout=10', edge3.ssh_alias, 'hostname'],
            capture_output=True,
            text=True,
            timeout=15
        )

        assert result.returncode == 0, f"SSH to edge3 failed: {result.stderr}"
        assert 'edge3' in result.stdout.lower(), f"Unexpected hostname: {result.stdout}"

    def test_edge4_ssh_connectivity(self, edge_sites):
        """Test: Edge4 SSH connection should succeed"""
        edge4 = next((s for s in edge_sites if s.name == 'edge4'), None)
        assert edge4 is not None, "Edge4 not found in config"

        result = subprocess.run(
            ['ssh', '-o', 'ConnectTimeout=10', edge4.ssh_alias, 'hostname'],
            capture_output=True,
            text=True,
            timeout=15
        )

        assert result.returncode == 0, f"SSH to edge4 failed: {result.stderr}"
        assert 'edge4' in result.stdout.lower(), f"Unexpected hostname: {result.stdout}"

    def test_all_edges_reachable(self, edge_sites):
        """Test: All 4 edge sites should be SSH reachable"""
        failed_sites = []

        for site in edge_sites:
            result = subprocess.run(
                ['ssh', '-o', 'ConnectTimeout=10', site.ssh_alias, 'echo OK'],
                capture_output=True,
                text=True,
                timeout=15
            )
            if result.returncode != 0:
                failed_sites.append(site.name)

        assert len(failed_sites) == 0, f"Failed to reach sites: {failed_sites}"


class TestKubernetesClusterHealth:
    """Test Phase 2: Kubernetes cluster health on edge sites"""

    def test_edge3_kubernetes_running(self):
        """Test: Edge3 Kubernetes cluster should be operational"""
        result = subprocess.run(
            ['ssh', 'edge3', 'kubectl', 'get', 'nodes', '-o', 'json'],
            capture_output=True,
            text=True,
            timeout=20
        )

        assert result.returncode == 0, f"kubectl failed on edge3: {result.stderr}"

        nodes = json.loads(result.stdout)
        assert len(nodes['items']) > 0, "No nodes found in edge3 cluster"

        # Check node is Ready
        node_status = nodes['items'][0]['status']['conditions']
        ready_condition = next((c for c in node_status if c['type'] == 'Ready'), None)
        assert ready_condition is not None, "Ready condition not found"
        assert ready_condition['status'] == 'True', "Node is not Ready"

    def test_edge4_kubernetes_running(self):
        """Test: Edge4 Kubernetes cluster should be operational"""
        result = subprocess.run(
            ['ssh', 'edge4', 'kubectl', 'get', 'nodes', '-o', 'json'],
            capture_output=True,
            text=True,
            timeout=20
        )

        assert result.returncode == 0, f"kubectl failed on edge4: {result.stderr}"

        nodes = json.loads(result.stdout)
        assert len(nodes['items']) > 0, "No nodes found in edge4 cluster"

        node_status = nodes['items'][0]['status']['conditions']
        ready_condition = next((c for c in node_status if c['type'] == 'Ready'), None)
        assert ready_condition is not None, "Ready condition not found"
        assert ready_condition['status'] == 'True', "Node is not Ready"

    def test_required_namespaces_exist(self):
        """Test: Required namespaces should exist on edge3/edge4"""
        required_namespaces = ['monitoring', 'config-management-system']

        for edge in ['edge3', 'edge4']:
            result = subprocess.run(
                ['ssh', edge, 'kubectl', 'get', 'ns', '-o', 'json'],
                capture_output=True,
                text=True,
                timeout=20
            )

            assert result.returncode == 0, f"Failed to get namespaces on {edge}"

            namespaces = json.loads(result.stdout)
            ns_names = [ns['metadata']['name'] for ns in namespaces['items']]

            for required_ns in required_namespaces:
                assert required_ns in ns_names, f"Namespace {required_ns} not found on {edge}"


class TestGitOpsRootSyncDeployment:
    """Test Phase 3: GitOps RootSync deployment and synchronization"""

    def test_edge3_rootsync_deployed(self):
        """Test: Edge3 should have RootSync deployed"""
        result = subprocess.run(
            ['ssh', 'edge3', 'kubectl', 'get', 'rootsync', '-n', 'config-management-system', '-o', 'json'],
            capture_output=True,
            text=True,
            timeout=20
        )

        assert result.returncode == 0, f"Failed to get RootSync on edge3: {result.stderr}"

        rootsyncs = json.loads(result.stdout)
        assert len(rootsyncs['items']) > 0, "No RootSync found on edge3"

    def test_edge4_rootsync_deployed(self):
        """Test: Edge4 should have RootSync deployed"""
        result = subprocess.run(
            ['ssh', 'edge4', 'kubectl', 'get', 'rootsync', '-n', 'config-management-system', '-o', 'json'],
            capture_output=True,
            text=True,
            timeout=20
        )

        assert result.returncode == 0, f"Failed to get RootSync on edge4: {result.stderr}"

        rootsyncs = json.loads(result.stdout)
        assert len(rootsyncs['items']) > 0, "No RootSync found on edge4"

    def test_rootsync_syncing_successfully(self):
        """Test: RootSync should be syncing without errors"""
        for edge in ['edge3', 'edge4']:
            result = subprocess.run(
                ['ssh', edge, 'kubectl', 'get', 'rootsync', '-n', 'config-management-system', '-o', 'json'],
                capture_output=True,
                text=True,
                timeout=20
            )

            assert result.returncode == 0, f"Failed to get RootSync status on {edge}"

            rootsyncs = json.loads(result.stdout)
            if len(rootsyncs['items']) > 0:
                rootsync = rootsyncs['items'][0]
                status = rootsync.get('status', {})

                # Check for sync errors
                conditions = status.get('conditions', [])
                error_conditions = [c for c in conditions if c.get('status') == 'False']

                assert len(error_conditions) == 0, f"RootSync has errors on {edge}: {error_conditions}"


class TestPrometheusMonitoring:
    """Test Phase 4: Prometheus monitoring deployment and health"""

    def test_edge3_prometheus_running(self):
        """Test: Edge3 should have Prometheus pod running"""
        result = subprocess.run(
            ['ssh', 'edge3', 'kubectl', 'get', 'pods', '-n', 'monitoring', '-l', 'app=prometheus', '-o', 'json'],
            capture_output=True,
            text=True,
            timeout=20
        )

        assert result.returncode == 0, f"Failed to get Prometheus pods on edge3: {result.stderr}"

        pods = json.loads(result.stdout)
        assert len(pods['items']) > 0, "No Prometheus pods found on edge3"

        # Check pod is Running
        pod_status = pods['items'][0]['status']['phase']
        assert pod_status == 'Running', f"Prometheus pod not running on edge3: {pod_status}"

    def test_edge4_prometheus_running(self):
        """Test: Edge4 should have Prometheus pod running"""
        result = subprocess.run(
            ['ssh', 'edge4', 'kubectl', 'get', 'pods', '-n', 'monitoring', '-l', 'app=prometheus', '-o', 'json'],
            capture_output=True,
            text=True,
            timeout=20
        )

        assert result.returncode == 0, f"Failed to get Prometheus pods on edge4: {result.stderr}"

        pods = json.loads(result.stdout)
        assert len(pods['items']) > 0, "No Prometheus pods found on edge4"

        pod_status = pods['items'][0]['status']['phase']
        assert pod_status == 'Running', f"Prometheus pod not running on edge4: {pod_status}"

    def test_prometheus_nodeport_service(self):
        """Test: Prometheus should be exposed via NodePort 30090"""
        for edge in ['edge3', 'edge4']:
            result = subprocess.run(
                ['ssh', edge, 'kubectl', 'get', 'svc', '-n', 'monitoring', 'prometheus', '-o', 'json'],
                capture_output=True,
                text=True,
                timeout=20
            )

            assert result.returncode == 0, f"Failed to get Prometheus service on {edge}"

            service = json.loads(result.stdout)
            assert service['spec']['type'] == 'NodePort', f"Service not NodePort on {edge}"

            node_port = service['spec']['ports'][0]['nodePort']
            assert node_port == 30090, f"Wrong NodePort on {edge}: {node_port}"


class TestVictoriaMetricsRemoteWrite:
    """Test Phase 5: VictoriaMetrics remote_write configuration"""

    def test_prometheus_remote_write_configured(self):
        """Test: Prometheus should have remote_write configured"""
        for edge in ['edge3', 'edge4']:
            result = subprocess.run(
                ['ssh', edge, 'kubectl', 'get', 'configmap', '-n', 'monitoring', 'prometheus-config', '-o', 'json'],
                capture_output=True,
                text=True,
                timeout=20
            )

            assert result.returncode == 0, f"Failed to get Prometheus config on {edge}"

            configmap = json.loads(result.stdout)
            prometheus_yml = configmap['data']['prometheus.yml']

            assert 'remote_write' in prometheus_yml, f"remote_write not configured on {edge}"
            assert '172.16.0.78:8428' in prometheus_yml, f"VictoriaMetrics URL not found on {edge}"

    def test_metrics_sent_to_victoriametrics(self):
        """Test: Metrics should be visible in VictoriaMetrics"""
        # Wait for metrics to be scraped and sent
        time.sleep(30)

        for edge in ['edge3', 'edge4']:
            # Query VictoriaMetrics for edge-specific metrics
            response = requests.get(
                'http://172.16.0.78:8428/api/v1/query',
                params={'query': f'up{{cluster="{edge}"}}'},
                timeout=10
            )

            assert response.status_code == 200, f"VictoriaMetrics query failed for {edge}"

            data = response.json()
            assert data['status'] == 'success', f"Query status not success for {edge}"

            # Check we have results
            results = data['data']['result']
            assert len(results) > 0, f"No metrics found in VictoriaMetrics for {edge}"


class TestO2IMSDeployment:
    """Test Phase 6: O2IMS API deployment and availability"""

    def test_edge3_o2ims_deployment_exists(self):
        """Test: Edge3 should have O2IMS deployment"""
        result = subprocess.run(
            ['ssh', 'edge3', 'kubectl', 'get', 'deployment', '-A', '-o', 'json'],
            capture_output=True,
            text=True,
            timeout=20
        )

        assert result.returncode == 0, f"Failed to get deployments on edge3"

        deployments = json.loads(result.stdout)
        o2ims_deployments = [d for d in deployments['items'] if 'o2ims' in d['metadata']['name'].lower()]

        assert len(o2ims_deployments) > 0, "No O2IMS deployment found on edge3"

    def test_edge4_o2ims_deployment_exists(self):
        """Test: Edge4 should have O2IMS deployment"""
        result = subprocess.run(
            ['ssh', 'edge4', 'kubectl', 'get', 'deployment', '-A', '-o', 'json'],
            capture_output=True,
            text=True,
            timeout=20
        )

        assert result.returncode == 0, f"Failed to get deployments on edge4"

        deployments = json.loads(result.stdout)
        o2ims_deployments = [d for d in deployments['items'] if 'o2ims' in d['metadata']['name'].lower()]

        assert len(o2ims_deployments) > 0, "No O2IMS deployment found on edge4"


class TestEndToEndIntegration:
    """Test Phase 7: End-to-end integration validation"""

    def test_all_four_edges_healthy(self):
        """Test: All 4 edge sites should be operational"""
        edges = ['edge1', 'edge2', 'edge3', 'edge4']
        failed_checks = {}

        for edge in edges:
            checks = {
                'ssh': False,
                'kubernetes': False,
                'prometheus': False
            }

            # SSH check
            result = subprocess.run(
                ['ssh', '-o', 'ConnectTimeout=10', edge, 'echo OK'],
                capture_output=True,
                timeout=15
            )
            checks['ssh'] = (result.returncode == 0)

            # Kubernetes check
            result = subprocess.run(
                ['ssh', edge, 'kubectl', 'get', 'nodes'],
                capture_output=True,
                timeout=20
            )
            checks['kubernetes'] = (result.returncode == 0)

            # Prometheus check
            result = subprocess.run(
                ['ssh', edge, 'kubectl', 'get', 'pods', '-n', 'monitoring', '-l', 'app=prometheus'],
                capture_output=True,
                timeout=20
            )
            checks['prometheus'] = (result.returncode == 0)

            failed = [k for k, v in checks.items() if not v]
            if failed:
                failed_checks[edge] = failed

        assert len(failed_checks) == 0, f"Health checks failed: {failed_checks}"

    def test_central_monitoring_receives_all_edges(self):
        """Test: VM-1 VictoriaMetrics should receive metrics from all edges"""
        time.sleep(30)  # Wait for metrics collection

        for edge in ['edge1', 'edge2', 'edge3', 'edge4']:
            response = requests.get(
                'http://172.16.0.78:8428/api/v1/query',
                params={'query': f'up{{cluster="{edge}"}}'},
                timeout=10
            )

            assert response.status_code == 200, f"Query failed for {edge}"

            data = response.json()
            results = data.get('data', {}).get('result', [])

            assert len(results) > 0, f"No metrics from {edge} in central monitoring"


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--tb=short'])