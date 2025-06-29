#!/bin/bash

# Script to find the latest RDS snapshot based on naming convention
# Usage: ./find-latest-snapshot.sh [prefix]
# Returns: Latest snapshot identifier or empty string if none found

set -e

# Default prefix if not provided
PREFIX=${1:-"ml-simple"}
SNAPSHOT_PATTERN="${PREFIX}-db-final-snapshot_"

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