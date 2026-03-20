#!/bin/sh
# scripts/security_fuzz.sh - Docker-based Protocol Security Audit
# This script spawns a fresh container, launches malformed UDP attacks,
# and verifies the x86_64 Core's resilience against crashes.

IMAGE_NAME="concrete-app:latest"
CONTAINER_NAME="concrete-security-fuzz"
CORE_PORT=8080
CORE_ADDR="127.0.0.1"

echo "🛡️  [SECURITY] Starting Docker-based Fuzzing Suite..."

# 1. PREPARATION: Cleanup previous instances
# Ensuring a clean slate before the audit begins
docker rm -f $CONTAINER_NAME >/dev/null 2>&1

# 2. LAUNCH TARGET CONTAINER
# Running in detached mode with UDP port mapping and shareable IPC
docker run -d \
    --name $CONTAINER_NAME \
    -p $CORE_PORT:$CORE_PORT/udp \
    --ipc="shareable" \
    $IMAGE_NAME > /dev/null

if [ $? -ne 0 ]; then
    echo "❌ [ERROR] Failed to start Docker container. Ensure the image '$IMAGE_NAME' is built."
    exit 1
fi

# Allow the Alpine-based Assembly process to initialize network sockets
sleep 1

echo "🚀 Container $CONTAINER_NAME is active. Initiating sequence..."
echo "------------------------------------------------"

# --- ATTACK VECTORS (Host -> Container) ---

# [A] Truncated Packet Attack
# Sending incomplete data (40 bytes) to test boundary checks in recvfrom loop
echo "[A] Sending truncated packet (40 bytes) to UDP/$CORE_PORT..."
head -c 40 /dev/urandom | nc -u -w 1 -q 0 $CORE_ADDR $CORE_PORT

# [B] Invalid Magic Header Attack
# Sending 80 bytes with a forged header to test protocol validation
echo "[B] Sending 80 bytes with INVALID magic header..."
printf "EVIL_HDR\x00\x00\x00\x00\x00\x00\x00\x00" | head -c 80 | nc -u -w 1 -q 0 $CORE_ADDR $CORE_PORT

# [C] Out-of-Bounds (OOB) Block ID Attack
# Sending ID 99 (Hex 0x63) which exceeds the 0-63 range limit
echo "[C] Sending 80 bytes with OOB Block ID (99)..."
printf "CONCRETE\x63\x00\x00\x00\x00\x00\x00\x00" | head -c 80 | nc -u -w 1 -q 0 $CORE_ADDR $CORE_PORT

echo "------------------------------------------------"
echo "🔍 Analyzing Container Integrity..."

# 3. VERIFY CORE SURVIVABILITY
# If the x86_64 Core crashes (Segfault/Bus Error), the container will stop or report an error code
STATUS=$(docker inspect -f '{{.State.Running}}' $CONTAINER_NAME 2>/dev/null)

if [ "$STATUS" = "true" ]; then
    echo "✅ [PASS] Core survived all malformed inputs (Protocol-level rejection)."

    # Secondary check: Scan logs for any hidden Segfaults or illegal instructions
    if docker logs $CONTAINER_NAME 2>&1 | grep -iq "segmentation fault"; then
        echo "❌ [FAIL] Hidden Segmentation Fault detected in container logs!"
        RET=1
    else
        RET=0
    fi
else
    echo "❌ [FAIL] Core CRASHED! Container is no longer running."
    echo "--- Last 5 logs from $CONTAINER_NAME ---"
    docker logs $CONTAINER_NAME | tail -n 5
    RET=1
fi

# 4. CLEANUP
echo "🧹 Removing security-fuzz container..."
docker rm -f $CONTAINER_NAME > /dev/null
echo "🛡️  Security Audit Finished."
exit $RET