"""
SLO Gate CLI Tool - Validates metrics against SLO thresholds.

Fetches metrics from adapter and validates against SLO string.
Returns exit code 0 for pass, 1 for fail (deterministic behavior).
Logs in JSON format for machine parsing.
"""

import argparse
import json
import logging
import re
import sys
from datetime import datetime
from typing import Dict, List, Union

import requests


class JSONFormatter(logging.Formatter):
    """Custom formatter for JSON log output."""

    def format(self, record):
        log_data = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "message": record.getMessage(),
            "module": record.module,
            "function": record.funcName,
        }

        # Add extra fields
        for attr in ["slo_validation", "metrics", "violations", "duration_ms", "url"]:
            if hasattr(record, attr):
                log_data[attr] = getattr(record, attr)

        return json.dumps(log_data)


# Configure logger
logger = logging.getLogger(__name__)
handler = logging.StreamHandler()
handler.setFormatter(JSONFormatter())
logger.addHandler(handler)
logger.setLevel(logging.INFO)


class SLOValidationError(Exception):
    """Raised when SLO validation fails."""

    pass


class MetricsFetchError(Exception):
    """Raised when metrics cannot be fetched."""

    pass


def parse_slo_string(slo_string: str) -> List[Dict[str, Union[str, float]]]:
    """
    Parse SLO string into structured format.

    Args:
        slo_string: String like "latency_p95_ms<=15,success_rate>=0.995"

    Returns:
        List of dicts with metric, operator, threshold

    Raises:
        ValueError: If SLO format is invalid
    """
    if not slo_string or not slo_string.strip():
        raise ValueError("Invalid SLO format: empty string")

    slos = []

    # Split by comma and process each constraint
    for constraint in slo_string.split(","):
        constraint = constraint.strip()

        if not constraint:
            continue

        # Match pattern: metric_name operator threshold
        pattern = r"^(\w+)\s*(<=|>=|<|>|==)\s*([\d.]+)$"
        match = re.match(pattern, constraint)

        if not match:
            raise ValueError(f"Invalid SLO format: {constraint}")

        metric, operator, threshold_str = match.groups()

        # Validate operator
        if operator not in ["<=", ">=", "<", ">", "=="]:
            raise ValueError(f"Invalid SLO format: unsupported operator {operator}")

        try:
            threshold = float(threshold_str)
        except ValueError:
            raise ValueError(
                f"Invalid SLO format: threshold must be numeric in {constraint}"
            )

        slos.append({"metric": metric, "operator": operator, "threshold": threshold})

    if not slos:
        raise ValueError("Invalid SLO format: no valid constraints found")

    return slos


def validate_metrics_against_slos(
    metrics: Dict[str, float], slos: List[Dict[str, Union[str, float]]]
) -> bool:
    """
    Validate metrics against SLO thresholds.

    Args:
        metrics: Dict of metric name -> value
        slos: List of SLO constraints from parse_slo_string

    Returns:
        True if all SLOs pass

    Raises:
        SLOValidationError: If any SLO fails
        KeyError: If required metric is missing
    """
    violations = []

    for slo in slos:
        metric_name = slo["metric"]
        operator = slo["operator"]
        threshold = slo["threshold"]

        if metric_name not in metrics:
            raise KeyError(f"Required metric '{metric_name}' not found in metrics data")

        actual_value = metrics[metric_name]
        passed = False

        # Evaluate SLO constraint
        if operator == "<=":
            passed = actual_value <= threshold
        elif operator == ">=":
            passed = actual_value >= threshold
        elif operator == "<":
            passed = actual_value < threshold
        elif operator == ">":
            passed = actual_value > threshold
        elif operator == "==":
            passed = actual_value == threshold

        if not passed:
            violations.append(
                {
                    "metric": metric_name,
                    "operator": operator,
                    "threshold": threshold,
                    "actual": actual_value,
                }
            )

    if violations:
        violation_details = [
            f"{v['metric']} {v['operator']} {v['threshold']} (actual: {v['actual']})"
            for v in violations
        ]
        raise SLOValidationError(f"SLO violations: {', '.join(violation_details)}")

    return True


