#!/usr/bin/env python3
"""
SMO/GitOps Orchestrator - Unified Pipeline Execution
Implements Intent → KRM → GitOps → Deployment with SLO gates
"""

import json
import subprocess
import sys
import time
import shutil
from pathlib import Path
from datetime import datetime
from typing import Dict, Any, Optional, Tuple
import hashlib
import argparse


class GitOpsOrchestrator:
    """End-to-end orchestration from Intent to Deployment"""

    def __init__(self, mode: str = "safe", dry_run: bool = False):
        self.mode = mode  # "safe" or "headless"
        self.dry_run = dry_run
        self.timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.report_dir = Path(f"reports/{self.timestamp}")
        self.report_dir.mkdir(parents=True, exist_ok=True)
        self.execution_log = []
        self.rollback_point = None

    def log(self, message: str, level: str = "INFO"):
        """Log with timestamp"""
        log_entry = f"[{datetime.now().isoformat()}] [{level}] {message}"
        print(log_entry)
        self.execution_log.append(log_entry)

    def checkpoint(self, phase: str) -> bool:
        """Interactive checkpoint in safe mode"""
        if self.mode == "safe" and not self.dry_run:
            response = input(f"\n🔵 Proceed with {phase}? (y/n): ")
            return response.lower() == 'y'
        return True

    def create_snapshot(self) -> str:
        """Create git snapshot for rollback"""
        self.log("Creating git snapshot for rollback")
        result = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            capture_output=True, text=True
        )
        self.rollback_point = result.stdout.strip()
        self.log(f"Snapshot created: {self.rollback_point}")
        return self.rollback_point

    def validate_intent(self, intent_path: Path) -> Tuple[bool, Dict]:
        """Validate Intent JSON schema and structure"""
        self.log(f"Validating intent: {intent_path}")

        try:
            with open(intent_path) as f:
                intent_data = json.load(f)

            # Check required fields
            required = ["intentId", "intentExpectations"]
            for field in required:
                if field not in intent_data:
                    return False, {"error": f"Missing required field: {field}"}

            # Store validated intent
            shutil.copy(intent_path, self.report_dir / "intent.json")

            return True, intent_data

        except Exception as e:
            return False, {"error": str(e)}

    def render_krm(self, intent_path: Path) -> Tuple[bool, Path]:
        """Render Intent to KRM using kpt functions"""
        self.log("Rendering Intent to KRM packages")

        krm_output = self.report_dir / "rendered"
        krm_output.mkdir(exist_ok=True)

        if self.dry_run:
            self.log("DRY RUN: Would render KRM packages")
            return True, krm_output

        # Execute kpt render pipeline
        cmd = [
            "kpt", "fn", "render",
            "--input", str(intent_path),
            "--output", str(krm_output),
            "--fn-config", "packages/intent-to-krm/expectation-config.yaml"
        ]

        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode != 0:
            self.log(f"KRM render failed: {result.stderr}", "ERROR")
            return False, krm_output

        # Calculate checksums
        self.calculate_checksums(krm_output)

        return True, krm_output

    def calculate_checksums(self, directory: Path):
        """Calculate SHA256 checksums for artifacts"""
        checksums = {}
        for file in directory.rglob("*.yaml"):
            with open(file, 'rb') as f:
                checksums[str(file)] = hashlib.sha256(f.read()).hexdigest()

        checksum_file = self.report_dir / "checksums.sha256"
        with open(checksum_file, 'w') as f:
            for path, hash in checksums.items():
                f.write(f"{hash}  {path}\n")

        self.log(f"Checksums written to {checksum_file}")

    def publish_gitops(self, krm_path: Path, target: str) -> bool:
        """Publish KRM to GitOps repository"""
        self.log(f"Publishing to GitOps repository: {target}")

        gitops_dir = Path(f"slo-gated-gitops/{target}")

        if not gitops_dir.exists():
            self.log(f"GitOps directory not found: {gitops_dir}", "ERROR")
            return False

        if self.dry_run:
            self.log(f"DRY RUN: Would publish to {gitops_dir}")
            return True

        # Copy KRM packages to GitOps repo
        target_dir = gitops_dir / "deployments"
        target_dir.mkdir(exist_ok=True)

        for krm_file in krm_path.glob("*.yaml"):
            shutil.copy(krm_file, target_dir)

        # Commit and push
        subprocess.run(["git", "add", str(gitops_dir)], cwd=".")
        subprocess.run([
            "git", "commit", "-m",
            f"feat: Deploy Intent {self.timestamp} to {target}"
        ], cwd=".")

        return True

    def check_slo_gates(self, target: str) -> Tuple[bool, Dict]:
        """Check SLO gates for deployment"""
        self.log(f"Checking SLO gates for {target}")

        # Query SLO endpoint
        slo_url = {
            "edge1": "http://172.16.4.45:30090",
            "edge2": "http://172.16.4.176:30090"
        }.get(target)

        if not slo_url:
            return False, {"error": f"Unknown target: {target}"}

        try:
            # Simulate SLO check (would use requests in real implementation)
            cmd = ["curl", "-s", f"{slo_url}/api/v1/slo/status"]
            result = subprocess.run(cmd, capture_output=True, text=True)

            if "PASS" in result.stdout:
                return True, {"status": "PASS", "details": result.stdout}
            else:
                return False, {"status": "FAIL", "details": result.stdout}

        except Exception as e:
            return False, {"error": str(e)}

    def rollback(self):
        """Execute rollback to snapshot"""
        self.log("Executing rollback", "WARN")

        if not self.rollback_point:
            self.log("No rollback point available", "ERROR")
            return False

        if self.dry_run:
            self.log(f"DRY RUN: Would rollback to {self.rollback_point}")
            return True

        subprocess.run(["git", "reset", "--hard", self.rollback_point])
        self.log(f"Rolled back to {self.rollback_point}")
        return True

    def generate_report(self, success: bool, details: Dict):
        """Generate final execution report"""
        report = {
            "timestamp": self.timestamp,
            "success": success,
            "mode": self.mode,
            "dry_run": self.dry_run,
            "rollback_point": self.rollback_point,
            "execution_log": self.execution_log,
            "details": details
        }

        report_file = self.report_dir / "execution_report.json"
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2)

        # Save execution log
        log_file = self.report_dir / "execution.log"
        with open(log_file, 'w') as f:
            f.write("\n".join(self.execution_log))

        self.log(f"Report generated: {report_file}")

        return report

    def orchestrate(self, intent_path: str, targets: list):
        """Main orchestration workflow"""
        self.log("=" * 60)
        self.log("SMO/GitOps Orchestrator Starting")
        self.log(f"Mode: {self.mode}, Targets: {targets}")
        self.log("=" * 60)

        details = {}

        # Phase 1: PLAN
        if not self.checkpoint("PLAN"):
            return False

        self.create_snapshot()

        # Phase 2: TESTS
        if not self.checkpoint("TESTS"):
            return False

        valid, intent_data = self.validate_intent(Path(intent_path))
        if not valid:
            self.log("Intent validation failed", "ERROR")
            return self.generate_report(False, {"phase": "TESTS", **intent_data})

        # Phase 3: RENDER
        if not self.checkpoint("RENDER"):
            return False

        success, krm_path = self.render_krm(Path(intent_path))
        if not success:
            self.log("KRM rendering failed", "ERROR")
            self.rollback()
            return self.generate_report(False, {"phase": "RENDER"})

        # Phase 4-7: Per-target deployment
        for target in targets:
            self.log(f"\nProcessing target: {target}")

            # Phase 4: PUBLISH
            if not self.checkpoint(f"PUBLISH to {target}"):
                continue

            if not self.publish_gitops(krm_path, target):
                self.log(f"GitOps publish failed for {target}", "ERROR")
                self.rollback()
                return self.generate_report(False, {"phase": "PUBLISH", "target": target})

            # Phase 5: VERIFY
            self.log(f"Waiting for deployment verification on {target}")
            time.sleep(5)  # Allow Config Sync to process

            # Phase 6: GATE
            if not self.checkpoint(f"GATE check for {target}"):
                continue

            gate_pass, gate_details = self.check_slo_gates(target)
            details[f"{target}_gate"] = gate_details

            if not gate_pass:
                self.log(f"SLO gate failed for {target}", "ERROR")

                # Phase 7: ROLLBACK
                if self.mode == "headless" or self.checkpoint("ROLLBACK"):
                    self.rollback()

                return self.generate_report(False, {
                    "phase": "GATE",
                    "target": target,
                    "gates": details
                })

        # Phase 8: REPORT
        self.log("\n" + "=" * 60)
        self.log("Orchestration completed successfully")
        self.log("=" * 60)

        return self.generate_report(True, {"gates": details})


