#!/usr/bin/env python3
"""TMF921 Intent to KRM Translator.

Translates TMF921 service intents to O2IMS ProvisioningRequests with site-specific overlays.
Integrates with kpt fn render pipeline for idempotent resource generation.
"""

import json
import yaml
import argparse
import os
import sys
from pathlib import Path
from typing import Dict, Any, List
from datetime import datetime

class IntentToKRMTranslator:
    """Translates TMF921 intents to KRM resources."""

    SERVICE_TYPE_MAPPING = {
        "enhanced-mobile-broadband": {
            "cpu": "8",
            "memory": "16Gi",
            "storage": "100Gi",
            "networkProfile": "embb",
            "sliceType": "eMBB"
        },
        "massive-machine-type": {
            "cpu": "4",
            "memory": "8Gi",
            "storage": "50Gi",
            "networkProfile": "mmtc",
            "sliceType": "mMTC"
        },
        "ultra-reliable-low-latency": {
            "cpu": "16",
            "memory": "32Gi",
            "storage": "200Gi",
            "networkProfile": "urllc",
            "sliceType": "URLLC"
        }
    }

    SITE_CONFIG = {
        "edge1": {
            "cluster": "edge-cluster-01",
            "namespace": "edge1",
            "plmnId": "00101",
            "gnbIdBase": "00001",
            "tac": "0001"
        },
        "edge2": {
            "cluster": "edge-cluster-02",
            "namespace": "edge2",
            "plmnId": "00102",
            "gnbIdBase": "00002",
            "tac": "0002"
        }
    }

    def __init__(self, output_dir: str = "rendered/krm"):
        self.output_dir = Path(output_dir)

    def translate(self, intent_file: str) -> Dict[str, List[Dict[str, Any]]]:
        """Translate intent JSON to KRM resources."""
        with open(intent_file, 'r') as f:
            intent = json.load(f)

        results = {}
        target_sites = self._get_target_sites(intent)

        for site in target_sites:
            krm_resources = self._generate_krm_for_site(intent, site)
            results[site] = krm_resources

        return results

    def _get_target_sites(self, intent: Dict[str, Any]) -> List[str]:
        """Determine target sites from intent."""
        target = intent.get("targetSite", "both")
        if target == "both":
            return ["edge1", "edge2"]
        return [target]

    def _generate_krm_for_site(self, intent: Dict[str, Any], site: str) -> List[Dict[str, Any]]:
        """Generate KRM resources for a specific site."""
        resources = []

        # Generate ProvisioningRequest
        pr = self._create_provisioning_request(intent, site)
        resources.append(pr)

        # Generate ConfigMap with intent metadata
        cm = self._create_intent_configmap(intent, site)
        resources.append(cm)

        # Generate NetworkSlice if SLA specified
        if "sla" in intent:
            ns = self._create_network_slice(intent, site)
            resources.append(ns)

        # Generate Kustomization for overlays
        kustomization = self._create_kustomization(intent, site)
        resources.append(kustomization)

        return resources

    def _create_provisioning_request(self, intent: Dict[str, Any], site: str) -> Dict[str, Any]:
        """Create O2IMS ProvisioningRequest."""
        service_type = intent.get("serviceType", "enhanced-mobile-broadband")
        service_config = self.SERVICE_TYPE_MAPPING.get(service_type, self.SERVICE_TYPE_MAPPING["enhanced-mobile-broadband"])
        site_config = self.SITE_CONFIG[site]

        pr = {
            "apiVersion": "o2ims.provisioning.oran.org/v1alpha1",
            "kind": "ProvisioningRequest",
            "metadata": {
                "name": f"{intent.get('intentId', 'unknown')}-{site}",
                "namespace": site_config["namespace"],
                "labels": {
                    "intent-id": intent.get("intentId", "unknown"),
                    "service-type": service_type,
                    "target-site": site
                },
                "annotations": {
                    "generated-by": "intent-compiler",
                    "timestamp": datetime.utcnow().isoformat() + "Z",
                    "resource-profile": intent.get("resourceProfile", "standard")
                }
            },
            "spec": {
                "description": f"Provisioning request for {service_type} service at {site}",
                "targetCluster": site_config["cluster"],
                "networkConfig": {
                    "plmnId": site_config["plmnId"],
                    "gnbId": site_config["gnbIdBase"],
                    "tac": site_config["tac"],
                    "sliceType": service_config["sliceType"]
                },
                "resourceRequirements": {
                    "cpu": service_config["cpu"],
                    "memory": service_config["memory"],
                    "storage": service_config["storage"]
                }
            }
        }

        # Add SLA parameters if present
        if "sla" in intent:
            pr["spec"]["slaRequirements"] = self._convert_sla(intent["sla"])

        return pr

    def _create_intent_configmap(self, intent: Dict[str, Any], site: str) -> Dict[str, Any]:
        """Create ConfigMap with intent metadata."""
        site_config = self.SITE_CONFIG[site]

        return {
            "apiVersion": "v1",
            "kind": "ConfigMap",
            "metadata": {
                "name": f"intent-{intent.get('intentId', 'unknown')}-{site}",
                "namespace": site_config["namespace"],
                "labels": {
                    "intent-id": intent.get("intentId", "unknown"),
                    "target-site": site
                }
            },
            "data": {
                "intent.json": json.dumps(intent, indent=2),
                "site": site,
                "serviceType": intent.get("serviceType", "unknown")
            }
        }

    def _create_network_slice(self, intent: Dict[str, Any], site: str) -> Dict[str, Any]:
        """Create NetworkSlice resource."""
        site_config = self.SITE_CONFIG[site]
        service_type = intent.get("serviceType", "enhanced-mobile-broadband")

        ns = {
            "apiVersion": "workload.nephio.org/v1alpha1",
            "kind": "NetworkSlice",
            "metadata": {
                "name": f"slice-{intent.get('intentId', 'unknown')}-{site}",
                "namespace": site_config["namespace"],
                "labels": {
                    "intent-id": intent.get("intentId", "unknown"),
                    "service-type": service_type,
                    "target-site": site
                }
            },
            "spec": {
                "sliceType": self.SERVICE_TYPE_MAPPING[service_type]["sliceType"],
                "plmn": {
                    "mcc": site_config["plmnId"][:3],
                    "mnc": site_config["plmnId"][3:]
                }
            }
        }

        # Add SLA-based QoS parameters
        if "sla" in intent:
            ns["spec"]["qos"] = self._convert_sla_to_qos(intent["sla"])

        return ns

    def _create_kustomization(self, intent: Dict[str, Any], site: str) -> Dict[str, Any]:
        """Create Kustomization for site-specific overlays."""
        return {
            "apiVersion": "kustomize.config.k8s.io/v1beta1",
            "kind": "Kustomization",
            "metadata": {
                "name": f"kustomization-{site}",
                "annotations": {
                    "config.kubernetes.io/local-config": "true"
                }
            },
            "resources": [
                f"{intent.get('intentId', 'unknown')}-{site}-provisioning-request.yaml",
                f"intent-{intent.get('intentId', 'unknown')}-{site}-configmap.yaml",
                f"slice-{intent.get('intentId', 'unknown')}-{site}-networkslice.yaml"
            ],
            "namespace": self.SITE_CONFIG[site]["namespace"],
            "commonLabels": {
                "target-site": site,
                "intent-id": intent.get("intentId", "unknown")
            }
        }

    def _convert_sla(self, sla: Dict[str, Any]) -> Dict[str, Any]:
        """Convert SLA requirements to O2IMS format."""
        result = {}

        if "availability" in sla:
            result["availability"] = f"{sla['availability']}%"
        if "latency" in sla:
            result["maxLatency"] = f"{sla['latency']}ms"
        if "throughput" in sla:
            result["minThroughput"] = f"{sla['throughput']}Mbps"
        if "connections" in sla:
            result["maxConnections"] = str(sla["connections"])

        return result

    def _convert_sla_to_qos(self, sla: Dict[str, Any]) -> Dict[str, Any]:
        """Convert SLA to QoS parameters."""
        qos = {"5qi": 9}  # Default 5QI value

        if "latency" in sla:
            latency = sla["latency"]
            if latency <= 1:
                qos["5qi"] = 1  # URLLC
            elif latency <= 10:
                qos["5qi"] = 5  # Low latency
            elif latency <= 50:
                qos["5qi"] = 7  # Voice
            else:
                qos["5qi"] = 9  # Best effort

        if "throughput" in sla:
            qos["gfbr"] = f"{sla['throughput']}Mbps"

        return qos

    def save_resources(self, results: Dict[str, List[Dict[str, Any]]]) -> None:
        """Save KRM resources to files."""
        for site, resources in results.items():
            site_dir = self.output_dir / site
            site_dir.mkdir(parents=True, exist_ok=True)

            for resource in resources:
                filename = self._get_resource_filename(resource)
                filepath = site_dir / filename

                with open(filepath, 'w') as f:
                    yaml.dump(resource, f, default_flow_style=False, sort_keys=False)

                print(f"Generated: {filepath}")

    def _get_resource_filename(self, resource: Dict[str, Any]) -> str:
        """Generate filename for resource."""
        kind = resource.get("kind", "unknown").lower()
        name = resource.get("metadata", {}).get("name", "unknown")

        # Map kinds to filename patterns
        filename_map = {
            "provisioningrequest": f"{name}-provisioning-request.yaml",
            "configmap": f"{name}-configmap.yaml",
            "networkslice": f"{name}-networkslice.yaml",
            "kustomization": "kustomization.yaml"
        }

        return filename_map.get(kind, f"{name}-{kind}.yaml")


def main():
    parser = argparse.ArgumentParser(description="Translate TMF921 intents to KRM resources")
    parser.add_argument("intent_file", help="Path to intent JSON file")
    parser.add_argument("-o", "--output", default="rendered/krm",
                       help="Output directory for KRM resources (default: rendered/krm)")
    parser.add_argument("--dry-run", action="store_true",
                       help="Print resources without saving to files")

    args = parser.parse_args()

    if not os.path.exists(args.intent_file):
        print(f"Error: Intent file not found: {args.intent_file}", file=sys.stderr)
        sys.exit(1)

    translator = IntentToKRMTranslator(args.output)

    try:
        results = translator.translate(args.intent_file)

        if args.dry_run:
            for site, resources in results.items():
                print(f"\n=== Resources for site: {site} ===")
                for resource in resources:
                    print(yaml.dump(resource, default_flow_style=False, sort_keys=False))
                    print("---")
        else:
            translator.save_resources(results)
            print(f"\nSuccessfully generated KRM resources in {args.output}")

    except Exception as e:
        print(f"Error translating intent: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()