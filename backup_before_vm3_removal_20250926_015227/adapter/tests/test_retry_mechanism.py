#!/usr/bin/env python3
"""
Unit tests for retry mechanism with exponential backoff
"""

import pytest
import time
import subprocess
from unittest.mock import Mock, patch, MagicMock
from pathlib import Path
import sys

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.main import (
    RetryConfig,
    calculate_backoff_delay,
    call_claude_with_retry,
    Metrics,
    validate_and_fix_json
)


class TestBackoffCalculation:
    """Test exponential backoff delay calculation"""

    def test_exponential_growth(self):
        """Test that delays grow exponentially"""
        config = RetryConfig(
            initial_delay=1.0,
            exponential_base=2.0,
            max_delay=100.0,
            jitter=False
        )

        delays = [calculate_backoff_delay(i, config) for i in range(4)]

        assert delays[0] == 1.0  # 1 * 2^0
        assert delays[1] == 2.0  # 1 * 2^1
        assert delays[2] == 4.0  # 1 * 2^2
        assert delays[3] == 8.0  # 1 * 2^3

    def test_max_delay_cap(self):
        """Test that delays are capped at max_delay"""
        config = RetryConfig(
            initial_delay=1.0,
            exponential_base=2.0,
            max_delay=5.0,
            jitter=False
        )

        delays = [calculate_backoff_delay(i, config) for i in range(5)]

        assert delays[0] == 1.0
        assert delays[1] == 2.0
        assert delays[2] == 4.0
        assert delays[3] == 5.0  # Capped at max_delay
        assert delays[4] == 5.0  # Still capped

    def test_jitter_adds_randomness(self):
        """Test that jitter adds randomness to delays"""
        config = RetryConfig(
            initial_delay=1.0,
            exponential_base=2.0,
            max_delay=100.0,
            jitter=True
        )

        # Generate multiple delays for the same attempt
        delays = [calculate_backoff_delay(1, config) for _ in range(10)]

        # With jitter, delays should vary
        assert len(set(delays)) > 1
        # But all should be within expected range (2.0 to 2.5 with 25% jitter)
        assert all(2.0 <= d <= 2.5 for d in delays)


class TestRetryLogic:
    """Test retry logic with mocked subprocess calls"""

    @patch('subprocess.run')
    def test_success_on_first_attempt(self, mock_run):
        """Test successful call on first attempt"""
        mock_run.return_value = MagicMock(
            stdout='{"test": "success"}',
            stderr='',
            returncode=0
        )

        output, retries = call_claude_with_retry("test prompt")

        assert output == '{"test": "success"}'
        assert retries == 0
        assert mock_run.call_count == 1

    @patch('subprocess.run')
    @patch('time.sleep')  # Mock sleep to speed up tests
    def test_retry_on_failure(self, mock_sleep, mock_run):
        """Test retry on transient failures"""
        # Fail twice, then succeed
        mock_run.side_effect = [
            MagicMock(stdout='', stderr='temporary error', returncode=1),
            MagicMock(stdout='', stderr='temporary error', returncode=1),
            MagicMock(stdout='{"test": "success"}', stderr='', returncode=0)
        ]

        config = RetryConfig(max_retries=3, initial_delay=0.1, jitter=False)
        output, retries = call_claude_with_retry("test prompt", config)

        assert output == '{"test": "success"}'
        assert retries == 2
        assert mock_run.call_count == 3
        assert mock_sleep.call_count == 2

    @patch('subprocess.run')
    def test_no_retry_on_auth_error(self, mock_run):
        """Test that auth errors are not retried"""
        mock_run.return_value = MagicMock(
            stdout='',
            stderr='Permission denied: unauthorized access',
            returncode=1
        )

        config = RetryConfig(max_retries=3)

        with pytest.raises(Exception) as exc_info:
            call_claude_with_retry("test prompt", config)

        assert mock_run.call_count == 1  # No retries
        # Check that it's a permission error (403)
        assert hasattr(exc_info.value, 'status_code')
        assert exc_info.value.status_code == 403

    @patch('subprocess.run')
    def test_no_retry_on_invalid_input(self, mock_run):
        """Test that invalid input errors are not retried"""
        mock_run.return_value = MagicMock(
            stdout='',
            stderr='Invalid prompt syntax',
            returncode=1
        )

        config = RetryConfig(max_retries=3)

        with pytest.raises(Exception) as exc_info:
            call_claude_with_retry("test prompt", config)

        assert mock_run.call_count == 1  # No retries
        # Check that it's an invalid input error (400)
        assert hasattr(exc_info.value, 'status_code')
        assert exc_info.value.status_code == 400

    @patch('subprocess.run')
    @patch('time.sleep')
    def test_timeout_retry(self, mock_sleep, mock_run):
        """Test retry on timeout"""
        # Timeout twice, then succeed
        mock_run.side_effect = [
            subprocess.TimeoutExpired('cmd', 20),
            subprocess.TimeoutExpired('cmd', 20),
            MagicMock(stdout='{"test": "success"}', stderr='', returncode=0)
        ]

        config = RetryConfig(max_retries=3, initial_delay=0.1, jitter=False)
        output, retries = call_claude_with_retry("test prompt", config)

        assert output == '{"test": "success"}'
        assert retries == 2
        assert mock_run.call_count == 3

    @patch('subprocess.run')
    @patch('time.sleep')
    def test_max_retries_exhausted(self, mock_sleep, mock_run):
        """Test failure when max retries are exhausted"""
        mock_run.return_value = MagicMock(
            stdout='',
            stderr='temporary error',
            returncode=1
        )

        config = RetryConfig(max_retries=2, initial_delay=0.1, jitter=False)

        with pytest.raises(Exception) as exc_info:
            call_claude_with_retry("test prompt", config)

        assert mock_run.call_count == 3  # Initial + 2 retries
        # Check that it's a service unavailable error (503)
        assert hasattr(exc_info.value, 'status_code')
        assert exc_info.value.status_code == 503


