# Package Artifacts Script Usage

The `scripts/package_artifacts.sh` script provides comprehensive supply chain trust artifact packaging for O-RAN L Release compliance.

## Quick Start

```bash
# Basic packaging
./scripts/package_artifacts.sh

# Preview without changes
./scripts/package_artifacts.sh --dry-run

# Use specific timestamp
./scripts/package_artifacts.sh --timestamp=20240101-120000

# With JSON logging
./scripts/package_artifacts.sh --json-logs
```

## Features

### ✅ Complete Artifact Collection
- Intent JSON files from LLM adapter
- Rendered KRM configurations (edge1/edge2)
- Postcheck SLO validation results
- O2IMS probe data

### ✅ Security & Compliance
- SHA256 checksums for all artifacts
- Cosign attestation support (SLSA L1/L2)
- SBOM generation (if syft available)
- Basic security scanning
- TMF921/O-RAN WG11 compliance metadata

### ✅ Robust Operation
- Idempotent execution
- Partial failure recovery
- Dry-run mode for testing
- Comprehensive logging (standard/JSON)

## Output Structure

```
reports/
├── <timestamp>/
│   ├── artifacts/
│   │   ├── intent.json
│   │   ├── postcheck.json
│   │   ├── o2ims.json
│   │   └── rendered/
│   │       ├── edge1-config/
│   │       └── edge2-config/
│   ├── attestations/
│   │   └── attest.json
│   ├── metadata/
│   │   └── security_scan.json
│   ├── manifest.json
│   └── checksums.txt
├── <timestamp>.tar.gz
├── <timestamp>.tar.gz.sha256
└── latest -> <timestamp>
```

## Compliance Features

### O-RAN WG11 Security
- Tamper-evident artifact packaging
- Complete audit trail generation
- Supply chain integrity verification

### TMF921 Intent Management
- Intent lifecycle documentation
- KRM rendering audit trail
- Multi-site deployment tracking

### FIPS 140-3 Compatible
- SHA256 checksums (FIPS approved)
- Cosign cryptographic attestation
- Secure artifact handling

## Environment Variables

```bash
export REPORTS_BASE_DIR="./custom-reports"     # Base directory for reports
export PACKAGE_MAINTAINER="ops@example.com"   # Maintainer for metadata
export ATTESTATION_KEY="./signing.key"         # Path to signing key
export DRY_RUN="true"                          # Enable dry-run mode
```

## Integration Examples

### CI/CD Pipeline
```bash
# In GitHub Actions or similar
./scripts/package_artifacts.sh --json-logs
tar -czf artifacts.tar.gz reports/latest/
```

### Production Deployment
```bash
# With signing key for attestation
./scripts/package_artifacts.sh \
  --attestation-key=/secure/keys/production.key \
  --timestamp="prod-$(date +%Y%m%d-%H%M%S)"
```

### Development/Testing
```bash
# Quick validation without side effects
./scripts/package_artifacts.sh --dry-run --json-logs
```

## Security Considerations

1. **Artifact Integrity**: All files are checksummed with SHA256
2. **Supply Chain**: Cosign attestations provide SLSA compliance
3. **Audit Trail**: Complete manifest with metadata
4. **Access Control**: Reports directory should have restricted permissions
5. **Key Management**: Signing keys should be stored securely

## Troubleshooting

### Common Issues

**Missing dependencies:**
```bash
# Install required tools
sudo apt-get install jq
curl -O https://github.com/sigstore/cosign/releases/download/v2.2.2/cosign-linux-amd64
```

**Permission denied:**
```bash
chmod +x ./scripts/package_artifacts.sh
```

**Disk space:**
```bash
# Check available space
df -h ./reports/
# Clean old reports
find ./reports/ -name "*.tar.gz" -mtime +7 -delete
```

### Debug Mode
```bash
# Enable detailed logging
LOG_LEVEL=DEBUG ./scripts/package_artifacts.sh --dry-run
```