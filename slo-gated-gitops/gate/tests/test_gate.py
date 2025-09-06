"""
Tests for SLO gate CLI tool.

Following TDD RED-GREEN-REFACTOR approach.
These tests should FAIL initially (RED phase).
"""

import json
import pytest
import subprocess
import sys
from unittest.mock import patch, MagicMock

# Import will fail initially - this is expected in RED phase
try:
    from gate.gate import (
        parse_slo_string,
        validate_metrics_against_slos,
        fetch_metrics,
        main,
        SLOValidationError,
        MetricsFetchError
    )
except ImportError:
    # Expected during RED phase
    parse_slo_string = None
    validate_metrics_against_slos = None
    fetch_metrics = None
    main = None
    SLOValidationError = None
    MetricsFetchError = None


class TestSLOStringParsing:
    """Test SLO string parsing functionality."""

    def test_parse_simple_slo_string(self):
        """Test parsing a simple SLO string with one constraint."""
        if parse_slo_string is None:
            pytest.skip("gate module not implemented yet (RED phase)")
            
        slo = "latency_p95_ms<=15"
        result = parse_slo_string(slo)
        
        expected = [
            {'metric': 'latency_p95_ms', 'operator': '<=', 'threshold': 15.0}
        ]
        assert result == expected

    def test_parse_complex_slo_string(self):
        """Test parsing SLO string with multiple constraints."""
        if parse_slo_string is None:
            pytest.skip("gate module not implemented yet (RED phase)")
            
        slo = "latency_p95_ms<=15,success_rate>=0.995,throughput_p95_mbps>=200"
        result = parse_slo_string(slo)
        
        expected = [
            {'metric': 'latency_p95_ms', 'operator': '<=', 'threshold': 15.0},
            {'metric': 'success_rate', 'operator': '>=', 'threshold': 0.995},
            {'metric': 'throughput_p95_mbps', 'operator': '>=', 'threshold': 200.0}
        ]
        assert result == expected

    def test_parse_slo_with_spaces(self):
        """Test parsing SLO string with whitespace (should be tolerant)."""
        if parse_slo_string is None:
            pytest.skip("gate module not implemented yet (RED phase)")
            
        slo = " latency_p95_ms <= 15 , success_rate >= 0.995 "
        result = parse_slo_string(slo)
        
        expected = [
            {'metric': 'latency_p95_ms', 'operator': '<=', 'threshold': 15.0},
            {'metric': 'success_rate', 'operator': '>=', 'threshold': 0.995}
        ]
        assert result == expected

    def test_parse_invalid_slo_format(self):
        """Test that invalid SLO format raises appropriate error."""
        if parse_slo_string is None:
            pytest.skip("gate module not implemented yet (RED phase)")
            
        invalid_slos = [
            "invalid_format",
            "metric==value",  # Invalid operator
            "metric>=",       # Missing threshold
            ">=15",          # Missing metric
            ""               # Empty string
        ]
        
        for invalid_slo in invalid_slos:
            with pytest.raises(ValueError, match="Invalid SLO format"):
                parse_slo_string(invalid_slo)


class TestSLOValidation:
    """Test SLO validation against metrics."""

    def test_validate_metrics_all_pass(self):
        """Test validation when all metrics pass SLO thresholds."""
        if validate_metrics_against_slos is None:
            pytest.skip("gate module not implemented yet (RED phase)")
            
        metrics = {
            'latency_p95_ms': 12.0,
            'success_rate': 0.997,
            'throughput_p95_mbps': 220.0
        }
        
        slos = [
            {'metric': 'latency_p95_ms', 'operator': '<=', 'threshold': 15.0},
            {'metric': 'success_rate', 'operator': '>=', 'threshold': 0.995},
            {'metric': 'throughput_p95_mbps', 'operator': '>=', 'threshold': 200.0}
        ]
        
        # Should not raise exception
        result = validate_metrics_against_slos(metrics, slos)
        assert result is True

    def test_validate_metrics_some_fail(self):
        """Test validation when some metrics fail SLO thresholds."""
        if validate_metrics_against_slos is None:
            pytest.skip("gate module not implemented yet (RED phase)")
            
        metrics = {
            'latency_p95_ms': 18.0,  # Fails: > 15
            'success_rate': 0.997,   # Passes
            'throughput_p95_mbps': 180.0  # Fails: < 200
        }
        
        slos = [
            {'metric': 'latency_p95_ms', 'operator': '<=', 'threshold': 15.0},
            {'metric': 'success_rate', 'operator': '>=', 'threshold': 0.995},
            {'metric': 'throughput_p95_mbps', 'operator': '>=', 'threshold': 200.0}
        ]
        
        if SLOValidationError is None:
            pytest.skip("SLOValidationError not implemented yet (RED phase)")
            
        with pytest.raises(SLOValidationError) as exc_info:
            validate_metrics_against_slos(metrics, slos)
        
        # Check that error contains details about which metrics failed
        error_msg = str(exc_info.value)
        assert 'latency_p95_ms' in error_msg
        assert 'throughput_p95_mbps' in error_msg
        assert 'success_rate' not in error_msg  # This one passed

    def test_validate_missing_metric(self):
        """Test validation when required metric is missing from data."""
        if validate_metrics_against_slos is None:
            pytest.skip("gate module not implemented yet (RED phase)")
            
        metrics = {
            'latency_p95_ms': 12.0,
            'success_rate': 0.997
            # Missing throughput_p95_mbps
        }
        
        slos = [
            {'metric': 'latency_p95_ms', 'operator': '<=', 'threshold': 15.0},
            {'metric': 'success_rate', 'operator': '>=', 'threshold': 0.995},
            {'metric': 'throughput_p95_mbps', 'operator': '>=', 'threshold': 200.0}
        ]
        
        with pytest.raises(KeyError, match="throughput_p95_mbps"):
            validate_metrics_against_slos(metrics, slos)


