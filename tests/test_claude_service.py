#!/usr/bin/env python3
"""
TDD Tests for Claude Headless Service
Following Test-Driven Development principles from ULTIMATE_DEVELOPMENT_PLAN.md
"""

import pytest
import asyncio
import json
from unittest.mock import Mock, patch, AsyncMock
import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from services.claude_headless import ClaudeHeadlessService, IntentRequest

class TestClaudeHeadlessService:
    """Test suite for Claude CLI headless mode integration"""

    def test_claude_cli_headless_mode(self):
        """Test that Claude CLI runs in headless mode with JSON output"""
        # Arrange
        test_prompt = "Convert 'Deploy eMBB on edge1' to TMF921"
        expected_output = {
            "intentType": "eMBB",
            "targetSites": ["edge01"],
            "serviceProfile": {
                "bandwidth": "100Mbps"
            }
        }

        # Act - Create service and mock the subprocess call
        service = ClaudeHeadlessService()

        with patch('subprocess.run') as mock_run:
            mock_run.return_value = Mock(
                returncode=0,
                stdout=json.dumps(expected_output),
                stderr=""
            )

            # Run synchronously for testing
            result = asyncio.run(service.process_intent(test_prompt, use_cache=False))

        # Assert
        assert "intentType" in result
        assert result["intentType"] == "eMBB"
        assert isinstance(result.get("targetSites"), list)

    def test_claude_cli_timeout_handling(self):
        """Test timeout handling for Claude CLI calls"""
        # Arrange
        service = ClaudeHeadlessService()
        service.timeout = 0.1  # Set very short timeout

        # Act & Assert
        with patch('asyncio.wait_for') as mock_wait:
            mock_wait.side_effect = asyncio.TimeoutError()

            # Should fall back to rule-based processing
            result = asyncio.run(service.process_intent("Deploy eMBB", use_cache=False))

            assert result.get("_fallback") is True
            assert "intentType" in result

    def test_fallback_to_rule_engine(self):
        """Test fallback when Claude is unavailable"""
        # Arrange
        service = ClaudeHeadlessService()
        test_prompt = "Deploy eMBB service on edge1 with 200Mbps"

        # Act - Mock subprocess to fail
        with patch('asyncio.create_subprocess_exec') as mock_exec:
            mock_proc = AsyncMock()
            mock_proc.returncode = 1
            mock_proc.communicate = AsyncMock(return_value=(b"", b"Error"))
            mock_exec.return_value = mock_proc

            result = asyncio.run(service.process_intent(test_prompt, use_cache=False))

        # Assert
        assert result["_fallback"] is True
        assert result["intentType"] == "eMBB"
        assert "edge01" in result["targetSites"]
        assert result["serviceProfile"]["bandwidth"] == "200MBPS"

    def test_tmf921_intent_format(self):
        """Test that output conforms to TMF921 intent format"""
        # Arrange
        service = ClaudeHeadlessService()
        test_input = "Deploy URLLC service with 1ms latency for autonomous vehicles"

        # Act - Use fallback for predictable output
        with patch('asyncio.create_subprocess_exec') as mock_exec:
            mock_proc = AsyncMock()
            mock_proc.returncode = 1  # Force fallback
            mock_proc.communicate = AsyncMock(return_value=(b"", b"Error"))
            mock_exec.return_value = mock_proc

            result = asyncio.run(service.process_intent(test_input, use_cache=False))

        # Assert TMF921 fields
        assert "intentId" in result
        assert "intentType" in result
        assert result["intentType"] == "URLLC"
        assert "serviceProfile" in result
        assert result["serviceProfile"]["latency"] == "1ms"

    def test_cache_functionality(self):
        """Test that caching works correctly"""
        # Arrange
        service = ClaudeHeadlessService()
        test_prompt = "Deploy mMTC for IoT devices"

        # Act - First call should process
        with patch('asyncio.create_subprocess_exec') as mock_exec:
            mock_proc = AsyncMock()
            mock_proc.returncode = 0
            mock_proc.communicate = AsyncMock(return_value=(
                json.dumps({"intentType": "mMTC", "cached": False}).encode(),
                b""
            ))
            mock_exec.return_value = mock_proc

            result1 = asyncio.run(service.process_intent(test_prompt, use_cache=True))

        # Second call should use cache (mock not called)
        result2 = asyncio.run(service.process_intent(test_prompt, use_cache=True))

        # Assert
        assert result1 == result2
        assert service.cache != {}

    @pytest.mark.asyncio
    async def test_concurrent_processing(self):
        """Test handling of concurrent intent processing"""
        # Arrange
        service = ClaudeHeadlessService()
        intents = [
            "Deploy eMBB on edge1",
            "Deploy URLLC on edge2",
            "Deploy mMTC on both edges"
        ]

        # Act - Process all intents concurrently
        with patch('asyncio.create_subprocess_exec') as mock_exec:
            mock_proc = AsyncMock()
            mock_proc.returncode = 1  # Force fallback for speed
            mock_proc.communicate = AsyncMock(return_value=(b"", b"Error"))
            mock_exec.return_value = mock_proc

            tasks = [service.process_intent(intent) for intent in intents]
            results = await asyncio.gather(*tasks)

        # Assert
        assert len(results) == 3
        assert results[0]["intentType"] == "eMBB"
        assert results[1]["intentType"] == "URLLC"
        assert results[2]["intentType"] == "mMTC"

    def test_error_recovery(self):
        """Test graceful error recovery"""
        # Arrange
        service = ClaudeHeadlessService()

        # Act - Test with malformed JSON response
        with patch('asyncio.create_subprocess_exec') as mock_exec:
            mock_proc = AsyncMock()
            mock_proc.returncode = 0
            mock_proc.communicate = AsyncMock(return_value=(
                b"Not valid JSON {broken",
                b""
            ))
            mock_exec.return_value = mock_proc

            result = asyncio.run(service.process_intent("Deploy service"))

        # Assert - Should fallback gracefully
        assert result["_fallback"] is True
        assert "intentType" in result