def fetch_metrics(url: str) -> Dict[str, float]:
    """
    Fetch metrics from adapter endpoint.

    Args:
        url: Metrics endpoint URL

    Returns:
        Dict of metric name -> value

    Raises:
        MetricsFetchError: If fetch fails
    """
    try:
        response = requests.get(url, timeout=30)
        response.raise_for_status()

        data = response.json()

        # Extract numeric metrics
        metrics = {}
        for key, value in data.items():
            if key in ["latency_p95_ms", "success_rate", "throughput_p95_mbps"]:
                if not isinstance(value, (int, float)):
                    raise MetricsFetchError(f"Metric {key} is not numeric: {value}")
                metrics[key] = float(value)

        logger.info(
            "Metrics fetched successfully",
            extra={"url": url, "metrics": metrics, "timestamp": data.get("timestamp")},
        )

        return metrics

    except requests.exceptions.RequestException as e:
        raise MetricsFetchError(f"Failed to fetch metrics from {url}: {str(e)}")
    except (json.JSONDecodeError, KeyError) as e:
        raise MetricsFetchError(f"Invalid JSON response from {url}: {str(e)}")


def create_parser() -> argparse.ArgumentParser:
    """Create command line argument parser."""
    parser = argparse.ArgumentParser(
        description="SLO Gate - Validate metrics against SLO thresholds",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --slo "latency_p95_ms<=15" --url http://localhost:8080/metrics
  %(prog)s --slo "latency_p95_ms<=15,success_rate>=0.995,throughput_p95_mbps>=200" --url http://adapter:8080/metrics

Exit Codes:
  0 - All SLOs pass
  1 - SLO violations or errors
        """,
    )

    parser.add_argument(
        "--slo",
        required=True,
        help='SLO string (e.g., "latency_p95_ms<=15,success_rate>=0.995")',
    )

    parser.add_argument("--url", required=True, help="Metrics endpoint URL")

    parser.add_argument(
        "--timeout",
        type=int,
        default=30,
        help="Request timeout in seconds (default: 30)",
    )

    parser.add_argument("--verbose", action="store_true", help="Enable verbose logging")

    return parser


def main() -> int:
    """
    Main CLI function.

    Returns:
        Exit code: 0 for success, 1 for failure
    """
    start_time = datetime.utcnow()

    parser = create_parser()
    args = parser.parse_args()

    if args.verbose:
        logger.setLevel(logging.DEBUG)

    logger.info(
        "SLO Gate starting",
        extra={
            "slo_string": args.slo,
            "metrics_url": args.url,
            "timeout": args.timeout,
        },
    )

    try:
        # Parse SLO string
        slos = parse_slo_string(args.slo)
        logger.debug("SLO constraints parsed", extra={"slos": slos})

        # Fetch metrics
        metrics = fetch_metrics(args.url)

        # Validate metrics against SLOs
        validate_metrics_against_slos(metrics, slos)

        # Success - all SLOs pass
        duration_ms = (datetime.utcnow() - start_time).total_seconds() * 1000
        logger.info(
            "SLO validation PASSED",
            extra={
                "slo_validation": "PASSED",
                "metrics": metrics,
                "slos": slos,
                "duration_ms": duration_ms,
            },
        )

        return 0

    except ValueError as e:
        logger.error(
            "SLO parsing error", extra={"error": str(e), "slo_string": args.slo}
        )
        return 1

    except MetricsFetchError as e:
        logger.error("Metrics fetch failed", extra={"error": str(e), "url": args.url})
        return 1

    except SLOValidationError as e:
        duration_ms = (datetime.utcnow() - start_time).total_seconds() * 1000
        logger.error(
            "SLO validation FAILED",
            extra={
                "slo_validation": "FAILED",
                "error": str(e),
                "duration_ms": duration_ms,
            },
        )
        return 1

    except KeyError as e:
        logger.error(
            "Missing required metric",
            extra={
                "error": str(e),
                "available_metrics": list(metrics.keys())
                if "metrics" in locals()
                else [],
            },
        )
        return 1

    except Exception as e:
        logger.error(
            "Unexpected error", extra={"error": str(e), "type": type(e).__name__}
        )
        return 1


if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)
