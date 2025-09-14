#!/usr/bin/env python3
"""TMF921 Intent to KRM Translator.

Translates TMF921 service intents to O2IMS ProvisioningRequests with site-specific overlays.
Integrates with kpt fn render pipeline for idempotent resource generation.

Features:
- Deterministic rendering with sorted keys and reproducible output
- SHA256 checksums for idempotency and integrity verification
- Comprehensive error handling and validation
- Manifest generation with metadata
- Production-ready logging
"""

import hashlib
import json
import logging
import os
import sys
import yaml
from argparse import ArgumentParser
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple


class IntentTranslationError(Exception):
    """Base exception for intent translation errors."""
    pass


class IntentValidationError(IntentTranslationError):
    """Exception raised for invalid intent data."""
    pass


class ResourceGenerationError(IntentTranslationError):
    """Exception raised during resource generation."""
    pass


class FileSystemError(IntentTranslationError):
    """Exception raised for filesystem operations."""
    pass


class IntentToKRMTranslator:
    """Translates TMF921 intents to KRM resources with deterministic output.

    Provides idempotent translation with checksums, comprehensive validation,
    and manifest generation for GitOps workflows.
    """

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

    def __init__(self, output_dir: str = "rendered/krm", enable_caching: bool = True):
        """Initialize the translator.

        Args:
            output_dir: Directory for generated KRM resources
            enable_caching: Enable idempotency checks with file caching
        """
        self.output_dir = Path(output_dir)
        self.enable_caching = enable_caching
        self.logger = self._setup_logging()
        self._manifest_data = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "generated_files": {},
            "resource_counts": {},
            "target_sites": [],
            "intent_id": None,
            "checksum_algorithm": "sha256"
        }

    def _setup_logging(self) -> logging.Logger:
        """Setup structured logging."""
        logger = logging.getLogger("intent-translator")
        if not logger.handlers:
            handler = logging.StreamHandler()
            formatter = logging.Formatter(
                '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            )
            handler.setFormatter(formatter)
            logger.addHandler(handler)
            logger.setLevel(logging.INFO)
        return logger

    def translate(self, intent_file: str) -> Dict[str, List[Dict[str, Any]]]:
        """Translate intent JSON to KRM resources with validation and error handling.

        Args:
            intent_file: Path to the intent JSON file

        Returns:
            Dictionary mapping site names to lists of KRM resources

        Raises:
            IntentValidationError: If intent data is invalid
            FileSystemError: If file operations fail
            ResourceGenerationError: If resource generation fails
        """
        self.logger.info(f"Starting intent translation from {intent_file}")

        try:
            intent = self._load_and_validate_intent(intent_file)
        except IntentValidationError:
            raise  # Re-raise validation errors as-is
        except (IOError, OSError) as e:
            raise FileSystemError(f"Failed to read intent file {intent_file}: {e}")
        except (json.JSONDecodeError, ValueError) as e:
            raise IntentValidationError(f"Invalid JSON in intent file: {e}")

        self._manifest_data["intent_id"] = intent.get("intentId", "unknown")
        target_sites = self._get_target_sites(intent)
        self._manifest_data["target_sites"] = sorted(target_sites)

        results = {}
        total_resources = 0

        try:
            for site in sorted(target_sites):  # Deterministic ordering
                self.logger.info(f"Generating KRM resources for site: {site}")
                krm_resources = self._generate_krm_for_site(intent, site)
                results[site] = krm_resources
                total_resources += len(krm_resources)
                self._manifest_data["resource_counts"][site] = len(krm_resources)

        except Exception as e:
            raise ResourceGenerationError(f"Failed to generate resources: {e}")

        self.logger.info(f"Successfully generated {total_resources} resources for {len(target_sites)} sites")
        return results

    def _load_and_validate_intent(self, intent_file: str) -> Dict[str, Any]:
        """Load and validate intent JSON.

        Args:
            intent_file: Path to intent file

        Returns:
            Validated intent dictionary

        Raises:
            IntentValidationError: If validation fails
        """
        with open(intent_file, 'r', encoding='utf-8') as f:
            intent = json.load(f)

        # Basic validation
        if not isinstance(intent, dict):
            raise IntentValidationError("Intent must be a JSON object")

        # Validate required fields
        required_fields = ["intentId"]
        missing_fields = [field for field in required_fields if field not in intent]
        if missing_fields:
            raise IntentValidationError(f"Missing required fields: {missing_fields}")

        # Validate service type
        service_type = intent.get("serviceType", "enhanced-mobile-broadband")
        if service_type not in self.SERVICE_TYPE_MAPPING:
            self.logger.warning(f"Unknown service type '{service_type}', using default")

        # Validate target site
        target_site = intent.get("targetSite", "both")
        valid_targets = {"edge1", "edge2", "both"}
        if target_site not in valid_targets:
            raise IntentValidationError(f"Invalid targetSite '{target_site}', must be one of: {valid_targets}")

        self.logger.debug(f"Intent validation passed for {intent.get('intentId')}")
        return intent

    def _get_target_sites(self, intent: Dict[str, Any]) -> List[str]:
        """Determine target sites from intent."""
        target = intent.get("targetSite", "both")
        if target == "both":
            return ["edge1", "edge2"]
        return [target]

    def _generate_krm_for_site(self, intent: Dict[str, Any], site: str) -> List[Dict[str, Any]]:
        """Generate KRM resources for a specific site with deterministic ordering.

        Args:
            intent: Validated intent data
            site: Target site name

        Returns:
            List of KRM resources with sorted keys for deterministic output
        """
        if site not in self.SITE_CONFIG:
            raise ResourceGenerationError(f"Unknown site: {site}")

        resources = []

        try:
            # Generate resources in deterministic order
            # 1. ProvisioningRequest
            pr = self._create_provisioning_request(intent, site)
            resources.append(self._sort_resource_keys(pr))

            # 2. ConfigMap with intent metadata
            cm = self._create_intent_configmap(intent, site)
            resources.append(self._sort_resource_keys(cm))

            # 3. NetworkSlice if SLA specified
            if "sla" in intent:
                ns = self._create_network_slice(intent, site)
                resources.append(self._sort_resource_keys(ns))

            # 4. Kustomization for overlays (always last)
            kustomization = self._create_kustomization(intent, site)
            resources.append(self._sort_resource_keys(kustomization))

        except Exception as e:
            raise ResourceGenerationError(f"Failed to generate resources for site {site}: {e}")

        return resources

    def _sort_resource_keys(self, resource: Dict[str, Any]) -> Dict[str, Any]:
        """Recursively sort all dictionary keys for deterministic output.

        Args:
            resource: Resource dictionary to sort

        Returns:
            Resource with all nested dictionaries sorted by key
        """
        if isinstance(resource, dict):
            sorted_dict = {}
            for key in sorted(resource.keys()):
                sorted_dict[key] = self._sort_resource_keys(resource[key])
            return sorted_dict
        elif isinstance(resource, list):
            return [self._sort_resource_keys(item) for item in resource]
        else:
            return resource

    def _create_provisioning_request(self, intent: Dict[str, Any], site: str) -> Dict[str, Any]:
        """Create O2IMS ProvisioningRequest with deterministic timestamp.

        Args:
            intent: Intent data
            site: Target site

        Returns:
            ProvisioningRequest resource
        """
        service_type = intent.get("serviceType", "enhanced-mobile-broadband")
        service_config = self.SERVICE_TYPE_MAPPING.get(
            service_type,
            self.SERVICE_TYPE_MAPPING["enhanced-mobile-broadband"]
        )
        site_config = self.SITE_CONFIG[site]

        # Use deterministic timestamp from manifest
        timestamp = self._manifest_data["timestamp"]

        pr = {
            "apiVersion": "o2ims.provisioning.oran.org/v1alpha1",
            "kind": "ProvisioningRequest",
            "metadata": {
                "annotations": {
                    "generated-by": "intent-compiler",
                    "resource-profile": intent.get("resourceProfile", "standard"),
                    "timestamp": timestamp
                },
                "labels": {
                    "intent-id": intent.get("intentId", "unknown"),
                    "service-type": service_type,
                    "target-site": site
                },
                "name": f"{intent.get('intentId', 'unknown')}-{site}",
                "namespace": site_config["namespace"]
            },
            "spec": {
                "description": f"Provisioning request for {service_type} service at {site}",
                "networkConfig": {
                    "gnbId": site_config["gnbIdBase"],
                    "plmnId": site_config["plmnId"],
                    "sliceType": service_config["sliceType"],
                    "tac": site_config["tac"]
                },
                "resourceRequirements": {
                    "cpu": service_config["cpu"],
                    "memory": service_config["memory"],
                    "storage": service_config["storage"]
                },
                "targetCluster": site_config["cluster"]
            }
        }

        # Add SLA parameters if present (sorted keys)
        if "sla" in intent:
            pr["spec"]["slaRequirements"] = self._convert_sla(intent["sla"])

        return pr

    def _create_intent_configmap(self, intent: Dict[str, Any], site: str) -> Dict[str, Any]:
        """Create ConfigMap with intent metadata and deterministic JSON.

        Args:
            intent: Intent data
            site: Target site

        Returns:
            ConfigMap resource
        """
        site_config = self.SITE_CONFIG[site]

        return {
            "apiVersion": "v1",
            "data": {
                "intent.json": json.dumps(intent, indent=2, sort_keys=True),
                "serviceType": intent.get("serviceType", "unknown"),
                "site": site
            },
            "kind": "ConfigMap",
            "metadata": {
                "labels": {
                    "intent-id": intent.get("intentId", "unknown"),
                    "target-site": site
                },
                "name": f"intent-{intent.get('intentId', 'unknown')}-{site}",
                "namespace": site_config["namespace"]
            }
        }

    def _create_network_slice(self, intent: Dict[str, Any], site: str) -> Dict[str, Any]:
        """Create NetworkSlice resource with sorted keys.

        Args:
            intent: Intent data
            site: Target site

        Returns:
            NetworkSlice resource
        """
        site_config = self.SITE_CONFIG[site]
        service_type = intent.get("serviceType", "enhanced-mobile-broadband")

        # Validate service type exists
        if service_type not in self.SERVICE_TYPE_MAPPING:
            service_type = "enhanced-mobile-broadband"

        ns = {
            "apiVersion": "workload.nephio.org/v1alpha1",
            "kind": "NetworkSlice",
            "metadata": {
                "labels": {
                    "intent-id": intent.get("intentId", "unknown"),
                    "service-type": service_type,
                    "target-site": site
                },
                "name": f"slice-{intent.get('intentId', 'unknown')}-{site}",
                "namespace": site_config["namespace"]
            },
            "spec": {
                "plmn": {
                    "mcc": site_config["plmnId"][:3],
                    "mnc": site_config["plmnId"][3:]
                },
                "sliceType": self.SERVICE_TYPE_MAPPING[service_type]["sliceType"]
            }
        }

        # Add SLA-based QoS parameters (sorted)
        if "sla" in intent:
            ns["spec"]["qos"] = self._convert_sla_to_qos(intent["sla"])

        return ns

    def _create_kustomization(self, intent: Dict[str, Any], site: str) -> Dict[str, Any]:
        """Create Kustomization for site-specific overlays with sorted resources.

        Args:
            intent: Intent data
            site: Target site

        Returns:
            Kustomization resource
        """
        intent_id = intent.get("intentId", "unknown")

        # Build resource list deterministically
        resources = [
            f"{intent_id}-{site}-provisioning-request.yaml",
            f"intent-{intent_id}-{site}-configmap.yaml"
        ]

        # Add NetworkSlice if SLA exists
        if "sla" in intent:
            resources.append(f"slice-{intent_id}-{site}-networkslice.yaml")

        # Sort resources for deterministic output
        resources.sort()

        return {
            "apiVersion": "kustomize.config.k8s.io/v1beta1",
            "commonLabels": {
                "intent-id": intent_id,
                "target-site": site
            },
            "kind": "Kustomization",
            "metadata": {
                "annotations": {
                    "config.kubernetes.io/local-config": "true"
                },
                "name": f"kustomization-{site}"
            },
            "namespace": self.SITE_CONFIG[site]["namespace"],
            "resources": resources
        }

    def _convert_sla(self, sla: Dict[str, Any]) -> Dict[str, Any]:
        """Convert SLA requirements to O2IMS format with sorted keys.

        Args:
            sla: SLA requirements dictionary

        Returns:
            O2IMS formatted SLA requirements
        """
        result = {}

        # Process in sorted order for deterministic output
        if "availability" in sla:
            result["availability"] = f"{sla['availability']}%"
        if "connections" in sla:
            result["maxConnections"] = str(sla["connections"])
        if "latency" in sla:
            result["maxLatency"] = f"{sla['latency']}ms"
        if "throughput" in sla:
            result["minThroughput"] = f"{sla['throughput']}Mbps"

        return result

    def _convert_sla_to_qos(self, sla: Dict[str, Any]) -> Dict[str, Any]:
        """Convert SLA to QoS parameters with deterministic ordering.

        Args:
            sla: SLA requirements dictionary

        Returns:
            QoS parameters with 5QI classification
        """
        qos = {"5qi": 9}  # Default 5QI value

        # Process latency first for QoS classification
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

        # Add throughput guarantee if specified
        if "throughput" in sla:
            qos["gfbr"] = f"{sla['throughput']}Mbps"

        return qos

    def save_resources(self, results: Dict[str, List[Dict[str, Any]]]) -> str:
        """Save KRM resources to files with checksums and manifest generation.

        Args:
            results: Dictionary mapping sites to resource lists

        Returns:
            Path to generated manifest file

        Raises:
            FileSystemError: If file operations fail
        """
        try:
            self.output_dir.mkdir(parents=True, exist_ok=True)

            for site in sorted(results.keys()):
                resources = results[site]
                site_dir = self.output_dir / site
                site_dir.mkdir(parents=True, exist_ok=True)

                self.logger.info(f"Saving {len(resources)} resources for site {site}")

                for resource in resources:
                    filename = self._get_resource_filename(resource)
                    filepath = site_dir / filename

                    # Check if file needs updating (idempotency)
                    content = yaml.dump(resource, default_flow_style=False, sort_keys=True)
                    content_hash = self._calculate_checksum(content)

                    should_write = True
                    if self.enable_caching and filepath.exists():
                        existing_content = filepath.read_text(encoding='utf-8')
                        existing_hash = self._calculate_checksum(existing_content)
                        if existing_hash == content_hash:
                            should_write = False
                            self.logger.debug(f"Skipping unchanged file: {filepath}")

                    if should_write:
                        with open(filepath, 'w', encoding='utf-8') as f:
                            f.write(content)
                        self.logger.info(f"Generated: {filepath}")

                    # Record in manifest
                    relative_path = filepath.relative_to(self.output_dir)
                    self._manifest_data["generated_files"][str(relative_path)] = {
                        "checksum": content_hash,
                        "size_bytes": len(content.encode('utf-8')),
                        "resource_kind": resource.get("kind", "Unknown")
                    }

            # Generate and save manifest
            manifest_path = self._save_manifest()
            self.logger.info(f"Generated manifest: {manifest_path}")
            return str(manifest_path)

        except (IOError, OSError) as e:
            raise FileSystemError(f"Failed to save resources: {e}")

    def _calculate_checksum(self, content: str) -> str:
        """Calculate SHA256 checksum of content.

        Args:
            content: String content to hash

        Returns:
            Hexadecimal SHA256 checksum
        """
        return hashlib.sha256(content.encode('utf-8')).hexdigest()

    def _save_manifest(self) -> Path:
        """Save generation manifest with metadata and checksums.

        Returns:
            Path to saved manifest file
        """
        manifest_path = self.output_dir / "manifest.json"

        # Add summary statistics
        self._manifest_data["summary"] = {
            "total_files": len(self._manifest_data["generated_files"]),
            "total_sites": len(self._manifest_data["target_sites"]),
            "total_resources": sum(self._manifest_data["resource_counts"].values())
        }

        with open(manifest_path, 'w', encoding='utf-8') as f:
            json.dump(self._manifest_data, f, indent=2, sort_keys=True)

        return manifest_path

    def _get_resource_filename(self, resource: Dict[str, Any]) -> str:
        """Generate deterministic filename for resource.

        Args:
            resource: Kubernetes resource dictionary

        Returns:
            Generated filename
        """
        kind = resource.get("kind", "unknown").lower()
        name = resource.get("metadata", {}).get("name", "unknown")

        # Map kinds to filename patterns (deterministic)
        filename_map = {
            "configmap": f"{name}-configmap.yaml",
            "kustomization": "kustomization.yaml",
            "networkslice": f"{name}-networkslice.yaml",
            "provisioningrequest": f"{name}-provisioning-request.yaml"
        }

        return filename_map.get(kind, f"{name}-{kind}.yaml")

    def get_resource_checksums(self, results: Dict[str, List[Dict[str, Any]]]) -> Dict[str, str]:
        """Calculate checksums for all resources without saving files.

        Args:
            results: Resource generation results

        Returns:
            Dictionary mapping resource identifiers to checksums
        """
        checksums = {}

        for site in sorted(results.keys()):
            for resource in results[site]:
                content = yaml.dump(resource, default_flow_style=False, sort_keys=True)
                checksum = self._calculate_checksum(content)

                kind = resource.get("kind", "unknown")
                name = resource.get("metadata", {}).get("name", "unknown")
                resource_id = f"{site}/{kind}/{name}"
                checksums[resource_id] = checksum

        return checksums


def main():
    """Main entry point for the intent translator."""
    parser = ArgumentParser(
        description="Translate TMF921 intents to KRM resources with deterministic output",
        epilog="Generates manifest.json with checksums for idempotency checks"
    )
    parser.add_argument(
        "intent_file",
        help="Path to intent JSON file"
    )
    parser.add_argument(
        "-o", "--output",
        default="rendered/krm",
        help="Output directory for KRM resources (default: rendered/krm)"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print resources without saving to files"
    )
    parser.add_argument(
        "--no-cache",
        action="store_true",
        help="Disable idempotency caching (always regenerate files)"
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Enable verbose logging"
    )
    parser.add_argument(
        "--checksums-only",
        action="store_true",
        help="Only calculate and display resource checksums"
    )

    args = parser.parse_args()

    # Setup logging
    log_level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(
        level=log_level,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )

    logger = logging.getLogger("intent-translator")

    # Validate input file
    if not os.path.exists(args.intent_file):
        logger.error(f"Intent file not found: {args.intent_file}")
        sys.exit(1)

    # Initialize translator
    translator = IntentToKRMTranslator(
        output_dir=args.output,
        enable_caching=not args.no_cache
    )

    try:
        # Translate intent
        results = translator.translate(args.intent_file)
        logger.info("Intent translation completed successfully")

        if args.checksums_only:
            # Only calculate checksums
            checksums = translator.get_resource_checksums(results)
            print("\n=== Resource Checksums ===")
            for resource_id in sorted(checksums.keys()):
                print(f"{resource_id}: {checksums[resource_id]}")

        elif args.dry_run:
            # Print resources without saving
            print("\n=== DRY RUN: Generated Resources ===")
            for site in sorted(results.keys()):
                print(f"\n--- Site: {site} ---")
                for resource in results[site]:
                    print(yaml.dump(resource, default_flow_style=False, sort_keys=True))
                    print("---")

            # Show checksums in dry run
            checksums = translator.get_resource_checksums(results)
            print("\n=== Resource Checksums ===")
            for resource_id in sorted(checksums.keys()):
                print(f"{resource_id}: {checksums[resource_id]}")
        else:
            # Save resources and generate manifest
            manifest_path = translator.save_resources(results)
            total_files = len(translator._manifest_data["generated_files"])
            total_resources = sum(translator._manifest_data["resource_counts"].values())

            print(f"\n=== Translation Complete ===")
            print(f"Generated {total_resources} resources in {total_files} files")
            print(f"Output directory: {args.output}")
            print(f"Manifest file: {manifest_path}")
            print(f"Target sites: {', '.join(sorted(translator._manifest_data['target_sites']))}")

    except IntentTranslationError as e:
        logger.error(f"Translation error: {e}")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        if args.verbose:
            logger.exception("Full traceback:")
        sys.exit(1)


if __name__ == "__main__":
    main()