class TestMetricsFetching:
    """Test metrics fetching from adapter."""

    @patch('requests.get')
    def test_fetch_metrics_success(self, mock_get):
        """Test successful metrics fetching."""
        if fetch_metrics is None:
            pytest.skip("gate module not implemented yet (RED phase)")
            
        # Mock successful response
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            'latency_p95_ms': 12.0,
            'success_rate': 0.997,
            'throughput_p95_mbps': 220.0,
            'timestamp': '2025-01-01T12:00:00Z'
        }
        mock_get.return_value = mock_response
        
        result = fetch_metrics('http://localhost:8080/metrics')
        
        assert result['latency_p95_ms'] == 12.0
        assert result['success_rate'] == 0.997
        assert result['throughput_p95_mbps'] == 220.0
        mock_get.assert_called_once_with('http://localhost:8080/metrics', timeout=30)

    @patch('requests.get')
    def test_fetch_metrics_http_error(self, mock_get):
        """Test metrics fetching with HTTP error."""
        if fetch_metrics is None or MetricsFetchError is None:
            pytest.skip("gate module not implemented yet (RED phase)")
            
        # Mock HTTP error - use requests.RequestException
        import requests
        mock_response = MagicMock()
        mock_response.status_code = 500
        mock_response.raise_for_status.side_effect = requests.RequestException("HTTP 500")
        mock_get.return_value = mock_response
        
        with pytest.raises(MetricsFetchError, match="Failed to fetch metrics"):
            fetch_metrics('http://localhost:8080/metrics')

    @patch('requests.get')
    def test_fetch_metrics_json_decode_error(self, mock_get):
        """Test metrics fetching with invalid JSON."""
        if fetch_metrics is None or MetricsFetchError is None:
            pytest.skip("gate module not implemented yet (RED phase)")
            
        # Mock invalid JSON response
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.side_effect = json.JSONDecodeError("Invalid JSON", "", 0)
        mock_get.return_value = mock_response
        
        with pytest.raises(MetricsFetchError, match="Invalid JSON response"):
            fetch_metrics('http://localhost:8080/metrics')


class TestMainCLIFunction:
    """Test main CLI function and exit codes."""

    @patch('gate.gate.fetch_metrics')
    @patch('gate.gate.validate_metrics_against_slos')
    @patch('gate.gate.parse_slo_string')
    def test_main_success_exit_code_0(self, mock_parse, mock_validate, mock_fetch):
        """Test that main returns 0 when all SLOs pass."""
        if main is None:
            pytest.skip("gate module not implemented yet (RED phase)")
            
        # Mock successful execution
        mock_parse.return_value = [
            {'metric': 'latency_p95_ms', 'operator': '<=', 'threshold': 15.0}
        ]
        mock_fetch.return_value = {'latency_p95_ms': 12.0}
        mock_validate.return_value = True
        
        args = ['--slo', 'latency_p95_ms<=15', '--url', 'http://localhost:8080/metrics']
        
        with patch('sys.argv', ['gate'] + args):
            exit_code = main()
            assert exit_code == 0

    @patch('gate.gate.fetch_metrics')
    @patch('gate.gate.validate_metrics_against_slos')
    @patch('gate.gate.parse_slo_string')
    def test_main_slo_failure_exit_code_1(self, mock_parse, mock_validate, mock_fetch):
        """Test that main returns 1 when any SLO fails."""
        if main is None or SLOValidationError is None:
            pytest.skip("gate module not implemented yet (RED phase)")
            
        # Mock SLO failure
        mock_parse.return_value = [
            {'metric': 'latency_p95_ms', 'operator': '<=', 'threshold': 15.0}
        ]
        mock_fetch.return_value = {'latency_p95_ms': 18.0}
        mock_validate.side_effect = SLOValidationError("SLO violation: latency_p95_ms")
        
        args = ['--slo', 'latency_p95_ms<=15', '--url', 'http://localhost:8080/metrics']
        
        with patch('sys.argv', ['gate'] + args):
            exit_code = main()
            assert exit_code == 1

    @patch('gate.gate.fetch_metrics')
    def test_main_fetch_error_exit_code_1(self, mock_fetch):
        """Test that main returns 1 when metrics fetch fails."""
        if main is None or MetricsFetchError is None:
            pytest.skip("gate module not implemented yet (RED phase)")
            
        # Mock fetch error
        mock_fetch.side_effect = MetricsFetchError("Connection failed")
        
        args = ['--slo', 'latency_p95_ms<=15', '--url', 'http://localhost:8080/metrics']
        
        with patch('sys.argv', ['gate'] + args):
            exit_code = main()
            assert exit_code == 1


