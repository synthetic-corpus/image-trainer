#!/bin/bash

# Script to find the latest RDS snapshot based on naming convention
# Usage: ./find-latest-snapshot.sh [prefix]
# Returns: Latest snapshot identifier or empty string if none found

set -e

# Read workspace from .workspace file (created by GitHub workflow)
# The script runs from infra/deploy/scripts, so .workspace is at ../../.workspace
WORKSPACE_FILE="../../../.workspace"
if [ -f "$WORKSPACE_FILE" ]; then
    WORKSPACE=$(cat "$WORKSPACE_FILE")
    PREFIX="ml-simple-${WORKSPACE}"
    echo "Using workspace from .workspace file: ${WORKSPACE}" >&2
    echo "Workspace file path: $(realpath "$WORKSPACE_FILE")" >&2
else
    # Fallback: Default prefix if not provided
    PREFIX=${1:-"ml-simple"}
    echo "No .workspace file found at $WORKSPACE_FILE, using default prefix: ${PREFIX}" >&2
    echo "Current directory: $(pwd)" >&2
    echo "Files in current directory:" >&2
    ls -la >&2
    echo "Files in parent directory:" >&2
    ls -la .. >&2
    echo "Files in grandparent directory:" >&2
    ls -la ../.. >&2
fi
SNAPSHOT_PATTERN="${PREFIX}-db-final-snapshot-"

echo "Looking for snapshots matching pattern: ${SNAPSHOT_PATTERN}" >&2

# Find the latest snapshot by creation time
LATEST_SNAPSHOT=$(aws rds describe-db-snapshots \
  --query "DBSnapshots[?starts_with(DBSnapshotIdentifier, \`${SNAPSHOT_PATTERN}\`) && Status==\`available\`] | sort_by(@, &SnapshotCreateTime) | [-1].DBSnapshotIdentifier" \
  --output text 2>/dev/null || echo "")

# Check if we found a snapshot
if [ -z "$LATEST_SNAPSHOT" ] || [ "$LATEST_SNAPSHOT" = "None" ]; then
    echo "No available snapshots found matching pattern: ${SNAPSHOT_PATTERN}" >&2
    echo ""
    exit 0
else
    echo "Found latest snapshot: ${LATEST_SNAPSHOT}" >&2
    echo "$LATEST_SNAPSHOT"
    exit 0
fi 