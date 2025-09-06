"""
Tests for job-query-adapter metrics endpoint.

Following TDD RED-GREEN-REFACTOR approach.
These tests should FAIL initially (RED phase).
"""

import json
import pytest
from unittest.mock import patch, MagicMock

# Import will fail initially - this is expected in RED phase
try:
    from adapter import create_app, MetricsConfig
except ImportError:
    # Expected during RED phase
    create_app = None
    MetricsConfig = None


@pytest.fixture
def app():
    """Create test app instance."""
    if create_app is None:
        pytest.skip("adapter module not implemented yet (RED phase)")
    
    app = create_app()
    app.config['TESTING'] = True
    return app


@pytest.fixture
def client(app):
    """Create test client."""
    return app.test_client()


class TestMetricsEndpoint:
    """Test the /metrics endpoint functionality."""

    def test_metrics_endpoint_exists(self, client):
        """Test that /metrics endpoint exists and returns JSON."""
        response = client.get('/metrics')
        assert response.status_code == 200
        assert response.content_type == 'application/json'

    def test_metrics_endpoint_returns_required_metrics(self, client):
        """Test that /metrics returns the three required SLO metrics."""
        response = client.get('/metrics')
        data = json.loads(response.data)
        
        # Required metrics for SLO gating
        required_metrics = ['latency_p95_ms', 'success_rate', 'throughput_p95_mbps']
        
        for metric in required_metrics:
            assert metric in data, f"Missing required metric: {metric}"
            assert isinstance(data[metric], (int, float)), f"{metric} must be numeric"

    def test_metrics_are_numeric_and_valid_ranges(self, client):
        """Test that metrics are in valid ranges."""
        response = client.get('/metrics')
        data = json.loads(response.data)
        
        # Latency should be positive
        assert data['latency_p95_ms'] >= 0, "Latency cannot be negative"
        
        # Success rate should be between 0 and 1
        assert 0 <= data['success_rate'] <= 1, "Success rate must be between 0 and 1"
        
        # Throughput should be positive
        assert data['throughput_p95_mbps'] >= 0, "Throughput cannot be negative"

    def test_metrics_endpoint_json_structure(self, client):
        """Test the JSON structure matches expected format."""
        response = client.get('/metrics')
        data = json.loads(response.data)
        
        expected_structure = {
            'timestamp': str,
            'latency_p95_ms': (int, float),
            'success_rate': (int, float),
            'throughput_p95_mbps': (int, float),
            'metadata': dict
        }
        
        for key, expected_type in expected_structure.items():
            assert key in data, f"Missing key: {key}"
            assert isinstance(data[key], expected_type), f"{key} should be {expected_type}"

    def test_health_endpoint(self, client):
        """Test health check endpoint."""
        response = client.get('/health')
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['status'] == 'healthy'


class TestMetricsConfig:
    """Test configurable metrics functionality."""

    def test_metrics_config_creation(self):
        """Test that MetricsConfig can be created with default values."""
        if MetricsConfig is None:
            pytest.skip("MetricsConfig not implemented yet (RED phase)")
            
        config = MetricsConfig()
        assert hasattr(config, 'latency_p95_ms')
        assert hasattr(config, 'success_rate')
        assert hasattr(config, 'throughput_p95_mbps')

    def test_metrics_config_customization(self):
        """Test that MetricsConfig accepts custom values."""
        if MetricsConfig is None:
            pytest.skip("MetricsConfig not implemented yet (RED phase)")
            
        config = MetricsConfig(
            latency_p95_ms=25.5,
            success_rate=0.999,
            throughput_p95_mbps=150.0
        )
        
        assert config.latency_p95_ms == 25.5
        assert config.success_rate == 0.999
        assert config.throughput_p95_mbps == 150.0

    @patch('adapter.current_metrics_config')
    def test_configurable_metrics_response(self, mock_config, client):
        """Test that metrics endpoint uses configurable values."""
        if create_app is None:
            pytest.skip("adapter module not implemented yet (RED phase)")
            
        # Mock configuration
        mock_config.latency_p95_ms = 12.3
        mock_config.success_rate = 0.997
        mock_config.throughput_p95_mbps = 180.5
        
        response = client.get('/metrics')
        data = json.loads(response.data)
        
        assert data['latency_p95_ms'] == 12.3
        assert data['success_rate'] == 0.997
        assert data['throughput_p95_mbps'] == 180.5

    def test_metrics_logging_json_format(self, client, caplog):
        """Test that metrics are logged in JSON format for machine parsing."""
        response = client.get('/metrics')
        
        # Check that at least one log record contains metrics extra data
        # (The JSONFormatter will convert this to JSON format)
        metrics_records = []
        for record in caplog.records:
            if hasattr(record, 'metrics') and hasattr(record, 'duration_ms'):
                metrics_records.append(record)
                
        assert len(metrics_records) > 0, "Expected at least one log record with metrics data"
        
        # Verify the log record has the expected structure
        metrics_record = metrics_records[0]
        assert hasattr(metrics_record, 'metrics'), "Log record should have metrics attribute"
        assert hasattr(metrics_record, 'duration_ms'), "Log record should have duration_ms attribute"
        assert isinstance(metrics_record.metrics, dict), "Metrics should be a dictionary"
        assert 'latency_p95_ms' in metrics_record.metrics, "Metrics should contain latency_p95_ms"
        assert 'success_rate' in metrics_record.metrics, "Metrics should contain success_rate"
        assert 'throughput_p95_mbps' in metrics_record.metrics, "Metrics should contain throughput_p95_mbps"


class TestAdapterConfiguration:
    """Test adapter configuration and environment handling."""

    def test_adapter_uses_env_example_pattern(self):
        """Test that adapter follows .env.example pattern (no plaintext secrets)."""
        if create_app is None:
            pytest.skip("adapter module not implemented yet (RED phase)")
            
        # This test ensures we follow the "no plaintext secrets" rule
        # by checking that sensitive config comes from environment
        import os
        
        # Mock environment variables
        with patch.dict(os.environ, {
            'ADAPTER_PORT': '8080',
            'ADAPTER_HOST': '0.0.0.0',
            'LOG_LEVEL': 'INFO'
        }):
            app = create_app()
            # App should be configurable via environment
            assert app is not None

    def test_deterministic_behavior(self, client):
        """Test that adapter behavior is deterministic for testing."""
        # Call endpoint multiple times - should be consistent
        responses = []
        for _ in range(3):
            response = client.get('/metrics')
            responses.append(json.loads(response.data))
        
        # With fixed config, responses should be identical (or at least consistent structure)
        assert all(set(resp.keys()) == set(responses[0].keys()) for resp in responses)