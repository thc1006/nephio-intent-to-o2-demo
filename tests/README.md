# Golden Test Suite for Intent Compilation Pipeline

This directory contains comprehensive golden tests for the intent-to-KRM compilation pipeline, ensuring consistent, correct, and deterministic output generation.

## Overview

The test suite consists of three main categories:

1. **Golden Tests** - Regression tests that compare generated output against known-good golden files
2. **Contract Tests** - API boundary and integration contract validation
3. **Framework Tests** - Tests for the golden test framework itself

## Directory Structure

```
tests/
├── conftest.py                 # Shared fixtures and pytest configuration
├── pytest.ini                 # Pytest settings
├── requirements.txt           # Test dependencies
├── run_golden_tests.py       # Test runner script
├── fixtures/                 # Test data and fixtures
│   ├── intents/             # Sample intent files
│   └── expected/            # Golden outputs
├── golden/                   # Golden regression tests
│   ├── test_framework.py    # Core framework tests
│   └── test_intent_scenarios.py # Scenario-specific tests
└── contract/                 # Contract tests
    ├── test_api_contracts.py # API boundary tests
    └── test_kpt_integration.py # kpt integration tests
```

## Test Scenarios

The test suite covers these key scenarios:

### Intent Variations
- **edge1-embb-with-sla**: Enhanced mobile broadband for edge1 with SLA
- **edge2-urllc-with-sla**: Ultra-reliable low-latency for edge2 with strict SLA
- **both-sites-mmt-with-sla**: Massive machine-type communication across both sites
- **edge1-embb-no-sla**: Basic service without SLA requirements
- **minimal-intent**: Minimal intent with default values

### Service Types
- Enhanced Mobile Broadband (eMBB)
- Ultra-Reliable Low-Latency Communications (URLLC)
- Massive Machine-Type Communications (mMTC)

### Deployment Targets
- Single site (edge1 or edge2)
- Multi-site (both edge1 and edge2)

## Running Tests

### Prerequisites

Install test dependencies:
```bash
pip install -r tests/requirements.txt
```

### Quick Start

Run all tests:
```bash
cd tests
python run_golden_tests.py
```

Run specific test types:
```bash
# Golden regression tests only
python run_golden_tests.py --type golden

# Contract tests only
python run_golden_tests.py --type contract

# Framework tests only
python run_golden_tests.py --type framework
```

### Advanced Usage

Generate new golden outputs:
```bash
python run_golden_tests.py --generate-golden
```

Update existing golden outputs:
```bash
python run_golden_tests.py --update-golden
```

Validate golden outputs against current implementation:
```bash
python run_golden_tests.py --validate-golden
```

Run with verbose output:
```bash
python run_golden_tests.py --verbose
```

Run specific scenarios:
```bash
python run_golden_tests.py --scenarios edge1-embb-with-sla edge2-urllc-with-sla
```

### Using pytest directly

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=translate --cov-report=html

# Run specific test file
pytest golden/test_intent_scenarios.py

# Run tests with specific marker
pytest -m golden

