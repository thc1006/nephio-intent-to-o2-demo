"""Pytest configuration and shared fixtures for golden tests."""

import json
import tempfile
from pathlib import Path
from typing import Any, Dict, List
from unittest.mock import Mock

import pytest
import yaml


@pytest.fixture(scope="session")
def test_data_dir():
    """Path to test data directory."""
    return Path(__file__).parent / "fixtures"


@pytest.fixture(scope="session")
def intent_fixtures_dir(test_data_dir):
    """Path to intent fixtures directory."""
    return test_data_dir / "intents"


@pytest.fixture(scope="session")
def expected_outputs_dir(test_data_dir):
    """Path to expected outputs directory."""
    return test_data_dir / "expected"


@pytest.fixture
def temp_workspace():
    """Create a temporary workspace for tests."""
    with tempfile.TemporaryDirectory() as tmpdir:
        workspace = Path(tmpdir)
        (workspace / "input").mkdir()
        (workspace / "output").mkdir()
        (workspace / "expected").mkdir()
        yield workspace


@pytest.fixture
def fixed_timestamp():
    """Fixed timestamp for deterministic testing."""
    return "2024-01-01T00:00:00+00:00"


@pytest.fixture
def mock_kpt_render():
    """Mock kpt fn render command for testing."""
    mock = Mock()
    mock.return_value.returncode = 0
    mock.return_value.stdout = ""
    mock.return_value.stderr = ""
    return mock


def load_yaml_file(file_path: Path) -> Any:
    """Load and return contents of a YAML file."""
    with open(file_path, "r") as f:
        return yaml.safe_load(f)


def load_json_file(file_path: Path) -> Dict[str, Any]:
    """Load and return contents of a JSON file."""
    with open(file_path, "r") as f:
        return json.load(f)


def normalize_yaml_content(content: str) -> str:
    """Normalize YAML content for comparison by parsing and re-dumping."""
    data = yaml.safe_load(content)
    return yaml.dump(data, sort_keys=True, default_flow_style=False)


@pytest.fixture
def yaml_normalizer():
    """Fixture providing YAML normalization function."""
    return normalize_yaml_content


@pytest.fixture
def json_normalizer():
    """Fixture providing JSON normalization function."""

    def normalize_json(content: str) -> str:
        """Normalize JSON content for comparison."""
        data = json.loads(content)
        return json.dumps(data, sort_keys=True, indent=2)

    return normalize_json


@pytest.fixture
def golden_framework(test_data_dir):
    """Provide golden test framework instance."""
    from golden.test_framework import GoldenTestFramework

    return GoldenTestFramework(test_data_dir)
