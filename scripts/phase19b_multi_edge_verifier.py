#!/usr/bin/env python3
"""
Phase 19-B (VM-4) Multi-Edge Verification System
Verifies PR readiness and resource deployment across multiple edge sites
"""

import json
import subprocess
import sys
import time
import argparse
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from concurrent.futures import ThreadPoolExecutor, as_completed


class EdgeVerifier:
    """Verifies edge site deployments and PR readiness"""

    def __init__(self, project_root: Path, timeout: int = 300):
        self.project_root = project_root
        self.timeout = timeout
        self.artifacts_dir = project_root / "artifacts"
        self.artifacts_dir.mkdir(parents=True, exist_ok=True)
        self.timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    def run_command(self, cmd: List[str], check: bool = False) -> Tuple[int, str, str]:
        """Execute a shell command and return output"""
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=check,
                timeout=30
            )
            return result.returncode, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return 1, "", "Command timed out"
        except subprocess.CalledProcessError as e:
            return e.returncode, e.stdout, e.stderr
        except Exception as e:
            return 1, "", str(e)

    def check_pr_status(self, edge_site: str, namespace: str = "default") -> Dict:
        """Check ProvisioningRequest status for an edge site"""
        results = {
            "edge": edge_site,
            "namespace": namespace,
            "provisioningRequests": [],
            "ready": False
        }

        # Try o2imsctl first
        cmd = ["o2imsctl", "pr", "list", "-n", namespace, "-o", "json"]
        returncode, stdout, stderr = self.run_command(cmd)

        if returncode == 0 and stdout:
            try:
                pr_data = json.loads(stdout)
                for item in pr_data.get("items", []):
                    pr_name = item.get("metadata", {}).get("name", "")
                    pr_status = item.get("status", {}).get("phase", "Unknown")

                    # Check if PR is for this edge site
                    if edge_site in pr_name or item.get("spec", {}).get("targetCluster") == edge_site:
                        results["provisioningRequests"].append({
                            "name": pr_name,
                            "status": pr_status,
                            "ready": pr_status in ["Ready", "Published"]
                        })
            except json.JSONDecodeError:
                pass

        # Fallback to kubectl with different CRD types
        if not results["provisioningRequests"]:
            for crd_type in ["provisioningrequests", "packagerevisions"]:
                cmd = ["kubectl", "get", crd_type, "-n", namespace, "-o", "json"]
                returncode, stdout, stderr = self.run_command(cmd)

                if returncode == 0 and stdout:
                    try:
                        data = json.loads(stdout)
                        for item in data.get("items", []):
                            pr_name = item.get("metadata", {}).get("name", "")

                            # Check if PR is for this edge site
                            if edge_site in pr_name:
                                # Check status or conditions
                                pr_status = item.get("status", {}).get("phase", "")
                                if not pr_status:
                                    conditions = item.get("status", {}).get("conditions", [])
                                    for cond in conditions:
                                        if cond.get("type") == "Ready":
                                            pr_status = "Ready" if cond.get("status") == "True" else "NotReady"
                                            break

                                results["provisioningRequests"].append({
                                    "name": pr_name,
                                    "status": pr_status or "Unknown",
                                    "ready": pr_status in ["Ready", "Published", "True"]
                                })
                    except json.JSONDecodeError:
                        pass

                if results["provisioningRequests"]:
                    break

        # Check if any PR is ready
        results["ready"] = any(pr["ready"] for pr in results["provisioningRequests"])
        results["total"] = len(results["provisioningRequests"])
        results["readyCount"] = sum(1 for pr in results["provisioningRequests"] if pr["ready"])

        return results

    def check_edge_resources(self, edge_site: str, namespace: str = "default") -> Dict:
        """Check deployed resources for an edge site"""
        resources = {
            "networkSlices": 0,
            "configMaps": 0,
            "services": 0,
            "deployments": 0,
            "serviceEndpoints": []
        }

        # Check NetworkSlices
        cmd = ["kubectl", "get", "networkslices", "-n", namespace, "-o", "json"]
        returncode, stdout, _ = self.run_command(cmd)
        if returncode == 0 and stdout:
            try:
                data = json.loads(stdout)
                for item in data.get("items", []):
                    if edge_site in item.get("metadata", {}).get("name", ""):
                        resources["networkSlices"] += 1
            except json.JSONDecodeError:
                pass

        # Check ConfigMaps
        cmd = ["kubectl", "get", "configmaps", "-n", namespace,
               "-l", f"edge={edge_site}", "-o", "json"]
        returncode, stdout, _ = self.run_command(cmd)
        if returncode == 0 and stdout:
            try:
                data = json.loads(stdout)
                resources["configMaps"] = len(data.get("items", []))
            except json.JSONDecodeError:
                pass

        # Check Services
        cmd = ["kubectl", "get", "services", "-n", namespace,
               "-l", f"edge={edge_site}", "-o", "json"]
        returncode, stdout, _ = self.run_command(cmd)
        if returncode == 0 and stdout:
            try:
                data = json.loads(stdout)
                resources["services"] = len(data.get("items", []))

                # Check service endpoints
                for svc in data.get("items", []):
                    svc_name = svc.get("metadata", {}).get("name", "")
                    endpoint = self.probe_service_endpoint(svc_name, namespace)
                    resources["serviceEndpoints"].append({
                        "name": svc_name,
                        "status": endpoint
                    })
            except json.JSONDecodeError:
                pass

        # Check Deployments
        cmd = ["kubectl", "get", "deployments", "-n", namespace,
               "-l", f"edge={edge_site}", "-o", "json"]
        returncode, stdout, _ = self.run_command(cmd)
        if returncode == 0 and stdout:
            try:
                data = json.loads(stdout)
                resources["deployments"] = len(data.get("items", []))
            except json.JSONDecodeError:
                pass

        # Determine overall resource status
        resources["status"] = "healthy" if (
            resources["networkSlices"] > 0 or
            resources["configMaps"] > 0 or
            resources["services"] > 0
        ) else "pending"

        return resources

    def probe_service_endpoint(self, service_name: str, namespace: str) -> str:
        """Probe a service endpoint for availability"""
        # Get service endpoint
        cmd = ["kubectl", "get", "service", service_name, "-n", namespace,
               "-o", "jsonpath={.status.loadBalancer.ingress[0].ip}"]
        returncode, stdout, _ = self.run_command(cmd)

        if returncode != 0 or not stdout.strip():
            # Try ClusterIP
            cmd = ["kubectl", "get", "service", service_name, "-n", namespace,
                   "-o", "jsonpath={.spec.clusterIP}"]
            returncode, stdout, _ = self.run_command(cmd)

        if returncode == 0 and stdout.strip():
            endpoint = stdout.strip()
            # Test connectivity (simplified - you might want to use curl or requests)
            cmd = ["timeout", "5", "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
                   f"http://{endpoint}:80"]
            returncode, stdout, _ = self.run_command(cmd)

            if returncode == 0:
                return "healthy"
            else:
                return "unreachable"

        return "not_found"

    def verify_edge_site(self, edge_site: str, namespace: str = "default") -> Dict:
        """Complete verification for a single edge site"""
        print(f"[{datetime.now().strftime('%H:%M:%S')}] Verifying edge site: {edge_site}")

        verification = {
            "timestamp": self.timestamp,
            "edge": edge_site,
            "namespace": namespace,
            "provisioningRequests": {},
            "resources": {},
            "status": "pending"
        }

        # Check PR status
        pr_status = self.check_pr_status(edge_site, namespace)
        verification["provisioningRequests"] = pr_status

        # Check resources
        resources = self.check_edge_resources(edge_site, namespace)
        verification["resources"] = resources

        # Determine overall status
        if pr_status["ready"] and resources["status"] == "healthy":
            verification["status"] = "success"
            print(f"  ✓ Edge {edge_site}: PR ready, resources healthy")
        elif pr_status["ready"]:
            verification["status"] = "partial"
            print(f"  ⚠ Edge {edge_site}: PR ready, resources pending")
        else:
            verification["status"] = "pending"
            print(f"  ⏳ Edge {edge_site}: PR not ready")

        return verification

    def verify_multiple_edges(self, edge_sites: List[str], namespace: str = "default",
                             parallel: bool = True) -> Dict:
        """Verify multiple edge sites"""
        results = {
            "timestamp": self.timestamp,
            "edges": {},
            "summary": {
                "total": len(edge_sites),
                "successful": 0,
                "partial": 0,
                "pending": 0,
                "failed": 0
            }
        }

        if parallel:
            # Parallel verification
            with ThreadPoolExecutor(max_workers=min(4, len(edge_sites))) as executor:
                futures = {
                    executor.submit(self.verify_edge_site, edge, namespace): edge
                    for edge in edge_sites
                }

                for future in as_completed(futures):
                    edge = futures[future]
                    try:
                        result = future.result(timeout=60)
                        results["edges"][edge] = result
                        results["summary"][result["status"]] = results["summary"].get(result["status"], 0) + 1
                    except Exception as e:
                        print(f"  ✗ Edge {edge}: Verification failed - {e}")
                        results["edges"][edge] = {
                            "error": str(e),
                            "status": "failed"
                        }
                        results["summary"]["failed"] += 1
        else:
            # Sequential verification
            for edge in edge_sites:
                try:
                    result = self.verify_edge_site(edge, namespace)
                    results["edges"][edge] = result
                    results["summary"][result["status"]] = results["summary"].get(result["status"], 0) + 1
                except Exception as e:
                    print(f"  ✗ Edge {edge}: Verification failed - {e}")
                    results["edges"][edge] = {
                        "error": str(e),
                        "status": "failed"
                    }
                    results["summary"]["failed"] += 1

        # Determine overall result
        if results["summary"]["successful"] == len(edge_sites):
            results["overallStatus"] = "SUCCESS"
        elif results["summary"]["successful"] > 0 or results["summary"]["partial"] > 0:
            results["overallStatus"] = "PARTIAL"
        else:
            results["overallStatus"] = "FAILED"

        return results

    def wait_for_ready(self, edge_sites: List[str], namespace: str = "default") -> bool:
        """Wait for all edge sites to be ready"""
        start_time = time.time()

        print(f"\n{'='*60}")
        print(f"Waiting for {len(edge_sites)} edge site(s) to be ready...")
        print(f"Timeout: {self.timeout} seconds")
        print(f"{'='*60}\n")

        while time.time() - start_time < self.timeout:
            results = self.verify_multiple_edges(edge_sites, namespace)

            if results["overallStatus"] == "SUCCESS":
                print(f"\n✓ All edge sites are ready!")
                return True

            # Show progress
            elapsed = int(time.time() - start_time)
            remaining = self.timeout - elapsed
            print(f"\r⏳ Progress: {results['summary']} | Elapsed: {elapsed}s | Remaining: {remaining}s", end="")

            time.sleep(10)

        print(f"\n✗ Timeout reached after {self.timeout} seconds")
        return False

    def save_results(self, results: Dict, edge_site: Optional[str] = None):
        """Save verification results to artifacts"""
        if edge_site:
            output_dir = self.artifacts_dir / edge_site
        else:
            output_dir = self.artifacts_dir / "multi-edge"

        output_dir.mkdir(parents=True, exist_ok=True)

        # Save timestamped file
        output_file = output_dir / f"ready_{self.timestamp}.json"
        with open(output_file, "w") as f:
            json.dump(results, f, indent=2)

        # Create symlink to latest
        latest_link = output_dir / "ready.json"
        if latest_link.exists():
            latest_link.unlink()
        latest_link.symlink_to(output_file.name)

        print(f"\n📁 Results saved to: {output_file}")
        print(f"📁 Latest symlink: {latest_link}")


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Phase 19-B Multi-Edge Verification System"
    )
    parser.add_argument(
        "--edges",
        nargs="+",
        default=["edge1", "edge2"],
        help="Edge sites to verify"
    )
    parser.add_argument(
        "--namespace",
        default="default",
        help="Kubernetes namespace"
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=300,
        help="Timeout in seconds"
    )
    parser.add_argument(
        "--wait",
        action="store_true",
        help="Wait for all edges to be ready"
    )
    parser.add_argument(
        "--output",
        choices=["json", "summary"],
        default="summary",
        help="Output format"
    )

    args = parser.parse_args()

    # Initialize verifier
    project_root = Path(__file__).parent.parent
    verifier = EdgeVerifier(project_root, timeout=args.timeout)

    # Run verification
    if args.wait:
        success = verifier.wait_for_ready(args.edges, args.namespace)
        if not success:
            sys.exit(1)

    # Final verification
    results = verifier.verify_multiple_edges(args.edges, args.namespace)

    # Save results
    verifier.save_results(results)

    # Output results
    if args.output == "json":
        print(json.dumps(results, indent=2))
    else:
        print("\n" + "="*60)
        print("VERIFICATION SUMMARY")
        print("="*60)
        print(f"Timestamp: {results['timestamp']}")
        print(f"Edges verified: {', '.join(args.edges)}")
        print(f"\nResults:")
        for edge, data in results["edges"].items():
            status_icon = {
                "success": "✓",
                "partial": "⚠",
                "pending": "⏳",
                "failed": "✗"
            }.get(data.get("status", "unknown"), "?")

            print(f"\n  {status_icon} {edge}:")
            if "error" not in data:
                pr_info = data.get("provisioningRequests", {})
                res_info = data.get("resources", {})
                print(f"    PRs: {pr_info.get('readyCount', 0)}/{pr_info.get('total', 0)} ready")
                print(f"    Resources: {res_info.get('status', 'unknown')}")
                print(f"    Services: {res_info.get('services', 0)}")
                print(f"    NetworkSlices: {res_info.get('networkSlices', 0)}")
            else:
                print(f"    Error: {data['error']}")

        print(f"\n{'='*60}")
        print(f"Overall Status: {results['overallStatus']}")
        print(f"Summary: {results['summary']}")

    # Exit with appropriate code
    sys.exit(0 if results["overallStatus"] == "SUCCESS" else 1)


if __name__ == "__main__":
    main()