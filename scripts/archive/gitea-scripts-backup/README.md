# Gitea Scripts Archive

This directory contains archived Gitea-related scripts that were moved during the cleanup process on 2025-09-13.

## Archived Scripts

### `gitea_tunnel_alternatives.sh`
- **Purpose**: Alternative tunneling methods for Gitea access
- **Status**: Archived - functionality covered by main setup scripts
- **Reason**: Alternative approach, not needed for primary workflow

### `gitea_web_ui.sh`
- **Purpose**: Simple wrapper for opening Gitea web UI
- **Status**: Archived - simple functionality that can be done manually
- **Reason**: Minimal functionality, not essential for automation

### `remote_gitea_access.sh`
- **Purpose**: Remote Gitea access configuration
- **Status**: Archived - duplicate functionality
- **Reason**: Overlaps with setup_gitea_access.sh

## Restoration

If any of these scripts are needed, they can be restored from this archive:

```bash
# Restore a specific script
cp scripts/archive/gitea-scripts-backup/<script-name> scripts/

# Make executable
chmod +x scripts/<script-name>
```

## Cleanup Date

Scripts archived: 2025-09-13
Cleanup performed by: Claude Code (outdated deployment analysis)