class TestMetrics:
    """Test metrics tracking"""

    def test_metrics_tracking(self):
        """Test that metrics are tracked correctly"""
        metrics = Metrics()

        # Record some requests
        metrics.record_request(success=True, retries=0)
        metrics.record_request(success=True, retries=2)
        metrics.record_request(success=False, retries=3)
        metrics.record_request(success=True, retries=0)

        stats = metrics.get_stats()

        assert stats["total_requests"] == 4
        assert stats["successful_requests"] == 3
        assert stats["failed_requests"] == 1
        assert stats["retry_attempts"] == 2  # 2 requests had retries
        assert stats["total_retries"] == 5  # 2 + 3 retries
        assert stats["success_rate"] == 0.75
        assert stats["retry_rate"] == 0.5

    def test_metrics_empty_state(self):
        """Test metrics with no data"""
        metrics = Metrics()
        stats = metrics.get_stats()

        assert stats["total_requests"] == 0
        assert stats["successful_requests"] == 0
        assert stats["failed_requests"] == 0
        assert stats["success_rate"] == 0.0
        assert stats["retry_rate"] == 0.0


class TestJSONValidation:
    """Test JSON validation and fixing"""

    def test_fix_string_numbers_in_qos(self):
        """Test conversion of string numbers to actual numbers"""
        intent = {
            "qos": {
                "dl_mbps": "100",
                "ul_mbps": "50.5",
                "latency_ms": "10"
            }
        }

        fixed = validate_and_fix_json(intent)

        assert fixed["qos"]["dl_mbps"] == 100
        assert fixed["qos"]["ul_mbps"] == 50.5
        assert fixed["qos"]["latency_ms"] == 10

    def test_fix_invalid_qos_values(self):
        """Test handling of invalid QoS values"""
        intent = {
            "qos": {
                "dl_mbps": "invalid",
                "ul_mbps": None,
                "latency_ms": "10ms"  # Invalid format
            }
        }

        fixed = validate_and_fix_json(intent)

        assert fixed["qos"]["dl_mbps"] is None
        assert fixed["qos"]["ul_mbps"] is None
        assert fixed["qos"]["latency_ms"] is None

    def test_fix_string_sst(self):
        """Test conversion of string SST to integer"""
        intent = {
            "slice": {
                "sst": "2"
            }
        }

        fixed = validate_and_fix_json(intent)

        assert fixed["slice"]["sst"] == 2
        assert isinstance(fixed["slice"]["sst"], int)

    def test_fix_invalid_sst(self):
        """Test handling of invalid SST values"""
        intent = {
            "slice": {
                "sst": "invalid"
            }
        }

        fixed = validate_and_fix_json(intent)

        assert fixed["slice"]["sst"] == 1  # Default to eMBB

    def test_fix_invalid_targetsite(self):
        """Test correction of invalid targetSite values"""
        intent = {
            "targetSite": "invalid_site"
        }

        fixed = validate_and_fix_json(intent)

        assert fixed["targetSite"] == "both"  # Default to both

    def test_preserve_valid_values(self):
        """Test that valid values are preserved"""
        intent = {
            "targetSite": "edge1",
            "qos": {
                "dl_mbps": 100,
                "ul_mbps": 50
            },
            "slice": {
                "sst": 2
            }
        }

        fixed = validate_and_fix_json(intent)

        assert fixed == intent  # Nothing should change


class TestIntegration:
    """Integration tests for retry mechanism"""

    @patch('subprocess.run')
    @patch('time.sleep')
    def test_exponential_backoff_timing(self, mock_sleep, mock_run):
        """Test that exponential backoff delays are applied correctly"""
        # Fail 3 times, then succeed
        mock_run.side_effect = [
            MagicMock(stdout='', stderr='error', returncode=1),
            MagicMock(stdout='', stderr='error', returncode=1),
            MagicMock(stdout='', stderr='error', returncode=1),
            MagicMock(stdout='{"success": true}', stderr='', returncode=0)
        ]

        config = RetryConfig(
            max_retries=3,
            initial_delay=1.0,
            exponential_base=2.0,
            max_delay=10.0,
            jitter=False
        )

        output, retries = call_claude_with_retry("test", config)

        assert retries == 3
        assert mock_sleep.call_count == 3

        # Check that sleep was called with correct delays
        sleep_calls = [call[0][0] for call in mock_sleep.call_args_list]
        assert sleep_calls[0] == 1.0  # First retry: 1 * 2^0
        assert sleep_calls[1] == 2.0  # Second retry: 1 * 2^1
        assert sleep_calls[2] == 4.0  # Third retry: 1 * 2^2


if __name__ == "__main__":
    pytest.main([__file__, "-v"])