#!/usr/bin/env python3
"""
O2IMS Postcheck Parser
Fetches metrics from O2IMS MeasurementJob and validates SLO compliance
"""

import json
import sys
import argparse
import subprocess
import requests
from datetime import datetime


class O2IMSPostcheck:
    def __init__(self, namespace="o2ims-system"):
        self.namespace = namespace
        self.measurementjob_name = "slo-metrics-scraper"

    def get_measurementjob_status(self):
        """Get MeasurementJob status from Kubernetes"""
        try:
            cmd = [
                "kubectl", "get", "measurementjob",
                self.measurementjob_name,
                "-n", self.namespace,
                "-o", "json"
            ]
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode != 0:
                print(f"Error getting MeasurementJob: {result.stderr}")
                return None

            return json.loads(result.stdout)
        except Exception as e:
            print(f"Failed to get MeasurementJob: {e}")
            return None

    def get_direct_metrics(self):
        """Get metrics directly from SLO endpoint"""
        try:
            response = requests.get("http://127.0.0.1:30090/metrics/api/v1/slo", timeout=5)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"Failed to get direct metrics: {e}")
            return None

    def parse_metrics(self, prefer_o2ims=True):
        """Parse metrics, preferring O2IMS values if available"""
        metrics = {}

        # Try to get O2IMS MeasurementJob status first
        if prefer_o2ims:
            mj_status = self.get_measurementjob_status()
            if mj_status and 'status' in mj_status:
                status = mj_status['status']
                metrics['source'] = 'o2ims'
                metrics['phase'] = status.get('phase', 'Unknown')
                metrics['last_scrape'] = status.get('lastScrapeTime', '')
                metrics['metrics_count'] = status.get('metricsCount', 0)
                metrics['message'] = status.get('message', '')

                # If we have successful O2IMS data, use it
                if metrics['phase'] == 'Ready':
                    print(f"✓ Using O2IMS values (MeasurementJob: {metrics['phase']})")
                else:
                    print(f"⚠ O2IMS MeasurementJob not ready: {metrics['phase']}")

        # If O2IMS is not available or not preferred, get direct metrics
        if not metrics or metrics.get('phase') != 'Ready':
            direct_metrics = self.get_direct_metrics()
            if direct_metrics:
                metrics['source'] = 'direct'
                metrics['data'] = direct_metrics
                print("✓ Using direct SLO endpoint values")

        return metrics

    def validate_slo(self, metrics):
        """Validate SLO compliance"""
        results = {
            'passed': [],
            'failed': [],
            'warnings': []
        }

        if not metrics:
            results['failed'].append("No metrics available")
            return results

        # Extract actual metrics data
        if 'data' in metrics:
            data = metrics['data']
        else:
            # Try to parse from MeasurementJob
            data = metrics

        # Define SLO thresholds
        slo_thresholds = {
            'success_rate': 99.0,  # Minimum success rate
            'p95_latency_ms': 100.0,  # Maximum P95 latency
            'p99_latency_ms': 200.0,  # Maximum P99 latency
        }

        # Validate metrics against SLOs
        if 'metrics' in data:
            m = data['metrics']

            # Check success rate
            if 'success_rate' in m:
                if m['success_rate'] >= slo_thresholds['success_rate']:
                    results['passed'].append(f"Success rate: {m['success_rate']}% >= {slo_thresholds['success_rate']}%")
                else:
                    results['failed'].append(f"Success rate: {m['success_rate']}% < {slo_thresholds['success_rate']}%")

            # Check P95 latency
            if 'latency_p95_ms' in m:
                if m['latency_p95_ms'] <= slo_thresholds['p95_latency_ms']:
                    results['passed'].append(f"P95 latency: {m['latency_p95_ms']}ms <= {slo_thresholds['p95_latency_ms']}ms")
                else:
                    results['failed'].append(f"P95 latency: {m['latency_p95_ms']}ms > {slo_thresholds['p95_latency_ms']}ms")

            # Check P99 latency
            if 'latency_p99_ms' in m:
                if m['latency_p99_ms'] <= slo_thresholds['p99_latency_ms']:
                    results['passed'].append(f"P99 latency: {m['latency_p99_ms']}ms <= {slo_thresholds['p99_latency_ms']}ms")
                else:
                    results['failed'].append(f"P99 latency: {m['latency_p99_ms']}ms > {slo_thresholds['p99_latency_ms']}ms")

            # Check if metrics are fresh
            if 'timestamp' in data:
                try:
                    ts = datetime.fromisoformat(data['timestamp'].replace('Z', '+00:00'))
                    age = (datetime.now(ts.tzinfo) - ts).total_seconds()
                    if age > 60:
                        results['warnings'].append(f"Metrics are {age:.0f}s old")
                except:
                    pass

        return results

    def run_postcheck(self, prefer_o2ims=True):
        """Run complete postcheck"""
        print("=" * 60)
        print("O2IMS SLO Postcheck")
        print("=" * 60)

        # Get metrics
        metrics = self.parse_metrics(prefer_o2ims)

        if metrics:
            print(f"\nMetrics Source: {metrics.get('source', 'unknown')}")
            if 'data' in metrics:
                print(f"Timestamp: {metrics['data'].get('timestamp', 'N/A')}")
                print(f"Service: {metrics['data'].get('service', 'N/A')}")

        # Validate SLOs
        print("\nSLO Validation:")
        print("-" * 40)
        validation = self.validate_slo(metrics)

        # Print results
        if validation['passed']:
            print("\n✅ Passed:")
            for item in validation['passed']:
                print(f"  - {item}")

        if validation['warnings']:
            print("\n⚠️  Warnings:")
            for item in validation['warnings']:
                print(f"  - {item}")

        if validation['failed']:
            print("\n❌ Failed:")
            for item in validation['failed']:
                print(f"  - {item}")

        # Overall result
        print("\n" + "=" * 60)
        if not validation['failed']:
            print("✅ All SLOs PASSED")
            return 0
        else:
            print(f"❌ {len(validation['failed'])} SLO(s) FAILED")
            return 1


def main():
    parser = argparse.ArgumentParser(description='O2IMS SLO Postcheck Parser')
    parser.add_argument('--prefer-direct', action='store_true',
                        help='Prefer direct endpoint over O2IMS values')
    parser.add_argument('--namespace', default='o2ims-system',
                        help='O2IMS namespace (default: o2ims-system)')
    parser.add_argument('--json', action='store_true',
                        help='Output results as JSON')

    args = parser.parse_args()

    checker = O2IMSPostcheck(namespace=args.namespace)

    if args.json:
        metrics = checker.parse_metrics(not args.prefer_direct)
        validation = checker.validate_slo(metrics)
        result = {
            'metrics': metrics,
            'validation': validation,
            'success': len(validation['failed']) == 0
        }
        print(json.dumps(result, indent=2))
        return 0 if result['success'] else 1
    else:
        return checker.run_postcheck(not args.prefer_direct)


if __name__ == "__main__":
    sys.exit(main())