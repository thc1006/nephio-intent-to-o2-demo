"""
Integration tests for SLO-gated GitOps pipeline.

Tests the full flow: job-query-adapter -> gate -> exit codes
Following TDD RED-GREEN-REFACTOR approach.
These tests should FAIL initially (RED phase).
"""

import json
import pytest
import subprocess
import sys
import time
import threading
import requests
from unittest.mock import patch

# These imports will fail initially - expected in RED phase
try:
    import sys
    sys.path.insert(0, '/home/ubuntu/nephio-intent-to-o2-demo/slo-gated-gitops/job-query-adapter')
    sys.path.insert(0, '/home/ubuntu/nephio-intent-to-o2-demo/slo-gated-gitops/gate')
    from adapter import create_app, MetricsConfig
    from gate import main as gate_main
except ImportError:
    create_app = None
    MetricsConfig = None
    gate_main = None


class TestE2EIntegration:
    """End-to-end integration tests for the SLO pipeline."""

    @pytest.fixture
    def adapter_server(self):
        """Start adapter server for integration testing."""
        if create_app is None:
            pytest.skip("Adapter not implemented yet (RED phase)")

        app = create_app()

        # Start server in background thread
        from werkzeug.serving import run_simple

        server_thread = threading.Thread(
            target=run_simple,
            args=("localhost", 8080, app),
            kwargs={"threaded": True, "use_reloader": False},
        )
        server_thread.daemon = True
        server_thread.start()

        # Wait for server to start
        for _ in range(10):  # 5 seconds max
            try:
                requests.get("http://localhost:8080/health", timeout=1)
                break
            except requests.exceptions.RequestException:
                time.sleep(0.5)
        else:
            pytest.fail("Adapter server failed to start")

        yield "http://localhost:8080"

        # Server will be cleaned up when thread ends

    def test_integration_slo_pass_scenario(self, adapter_server):
        """Test complete pipeline when all SLOs pass."""
        # Configure adapter to return good metrics
        if MetricsConfig is None:
            pytest.skip("MetricsConfig not implemented yet (RED phase)")

        # Set up metrics that will PASS the SLO thresholds
        good_config = MetricsConfig(
            latency_p95_ms=12.0,  # < 15 (pass)
            success_rate=0.997,  # > 0.995 (pass)
            throughput_p95_mbps=220.0,  # > 200 (pass)
        )

        with patch("job_query_adapter.adapter.current_metrics_config", good_config):
            # Run gate CLI
            slo_string = (
                "latency_p95_ms<=15,success_rate>=0.995,throughput_p95_mbps>=200"
            )
            cmd = [
                sys.executable,
                "-m",
                "gate.gate",
                "--slo",
                slo_string,
                "--url",
                f"{adapter_server}/metrics",
            ]

            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                cwd="/home/ubuntu/nephio-intent-to-o2-demo/slo-gated-gitops",
            )

            # Should exit with code 0 (success)
            assert (
                result.returncode == 0
            ), f"Expected exit code 0, got {result.returncode}. stderr: {result.stderr}"

            # Should log success in JSON format
            assert "slo_validation" in result.stdout or "SUCCESS" in result.stdout

    def test_integration_slo_fail_scenario(self, adapter_server):
        """Test complete pipeline when SLOs fail."""
        if MetricsConfig is None:
            pytest.skip("MetricsConfig not implemented yet (RED phase)")

        # Set up metrics that will FAIL the SLO thresholds
        bad_config = MetricsConfig(
            latency_p95_ms=25.0,  # > 15 (fail)
            success_rate=0.990,  # < 0.995 (fail)
            throughput_p95_mbps=150.0,  # < 200 (fail)
        )

        with patch("job_query_adapter.adapter.current_metrics_config", bad_config):
            # Run gate CLI
            slo_string = (
                "latency_p95_ms<=15,success_rate>=0.995,throughput_p95_mbps>=200"
            )
            cmd = [
                sys.executable,
                "-m",
                "gate.gate",
                "--slo",
                slo_string,
                "--url",
                f"{adapter_server}/metrics",
            ]

            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                cwd="/home/ubuntu/nephio-intent-to-o2-demo/slo-gated-gitops",
            )

            # Should exit with code 1 (failure)
            assert (
                result.returncode == 1
            ), f"Expected exit code 1, got {result.returncode}. stdout: {result.stdout}"

            # Should log failure details in JSON format
            assert (
                "slo_violation" in result.stdout
                or "FAILED" in result.stdout
                or "ERROR" in result.stderr
            )

    def test_integration_mixed_slo_scenario(self, adapter_server):
        """Test pipeline with some passing and some failing SLOs."""
        if MetricsConfig is None:
            pytest.skip("MetricsConfig not implemented yet (RED phase)")

        # Set up metrics where some pass, some fail
        mixed_config = MetricsConfig(
            latency_p95_ms=12.0,  # < 15 (pass)
            success_rate=0.990,  # < 0.995 (fail)
            throughput_p95_mbps=220.0,  # > 200 (pass)
        )

        with patch("job_query_adapter.adapter.current_metrics_config", mixed_config):
            slo_string = (
                "latency_p95_ms<=15,success_rate>=0.995,throughput_p95_mbps>=200"
            )
            cmd = [
                sys.executable,
                "-m",
                "gate.gate",
                "--slo",
                slo_string,
                "--url",
                f"{adapter_server}/metrics",
            ]

            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                cwd="/home/ubuntu/nephio-intent-to-o2-demo/slo-gated-gitops",
            )

            # Should exit with code 1 (any failure = overall failure)
            assert result.returncode == 1

            # Output should indicate which specific SLO failed
            output = result.stdout + result.stderr
            assert "success_rate" in output  # The failing metric should be mentioned

    def test_integration_adapter_unreachable(self):
        """Test gate behavior when adapter is unreachable."""
        if gate_main is None:
            pytest.skip("Gate not implemented yet (RED phase)")

        # Try to connect to non-existent adapter
        slo_string = "latency_p95_ms<=15"
        cmd = [
            sys.executable,
            "-m",
            "gate.gate",
            "--slo",
            slo_string,
            "--url",
            "http://localhost:9999/metrics",  # Non-existent port
        ]

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd="/home/ubuntu/nephio-intent-to-o2-demo/slo-gated-gitops",
        )

        # Should exit with code 1 (connection error)
        assert result.returncode == 1

        # Should log connection error
        output = result.stdout + result.stderr
        assert (
            "connection" in output.lower()
            or "fetch" in output.lower()
            or "error" in output.lower()
        )