class TestIntentAPI:
    """Test API endpoints for intent processing"""

    @pytest.fixture
    def client(self):
        """Create test client"""
        from fastapi.testclient import TestClient
        from services.claude_headless import app
        return TestClient(app)

    def test_health_endpoint(self, client):
        """Test health check endpoint"""
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert "status" in data
        assert "claude" in data

    def test_process_intent_endpoint(self, client):
        """Test intent processing endpoint"""
        # Arrange
        request_data = {
            "text": "Deploy eMBB service on edge1",
            "target_sites": ["edge01"]
        }

        # Act
        with patch('services.claude_headless.service.process_intent') as mock_process:
            mock_process.return_value = asyncio.coroutine(lambda: {
                "intentType": "eMBB",
                "targetSites": ["edge01"]
            })()

            response = client.post("/api/v1/intent", json=request_data)

        # Assert
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        assert "intent" in data

    def test_batch_intent_endpoint(self, client):
        """Test batch intent processing"""
        # Arrange
        requests = [
            {"text": "Deploy eMBB on edge1"},
            {"text": "Deploy URLLC on edge2"}
        ]

        # Act
        with patch('services.claude_headless.service.process_intent') as mock_process:
            mock_process.side_effect = [
                asyncio.coroutine(lambda: {"intentType": "eMBB"})(),
                asyncio.coroutine(lambda: {"intentType": "URLLC"})()
            ]

            response = client.post("/api/v1/intent/batch", json=requests)

        # Assert
        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 2
        assert len(data["results"]) == 2

if __name__ == "__main__":
    # Run tests with coverage
    pytest.main([__file__, "-v", "--cov=services.claude_headless", "--cov-report=term-missing"])