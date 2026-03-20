#!/bin/sh
# scripts/setup_shm.sh - Shared Memory Environment Preparation
# This script initializes the /dev/shm segment with correct size and permissions.

SHM_PATH="/dev/shm/concrete.data"
SHM_SIZE=4096

echo "🏗️  Preparing Concrete SHM environment..."

# 1. Kill any stale core processes to release file locks
# Redirecting to /dev/null to keep the output clean if no process is found
pkill -9 concrete_core 2>/dev/null

# 2. Remove existing SHM file with elevated privileges if necessary
# This clears any previous "Permission Denied" states from Docker-owned files
if [ -f "$SHM_PATH" ]; then
    echo "🧹 Removing stale SHM file: $SHM_PATH"
    sudo rm -f "$SHM_PATH"
fi

# 3. Create a fresh, zeroed-out memory segment
# 'truncate' is used to set the exact size without writing 4KB of actual zeros to disk/RAM yet
echo "📦 Allocating $SHM_SIZE bytes for $SHM_PATH"
truncate -s $SHM_SIZE "$SHM_PATH"

# 4. Set global read/write permissions
# This allows the 'concrete_core' (Assembly) and 'bench.go' (Go) to communicate
# regardless of which user started the process.
chmod 666 "$SHM_PATH"

echo "------------------------------------------------"
echo "✅ SHM Setup Complete."
echo "🚀 You can now start the core: ./bin/concrete_core"
echo "------------------------------------------------"