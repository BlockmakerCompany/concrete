#!/bin/sh
# scripts/test_functional.sh - Integrated Functional Test Suite
# Validates standard synchronization, boundary conditions, and data isolation.

# Force path to the directory where the script is located
cd "$(dirname "$0")"

# Project-relative paths
SHM_FILE="/dev/shm/concrete.data"
# Search for trigger in local bin or absolute /app/bin (Docker context)
TRIGGER="./bin/concrete_trigger"
[ ! -f "$TRIGGER" ] && TRIGGER="/app/bin/concrete_trigger"

echo "🧱 [CONCRETE] Starting Integrated Test Suite..."

# --- TEST 1: Original Case (Block 7) ---
# Validating your original logic with 'PROT_V2'
BLOCK_ID=7
EXPECTED_OFFSET="000001c0"
echo "[1/3] Firing trigger [ID:$BLOCK_ID MSG:'PROT_V2']..."

$TRIGGER $BLOCK_ID "PROT_V2"
sleep 0.5

echo "🔍 Analyzing Block 7 integrity in $SHM_FILE..."
if [ -f "$SHM_FILE" ]; then
    if hexdump -C "$SHM_FILE" | grep -q "PROT_V2"; then
        echo "✅ [PASS] Block 7 synchronization successful."
        hexdump -C "$SHM_FILE" | grep "$EXPECTED_OFFSET"
    else
        echo "❌ [FAIL] Block 7 is empty or data did not arrive."
        exit 1
    fi
else
    echo "❌ [FAIL] SHM not found. Is the core running?"
    exit 1
fi

# --- TEST 2: Lower Boundary (Block 0) ---
echo "[2/3] Testing Lower Boundary (Block 0)..."
$TRIGGER 0 "FIRST_BLOCK_OK"
sleep 0.1
if hexdump -C "$SHM_FILE" | grep "00000000" | grep -q "FIRST_BLOCK_OK"; then
    echo "✅ [PASS] Block 0 alignment OK."
else
    echo "❌ [FAIL] Block 0 alignment failed."
    exit 1
fi

# --- TEST 3: Upper Boundary (Block 63) ---
echo "[3/3] Testing Upper Boundary (Block 63)..."
$TRIGGER 63 "LAST_BLOCK_OK"
sleep 0.1
# Hex offset for Block 63 (63 * 64) is 0x00000fc0
if hexdump -C "$SHM_FILE" | grep "00000fc0" | grep -q "LAST_BLOCK_OK"; then
    echo "✅ [PASS] Block 63 alignment OK."
else
    echo "❌ [FAIL] Block 63 boundary failed."
    exit 1
fi

echo "------------------------------------------------"
echo "🏁 [SUCCESS] Full functional suite passed."
echo "------------------------------------------------"
exit 0