def main():
    parser = argparse.ArgumentParser(
        description="SMO/GitOps Orchestrator - Intent to Deployment Pipeline"
    )
    parser.add_argument(
        "intent",
        help="Path to Intent JSON file"
    )
    parser.add_argument(
        "--targets",
        nargs="+",
        default=["edge1", "edge2"],
        choices=["edge1", "edge2"],
        help="Deployment targets (default: both edges)"
    )
    parser.add_argument(
        "--mode",
        default="safe",
        choices=["safe", "headless"],
        help="Execution mode (default: safe)"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Simulate execution without making changes"
    )

    args = parser.parse_args()

    # Initialize orchestrator
    orchestrator = GitOpsOrchestrator(
        mode=args.mode,
        dry_run=args.dry_run
    )

    # Execute pipeline
    try:
        report = orchestrator.orchestrate(args.intent, args.targets)

        if report and report.get("success"):
            print(f"\n✅ Success! Report: {orchestrator.report_dir}")
            sys.exit(0)
        else:
            print(f"\n❌ Failed! Report: {orchestrator.report_dir}")
            sys.exit(1)

    except KeyboardInterrupt:
        print("\n⚠️  Orchestration interrupted")
        orchestrator.rollback()
        sys.exit(130)
    except Exception as e:
        print(f"\n❌ Fatal error: {e}")
        orchestrator.rollback()
        sys.exit(1)


if __name__ == "__main__":
    main()