class TestCIPipelineScenarios:
    """Test scenarios that would be used in CI pipeline."""

    @pytest.fixture
    def mock_adapter_server(self):
        """Set up a mock adapter server for CI testing."""
        import http.server
        import socketserver
        import json
        import threading
        import time

        class MockHandler(http.server.SimpleHTTPRequestHandler):
            def do_GET(self):
                if self.path == "/metrics":
                    metrics_data = getattr(
                        self.server,
                        "metrics_data",
                        {
                            "latency_p95_ms": 10.0,
                            "success_rate": 0.998,
                            "throughput_p95_mbps": 250.0,
                            "timestamp": "2025-01-01T12:00:00Z",
                        },
                    )

                    self.send_response(200)
                    self.send_header("Content-type", "application/json")
                    self.end_headers()
                    self.wfile.write(json.dumps(metrics_data).encode())
                else:
                    self.send_response(404)
                    self.end_headers()

            def log_message(self, format, *args):
                # Suppress HTTP server logs during tests
                pass

        # Start server on available port
        with socketserver.TCPServer(("", 0), MockHandler) as httpd:
            port = httpd.server_address[1]
            server_thread = threading.Thread(target=httpd.serve_forever, daemon=True)
            server_thread.start()

            # Wait for server to be ready
            time.sleep(0.1)

            yield f"http://localhost:{port}", httpd

            httpd.shutdown()

    def test_ci_violating_metrics_scenario(self, mock_adapter_server):
        """Test CI scenario: first check with violating metrics (should fail)."""
        base_url, httpd = mock_adapter_server

        # Set up bad metrics that will violate SLOs
        httpd.metrics_data = {
            "latency_p95_ms": 25.0,  # Violates <= 15
            "success_rate": 0.990,  # Violates >= 0.995
            "throughput_p95_mbps": 150.0,  # Violates >= 200
            "timestamp": "2025-01-01T12:00:00Z",
        }

        # Run gate CLI against violating metrics
        cmd = [
            "python3",
            "-m",
            "gate.gate",
            "--slo",
            "latency_p95_ms<=15,success_rate>=0.995,throughput_p95_mbps>=200",
            "--url",
            f"{base_url}/metrics",
        ]

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd="/home/ubuntu/nephio-intent-to-o2-demo/slo-gated-gitops",
        )

        # Should fail in CI when metrics violate SLOs
        assert (
            result.returncode == 1
        ), f"Expected exit code 1, got {result.returncode}. stderr: {result.stderr}"

        # Should log failure details in JSON format
        assert "slo_validation" in result.stderr or "FAILED" in result.stderr

    def test_ci_compliant_metrics_scenario(self, mock_adapter_server):
        """Test CI scenario: metrics are compliant (should pass)."""
        base_url, httpd = mock_adapter_server

        # Set up good metrics that will pass SLOs
        httpd.metrics_data = {
            "latency_p95_ms": 12.0,  # Passes <= 15
            "success_rate": 0.997,  # Passes >= 0.995
            "throughput_p95_mbps": 220.0,  # Passes >= 200
            "timestamp": "2025-01-01T12:00:00Z",
        }

        # Run gate CLI against compliant metrics
        cmd = [
            "python3",
            "-m",
            "gate.gate",
            "--slo",
            "latency_p95_ms<=15,success_rate>=0.995,throughput_p95_mbps>=200",
            "--url",
            f"{base_url}/metrics",
        ]

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd="/home/ubuntu/nephio-intent-to-o2-demo/slo-gated-gitops",
        )

        # Should pass in CI when metrics meet SLOs
        assert (
            result.returncode == 0
        ), f"Expected exit code 0, got {result.returncode}. stderr: {result.stderr}"

        # Should log success in JSON format
        assert "slo_validation" in result.stderr or "PASSED" in result.stderr

    def test_ci_pipeline_sequence(self, mock_adapter_server):
        """Test full CI scenario: bad metrics first, then good metrics after fix."""
        base_url, httpd = mock_adapter_server

        # PHASE 1: Bad metrics (should fail)
        httpd.metrics_data = {
            "latency_p95_ms": 25.0,  # Violates <= 15
            "success_rate": 0.990,  # Violates >= 0.995
            "throughput_p95_mbps": 150.0,  # Violates >= 200
            "timestamp": "2025-01-01T12:00:00Z",
        }

        cmd = [
            "python3",
            "-m",
            "gate.gate",
            "--slo",
            "latency_p95_ms<=15,success_rate>=0.995,throughput_p95_mbps>=200",
            "--url",
            f"{base_url}/metrics",
        ]

        result1 = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd="/home/ubuntu/nephio-intent-to-o2-demo/slo-gated-gitops",
        )

        assert result1.returncode == 1, "Phase 1 should fail with bad metrics"

        # PHASE 2: Good metrics after "fix" (should pass)
        httpd.metrics_data = {
            "latency_p95_ms": 12.0,  # Passes <= 15
            "success_rate": 0.997,  # Passes >= 0.995
            "throughput_p95_mbps": 220.0,  # Passes >= 200
            "timestamp": "2025-01-01T12:00:01Z",
        }

        result2 = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd="/home/ubuntu/nephio-intent-to-o2-demo/slo-gated-gitops",
        )

        assert result2.returncode == 0, "Phase 2 should pass with good metrics"


