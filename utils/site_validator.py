#!/usr/bin/env python3
"""
Site Validation Utilities for 4-Site Support
Centralized validation for edge1, edge2, edge3, edge4 across all services
"""

import yaml
import os
from typing import List, Dict, Any, Optional
from dataclasses import dataclass

@dataclass
class SiteConfig:
    """Site configuration data structure"""
    name: str
    ip: str
    location: str
    status: str
    ports: List[int]

class SiteValidator:
    """Validates and normalizes site identifiers across services"""

    def __init__(self, config_path: Optional[str] = None):
        """Initialize with config file path"""
        if config_path is None:
            config_path = "/home/ubuntu/nephio-intent-to-o2-demo/config/edge-sites-config.yaml"

        self.config_path = config_path
        self.valid_sites = ["edge1", "edge2", "edge3", "edge4"]
        self.site_configs = self._load_site_configs()

    def _load_site_configs(self) -> Dict[str, SiteConfig]:
        """Load site configurations from YAML file"""
        try:
            with open(self.config_path, 'r') as f:
                config = yaml.safe_load(f)

            sites = {}
            for site_id, site_data in config.get('sites', {}).items():
                if site_id in self.valid_sites:
                    sites[site_id] = SiteConfig(
                        name=site_data.get('name', site_id),
                        ip=site_data.get('network', {}).get('internal_ip', ''),
                        location=site_data.get('location', ''),
                        status=site_data.get('status', {}).get('connectivity', 'unknown'),
                        ports=[30090, 30205, 6443]  # Default ports
                    )

            return sites
        except Exception as e:
            print(f"Warning: Could not load site configs: {e}")
            return self._get_default_configs()

    def _get_default_configs(self) -> Dict[str, SiteConfig]:
        """Get default site configurations"""
        return {
            "edge1": SiteConfig("Edge1 (VM-2)", "172.16.4.45", "VM-2", "operational", [30090, 31280, 6443]),
            "edge2": SiteConfig("Edge2 (VM-4)", "172.16.4.176", "VM-4", "operational", [30090, 31280, 6443]),
            "edge3": SiteConfig("Edge3 (New)", "172.16.5.81", "Remote Site", "operational", [30090, 31280, 6443]),
            "edge4": SiteConfig("Edge4 (New)", "172.16.1.252", "Remote Site 2", "operational", [30090, 31280, 6443])
        }

    def is_valid_site(self, site: str) -> bool:
        """Check if site identifier is valid"""
        return site in self.valid_sites

    def normalize_site(self, site: str) -> Optional[str]:
        """Normalize site identifier to standard format"""
        if not site:
            return None

        site_lower = site.lower().strip()

        # Handle various formats
        if site_lower in ["edge1", "edge01", "edge-1", "site1", "site 1"]:
            return "edge1"
        elif site_lower in ["edge2", "edge02", "edge-2", "site2", "site 2"]:
            return "edge2"
        elif site_lower in ["edge3", "edge03", "edge-3", "site3", "site 3"]:
            return "edge3"
        elif site_lower in ["edge4", "edge04", "edge-4", "site4", "site 4"]:
            return "edge4"
        elif site_lower in ["both", "all", "multiple", "all sites"]:
            return "both"

        return None

    def validate_site_list(self, sites: List[str]) -> List[str]:
        """Validate and normalize a list of sites"""
        validated = []
        for site in sites:
            normalized = self.normalize_site(site)
            if normalized and normalized != "both":
                if normalized not in validated:
                    validated.append(normalized)
            elif normalized == "both":
                return self.valid_sites  # Return all sites

        return validated if validated else ["edge1"]  # Default fallback

    def get_site_config(self, site: str) -> Optional[SiteConfig]:
        """Get configuration for a specific site"""
        normalized = self.normalize_site(site)
        return self.site_configs.get(normalized) if normalized else None

    def get_all_sites(self) -> List[str]:
        """Get list of all valid sites"""
        return self.valid_sites.copy()

    def get_site_endpoints(self, site: str) -> Dict[str, str]:
        """Get API endpoints for a site"""
        config = self.get_site_config(site)
        if not config:
            return {}

        return {
            "slo_metrics": f"http://{config.ip}:30090/metrics/api/v1/slo",
            "o2ims_api": f"http://{config.ip}:30205",
            "kubernetes_api": f"https://{config.ip}:6443",
            "health_check": f"http://{config.ip}:30090/health"
        }

    def validate_target_sites_param(self, target_sites: Any) -> List[str]:
        """
        Validate target_sites parameter from API requests
        Handles string, list, or None inputs
        """
        if target_sites is None:
            return ["edge1"]  # Default

        if isinstance(target_sites, str):
            # Single site as string
            if target_sites.lower() in ["both", "all"]:
                return self.valid_sites
            normalized = self.normalize_site(target_sites)
            return [normalized] if normalized else ["edge1"]

        if isinstance(target_sites, list):
            # List of sites
            return self.validate_site_list(target_sites)

        # Invalid type
        return ["edge1"]

# Global validator instance
validator = SiteValidator()

def validate_sites(sites: Any) -> List[str]:
    """Convenience function for site validation"""
    return validator.validate_target_sites_param(sites)

def is_valid_site(site: str) -> bool:
    """Convenience function to check if site is valid"""
    return validator.is_valid_site(site)

def get_site_endpoints(site: str) -> Dict[str, str]:
    """Convenience function to get site endpoints"""
    return validator.get_site_endpoints(site)

def get_all_valid_sites() -> List[str]:
    """Convenience function to get all valid sites"""
    return validator.get_all_sites()

# Export commonly used functions
__all__ = [
    'SiteValidator',
    'SiteConfig',
    'validator',
    'validate_sites',
    'is_valid_site',
    'get_site_endpoints',
    'get_all_valid_sites'
]

if __name__ == "__main__":
    # Test the validator
    print("Testing Site Validator:")
    print(f"Valid sites: {validator.get_all_sites()}")

    test_cases = [
        "edge1", "edge2", "edge3", "edge4",
        "Edge1", "EDGE2", "edge-3", "site 4",
        "both", "all", "invalid", None, ["edge1", "edge3"]
    ]

    for test in test_cases:
        result = validator.validate_target_sites_param(test)
        print(f"Input: {test} -> Output: {result}")

    # Test site configs
    for site in validator.get_all_sites():
        config = validator.get_site_config(site)
        endpoints = validator.get_site_endpoints(site)
        print(f"\n{site}: {config.name} at {config.ip}")
        print(f"  SLO: {endpoints['slo_metrics']}")