# Run in parallel
pytest -n auto
```

## Test Categories

### Golden Tests

Golden tests ensure that the intent compilation pipeline produces consistent output:

- **Deterministic Output**: Same input always produces same output
- **Checksum Consistency**: Generated checksums are accurate and reproducible
- **Resource Structure**: Generated KRM resources have correct structure
- **Multi-site Handling**: Both single and multi-site deployments work correctly

### Contract Tests

Contract tests validate API boundaries and integration points:

- **Intent Validation**: Proper validation of intent structure and fields
- **Resource Generation**: Correct generation of different resource types
- **SLA Conversion**: Proper mapping of SLA requirements to technical parameters
- **Error Handling**: Appropriate error responses for various failure modes
- **kpt Integration**: Compatibility with kpt fn render pipeline
- **Kubeconform Validation**: Generated resources pass Kubernetes schema validation

### Integration Tests

Integration tests verify end-to-end functionality:

- **File System Operations**: Proper handling of file I/O
- **Manifest Generation**: Correct manifest structure and content
- **Idempotency**: Multiple runs produce identical results
- **Performance**: Tests complete within reasonable time bounds

## Golden Test Framework

The golden test framework provides:

### Core Features
- **Test Data Management**: Organized fixtures for different scenarios
- **Output Comparison**: Intelligent comparison of generated vs expected outputs
- **Checksum Validation**: SHA256 integrity checking
- **Deterministic Testing**: Fixed timestamps for reproducible results

### Key Classes
- `GoldenTestFramework`: Main framework class
- `IntentToKRMTranslator`: The system under test
- Test fixtures and utilities in `conftest.py`

## Writing New Tests

### Adding Intent Scenarios

1. Create intent fixture in `fixtures/intents/`:
```json
{
  "intentId": "new-scenario-001",
  "serviceType": "enhanced-mobile-broadband",
  "targetSite": "edge1",
  "sla": {
    "availability": 99.9,
    "latency": 5
  }
}
```

2. Generate golden output:
```bash
python run_golden_tests.py --generate-golden --scenarios new-scenario-001
```

3. Add test case to `golden/test_intent_scenarios.py`:
```python
def test_new_scenario_golden(self):
    """Test new scenario description."""
    scenario = self.framework.generate_test_scenario(
        "new-scenario-001",
        fixed_timestamp=self.fixed_timestamp
    )
    # Add assertions for scenario-specific validation
```

### Adding Contract Tests

1. Add test method to appropriate contract test file
2. Use fixtures and mocks to isolate the component under test
3. Assert expected behavior and error conditions

### Test Best Practices

- Use descriptive test names that explain what is being tested
- Include both positive and negative test cases
- Use fixtures to set up test data consistently
- Mock external dependencies (filesystem, subprocess calls)
- Assert specific behavior, not just absence of errors
- Keep tests focused and independent

## CI/CD Integration

The test suite is designed for integration with CI/CD pipelines:

### GitHub Actions Example

```yaml
name: Golden Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-python@v4
        with:
          python-version: '3.9'
      - name: Install dependencies
        run: |
          pip install -r tests/requirements.txt
          pip install -r tools/intent-compiler/requirements.txt
      - name: Run golden tests
        run: |
          cd tests
          python run_golden_tests.py --verbose
      - name: Upload coverage
        uses: codecov/codecov-action@v3
```

### Test Reports

The test runner can generate JSON reports for CI integration:

```bash
python run_golden_tests.py --report-file test-report.json
```

## Maintenance

### Updating Golden Outputs

When the intent compiler implementation changes legitimately:

1. Review changes carefully to ensure they're intentional
2. Update golden outputs: `python run_golden_tests.py --update-golden`
3. Commit updated golden files with clear explanation

### Performance Monitoring

Monitor test execution time and add performance tests for critical paths:

```python
@pytest.mark.slow
def test_large_intent_performance(self):
    # Test performance with large/complex intents
    pass
```

### Coverage Goals

Maintain minimum 80% code coverage on the intent compiler:
- Run `pytest --cov=translate --cov-report=html`
- Review `htmlcov/index.html` for detailed coverage report

## Troubleshooting

### Common Issues

1. **Tests fail after compiler changes**
   - Check if changes are intentional
   - Update golden outputs if needed
   - Review test assertions

2. **Inconsistent test results**
   - Check for non-deterministic behavior
   - Ensure fixed timestamps are used
   - Review file system operations

3. **Slow test execution**
   - Use `pytest -n auto` for parallel execution
   - Profile slow tests with `pytest --durations=10`
   - Consider mocking expensive operations

4. **Missing test dependencies**
   - Install: `pip install -r tests/requirements.txt`
   - Check Python version compatibility

### Debug Mode

Run tests with maximum verbosity and debug output:

```bash
pytest -vvs --tb=long --log-cli-level=DEBUG
```

## Contributing

When contributing to the test suite:

1. Follow existing patterns and conventions
2. Add tests for new functionality
3. Ensure tests are deterministic and reliable
4. Update documentation for significant changes
5. Run full test suite before submitting changes