class TestDeterministicBehavior:
    """Test that the pipeline behaves deterministically."""

    def test_repeated_calls_same_result(self):
        """Test that repeated gate calls with same inputs produce same results."""
        if gate_main is None:
            pytest.skip("Gate not implemented yet (RED phase)")

        # Mock stable metrics
        stable_metrics = {
            "latency_p95_ms": 12.0,
            "success_rate": 0.997,
            "throughput_p95_mbps": 220.0,
            "timestamp": "2025-01-01T12:00:00Z",
        }

        results = []

        with patch("gate.fetch_metrics", return_value=stable_metrics):
            for _ in range(3):
                with patch(
                    "sys.argv",
                    ["gate", "--slo", "latency_p95_ms<=15", "--url", "http://test"],
                ):
                    exit_code = gate_main()
                    results.append(exit_code)

        # All results should be identical
        assert all(
            r == results[0] for r in results
        ), "Gate should produce deterministic results"
        assert results[0] == 0, "Stable good metrics should always pass"

    def test_cli_deterministic_exit_codes(self):
        """Test that CLI produces consistent exit codes for same inputs."""
        # Test multiple CLI calls with mocked stable metrics
        stable_metrics = {
            "latency_p95_ms": 12.0,
            "success_rate": 0.997,
            "throughput_p95_mbps": 220.0,
            "timestamp": "2025-01-01T12:00:00Z",
        }

        exit_codes = []

        with patch("gate.fetch_metrics", return_value=stable_metrics):
            for _ in range(3):
                with patch(
                    "sys.argv",
                    ["gate", "--slo", "latency_p95_ms<=15", "--url", "http://test"],
                ):
                    # Use direct call instead of subprocess for deterministic testing
                    exit_code = gate_main()
                    exit_codes.append(exit_code)

        # All exit codes should be identical
        assert all(
            code == exit_codes[0] for code in exit_codes
        ), "CLI should produce deterministic exit codes"
        assert exit_codes[0] == 0, "Stable good metrics should consistently pass"

    def test_json_logging_deterministic_structure(self, caplog):
        """Test that JSON logs have consistent structure across runs."""
        if gate_main is None:
            pytest.skip("Gate not implemented yet (RED phase)")

        metrics = {
            "latency_p95_ms": 12.0,
            "success_rate": 0.997,
            "throughput_p95_mbps": 220.0,
        }

        log_structures = []

        for _ in range(2):
            caplog.clear()
            with patch("gate.gate.fetch_metrics", return_value=metrics):
                with patch(
                    "sys.argv",
                    ["gate", "--slo", "latency_p95_ms<=15", "--url", "http://test"],
                ):
                    gate_main()

            # Extract JSON log structure
            for record in caplog.records:
                try:
                    log_data = json.loads(record.message)
                    log_structures.append(set(log_data.keys()))
                    break
                except (json.JSONDecodeError, AttributeError):
                    continue

        # Log structures should be identical
        if len(log_structures) >= 2:
            assert (
                log_structures[0] == log_structures[1]
            ), "JSON log structure should be consistent"