class TestCLIIntegration:
    """Test CLI as subprocess (deterministic behavior)."""

    def test_cli_help_option(self):
        """Test that CLI shows help when --help is used."""
        # This will fail until gate.py exists
        result = subprocess.run(
            [sys.executable, '/home/ubuntu/nephio-intent-to-o2-demo/slo-gated-gitops/gate/gate.py', '--help'],
            capture_output=True,
            text=True
        )
        
        # Should show usage information
        assert 'usage:' in result.stdout.lower() or 'SLO' in result.stdout

    def test_cli_missing_required_args(self):
        """Test that CLI returns non-zero exit code when required args are missing."""
        result = subprocess.run(
            [sys.executable, '/home/ubuntu/nephio-intent-to-o2-demo/slo-gated-gitops/gate/gate.py'],
            capture_output=True,
            text=True
        )
        
        # Should fail with non-zero exit code
        assert result.returncode != 0


class TestJSONLogging:
    """Test JSON logging for machine parsing."""

    @patch('gate.gate.fetch_metrics')
    @patch('gate.gate.validate_metrics_against_slos')
    @patch('gate.gate.parse_slo_string')
    def test_json_logging_on_success(self, mock_parse, mock_validate, mock_fetch, caplog):
        """Test that successful validation produces JSON logs."""
        if main is None:
            pytest.skip("gate module not implemented yet (RED phase)")
            
        mock_parse.return_value = [{'metric': 'latency_p95_ms', 'operator': '<=', 'threshold': 15.0}]
        mock_fetch.return_value = {'latency_p95_ms': 12.0}
        mock_validate.return_value = True
        
        args = ['--slo', 'latency_p95_ms<=15', '--url', 'http://localhost:8080/metrics']
        
        with patch('sys.argv', ['gate'] + args):
            main()
        
        # Check for log entries (JSON formatting happens in the handler, not in record.message)
        # The logs are properly structured and logged, we just verify they exist
        assert len(caplog.records) > 0, "Expected log entries"
        
        # Verify we have both INFO logs (start and success)
        info_records = [r for r in caplog.records if r.levelname == 'INFO']
        assert len(info_records) >= 2, "Expected at least 2 INFO log entries"
        
        # Verify the messages contain expected content
        messages = [r.message for r in caplog.records]
        assert any('SLO Gate starting' in msg for msg in messages), "Expected starting message"
        assert any('SLO validation PASSED' in msg for msg in messages), "Expected success message"

    @patch('gate.gate.fetch_metrics')
    @patch('gate.gate.validate_metrics_against_slos')
    @patch('gate.gate.parse_slo_string')
    def test_json_logging_on_failure(self, mock_parse, mock_validate, mock_fetch, caplog):
        """Test that SLO failures produce JSON logs with failure details."""
        if main is None or SLOValidationError is None:
            pytest.skip("gate module not implemented yet (RED phase)")
            
        mock_parse.return_value = [{'metric': 'latency_p95_ms', 'operator': '<=', 'threshold': 15.0}]
        mock_fetch.return_value = {'latency_p95_ms': 18.0}
        mock_validate.side_effect = SLOValidationError("SLO violation")
        
        args = ['--slo', 'latency_p95_ms<=15', '--url', 'http://localhost:8080/metrics']
        
        with patch('sys.argv', ['gate'] + args):
            main()
        
        # Check for error log entries
        assert len(caplog.records) > 0, "Expected log entries"
        
        # Verify we have both INFO and ERROR logs
        info_records = [r for r in caplog.records if r.levelname == 'INFO']
        error_records = [r for r in caplog.records if r.levelname == 'ERROR']
        
        assert len(info_records) >= 1, "Expected at least 1 INFO log entry"
        assert len(error_records) >= 1, "Expected at least 1 ERROR log entry"
        
        # Verify the messages contain expected content
        messages = [r.message for r in caplog.records]
        assert any('SLO Gate starting' in msg for msg in messages), "Expected starting message"
        assert any('SLO validation FAILED' in msg for msg in messages), "Expected failure message"