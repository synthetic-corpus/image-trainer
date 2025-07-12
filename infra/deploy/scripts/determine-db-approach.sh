#!/bin/bash

# Script to determine whether to restore from snapshot or create fresh database
# Usage: ./determine-db-approach.sh [prefix]
# Outputs: Environment variables for Terraform

set -e

# Read workspace from .workspace file (created by GitHub workflow)
if [ -f "../../.workspace" ]; then
    WORKSPACE=$(cat ../../.workspace)
    PREFIX="ml-simple-${WORKSPACE}"
    echo "Using workspace from .workspace file: ${WORKSPACE}" >&2
else
    # Fallback: Default prefix if not provided
    PREFIX=${1:-"ml-simple"}
    echo "No .workspace file found, using default prefix: ${PREFIX}" >&2
fi

echo "Determining database approach for prefix: ${PREFIX}" >&2

# Find the latest snapshot
LATEST_SNAPSHOT=$(./find-latest-snapshot.sh "${PREFIX}")

if [ -n "$LATEST_SNAPSHOT" ]; then
    echo "Found snapshot: ${LATEST_SNAPSHOT}" >&2
    echo "USE_SNAPSHOT=true"
    echo "SNAPSHOT_IDENTIFIER=${LATEST_SNAPSHOT}"
    echo "DB_APPROACH=restore"
else
    echo "No snapshot found, will create fresh database" >&2
    echo "USE_SNAPSHOT=false"
    echo "SNAPSHOT_IDENTIFIER="
    echo "DB_APPROACH=fresh"
fi 