class TestSecurityCompliance:
    """Test security compliance (no plaintext secrets, etc.)."""

    def test_no_hardcoded_secrets_in_config(self):
        """Test that configuration follows .env.example pattern."""
        # Check that sensitive values come from environment, not hardcoded

        # This test will verify our implementation follows security rules
        # Should not find any hardcoded passwords, tokens, etc.

        import glob

        # Check Python files for potential secrets
        python_files = glob.glob(
            "/home/ubuntu/nephio-intent-to-o2-demo/slo-gated-gitops/**/*.py",
            recursive=True,
        )

        dangerous_patterns = ["password=", "token=", "secret=", "api_key=", "auth="]

        violations = []
        for file_path in python_files:
            try:
                with open(file_path, "r") as f:
                    content = f.read().lower()
                    for pattern in dangerous_patterns:
                        if pattern in content and "os.environ" not in content:
                            # Allow if it's clearly getting from environment
                            violations.append(f"{file_path}: Found {pattern}")
            except (IOError, UnicodeDecodeError):
                continue  # Skip files we can't read

        # During RED phase, files don't exist yet, so this is expected to pass
        assert len(violations) == 0, f"Found potential hardcoded secrets: {violations}"

    def test_configuration_from_environment(self):
        """Test that configuration properly reads from environment variables."""
        # This will verify our implementation uses environment variables
        # instead of hardcoded values

        import os

        # Test environment variable usage
        test_env_vars = {
            "ADAPTER_PORT": "8080",
            "ADAPTER_HOST": "0.0.0.0",
            "METRICS_URL": "http://localhost:8080/metrics",
            "LOG_LEVEL": "INFO",
        }

        with patch.dict(os.environ, test_env_vars):
            # During GREEN phase, implementation should respect these
            if create_app is not None:
                app = create_app()
                # App should be configurable
                assert app is not None
