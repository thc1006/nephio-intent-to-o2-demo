# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v1.1.1] - 2025-09-14

### Added
- Comprehensive project deep analysis report (PROJECT_DEEP_ANALYSIS_v1.1.1.md)
- Complete documentation reorganization with architecture files moved to root
- Enhanced network topology documentation with detailed VM connectivity matrix
- Full test coverage reports and metrics

### Changed
- Updated version references from v1.1.0-rc2 to v1.1.1
- Reorganized architecture documentation for better accessibility
- Improved GitOps configuration structure for multi-site deployments
- Enhanced security reporting with three modes (dev/normal/strict)

### Fixed
- Documentation path references corrected
- Network configuration inconsistencies resolved
- VM-4 connectivity documentation updated with proper internal-ipv4 references

### Documentation
- Added 46+ markdown documentation files
- Created comprehensive network configuration guide (AUTHORITATIVE_NETWORK_CONFIG.md)
- Updated system architecture HLA documentation (21KB)
- Enhanced deployment guides and runbooks

### Infrastructure
- 86 automation scripts fully documented and tested
- Multi-site support validated (Edge1: 100%, Edge2: 95%)
- GitOps pipeline fully operational with Config Sync
- O2IMS integration completed with proper API endpoints

## [v1.1.0-rc2] - 2025-09-13

### Added
- Initial release candidate with core functionality
- Basic multi-site support
- GitOps integration framework
- O-RAN O2IMS SDK implementation

### Changed
- Refactored intent-to-KRM compilation pipeline
- Updated Python dependencies to 3.11
- Upgraded Go version to 1.22

### Fixed
- Various bug fixes and performance improvements
- Security vulnerabilities patched
- Test coverage improved

## [v1.0.0] - 2025-09-01

### Added
- Initial project structure
- Basic Nephio integration
- Simple intent processing
- Single-site deployment support

---

For detailed release notes, see individual RELEASE_NOTES_*.md files.