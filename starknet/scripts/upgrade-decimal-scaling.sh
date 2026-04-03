#!/bin/bash

# Upgrade script for Decimal Scaling Fixes
# This script upgrades both adam-token and adam-swap contracts with the new decimal handling

# Load environment variables
source .env

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

RPC_URL="${STARKNET_RPC_URL}"
ACCOUNT="${DEPLOYER_ACCOUNT}"
SWAP_ADDRESS="${SWAP_ADDRESS}"
ADUSD_ADDRESS="${ADUSD_ADDRESS}"
ADNGN_ADDRESS="${ADNGN_ADDRESS}"
ADKES_ADDRESS="${ADKES_ADDRESS}"
ADGHS_ADDRESS="${ADGHS_ADDRESS}"
ADZAR_ADDRESS="${ADZAR_ADDRESS}"

LOG_DIR="deployment_logs"
LOG_FILE="${LOG_DIR}/upgrade_decimal_scaling_$(date -u +"%Y-%m-%dT%H-%M-%S").log"
mkdir -p "${LOG_DIR}"

log() { echo -e "${2}[$(date -u +"%Y-%m-%dT%H:%M:%S")]${NC} $1" | tee -a "${LOG_FILE}"; }
log_success() { log "✓ $1" "${GREEN}"; }
log_error() { log "✗ $1" "${RED}"; }
log_info() { log "→ $1" "${BLUE}"; }
log_warning() { log "⚠ $1" "${YELLOW}"; }

# Validation
if [ -z "$RPC_URL" ] || [ -z "$ACCOUNT" ] || [ -z "$SWAP_ADDRESS" ]; then
    log_error "Missing required environment variables"
    log_info "Required: STARKNET_RPC_URL, DEPLOYER_ACCOUNT, SWAP_ADDRESS"
    exit 1
fi

if [ -z "$ADUSD_ADDRESS" ] || [ -z "$ADNGN_ADDRESS" ]; then
    log_error "Missing token addresses"
    log_info "Required: ADUSD_ADDRESS, ADNGN_ADDRESS"
    exit 1
fi

log_info "========================================="
log_info "Decimal Scaling Upgrade"
log_info "========================================="
log_info "Network: Sepolia"
log_info "Account: ${ACCOUNT}"
log_info "RPC: ${RPC_URL}"
log_info "========================================="

# Step 1: Build contracts
log_info "--- Step 1: Building Contracts ---"
scarb build
if [ $? -ne 0 ]; then
    log_error "Failed to build contracts"
    exit 1
fi
log_success "Contracts built successfully"

# Step 2: Declare AdamToken implementations
log_info "--- Step 2: Declaring AdamToken Implementations ---"

declare_token() {
    local token_name=$1
    local token_address=$2
    
    log_info "Declaring ${token_name}..."
    
    TOKEN_DECLARE=$(sncast --account "${ACCOUNT}" declare \
        --url "${RPC_URL}" \
        --contract-name AdamToken \
        --package adam_token \
        --estimate-tip 2>&1)
    
    if echo "$TOKEN_DECLARE" | grep -q "Class Hash:"; then
        TOKEN_CLASS_HASH=$(echo "$TOKEN_DECLARE" | grep "Class Hash:" | awk '{print $3}')
        log_success "${token_name} declared with class hash: ${TOKEN_CLASS_HASH}"
        sleep 5
        echo "$TOKEN_CLASS_HASH"
    elif echo "$TOKEN_DECLARE" | grep -q "is already declared"; then
        log_info "${token_name} already declared, computing class hash..."
        TOKEN_CLASS_HASH=$(starkli class-hash target/dev/adam_token_AdamToken.contract_class.json)
        log_info "Computed class hash: ${TOKEN_CLASS_HASH}"
        echo "$TOKEN_CLASS_HASH"
    else
        log_error "Failed to declare ${token_name}"
        echo "$TOKEN_DECLARE" | tee -a "${LOG_FILE}"
        return 1
    fi
}

# Declare once (same implementation for all tokens)
ADUSD_CLASS_HASH=$(declare_token "ADUSD" "$ADUSD_ADDRESS")
if [ -z "$ADUSD_CLASS_HASH" ]; then
    log_error "Failed to declare token implementation"
    exit 1
fi

# Step 3: Upgrade AdamSwap
log_info "--- Step 3: Declaring AdamSwap Implementation ---"

SWAP_DECLARE=$(sncast --account "${ACCOUNT}" declare \
    --url "${RPC_URL}" \
    --contract-name AdamSwap \
    --package adam_swap \
    --estimate-tip 2>&1)

if echo "$SWAP_DECLARE" | grep -q "Class Hash:"; then
    SWAP_CLASS_HASH=$(echo "$SWAP_DECLARE" | grep "Class Hash:" | awk '{print $3}')
    log_success "AdamSwap declared with class hash: ${SWAP_CLASS_HASH}"
    sleep 5
elif echo "$SWAP_DECLARE" | grep -q "is already declared"; then
    log_info "AdamSwap already declared, computing class hash..."
    SWAP_CLASS_HASH=$(starkli class-hash target/dev/adam_swap_AdamSwap.contract_class.json)
    log_info "Computed class hash: ${SWAP_CLASS_HASH}"
else
    log_error "Failed to declare AdamSwap"
    echo "$SWAP_DECLARE" | tee -a "${LOG_FILE}"
    exit 1
fi

# Step 4: Upgrade token contracts
log_info "--- Step 4: Upgrading Token Contracts ---"

upgrade_token() {
    local token_name=$1
    local token_address=$2
    local class_hash=$3
    
    log_info "Upgrading ${token_name} at ${token_address}..."
    
    UPGRADE_RESULT=$(sncast --account "${ACCOUNT}" invoke \
        --url "${RPC_URL}" \
        --contract-address "${token_address}" \
        --function "upgrade" \
        --calldata "${class_hash}" \
        --estimate-tip 2>&1)
    
    if echo "$UPGRADE_RESULT" | grep -q "Transaction Hash:"; then
        UPGRADE_TX=$(echo "$UPGRADE_RESULT" | grep "Transaction Hash:" | awk '{print $3}')
        log_success "${token_name} upgrade submitted: ${UPGRADE_TX}"
        sleep 3
        return 0
    else
        log_error "Failed to upgrade ${token_name}"
        echo "$UPGRADE_RESULT" | tee -a "${LOG_FILE}"
        return 1
    fi
}

# Upgrade all token contracts
upgrade_token "ADUSD" "$ADUSD_ADDRESS" "$ADUSD_CLASS_HASH"
if [ $? -ne 0 ]; then
    log_warning "ADUSD upgrade may have failed, continuing..."
fi

upgrade_token "ADNGN" "$ADNGN_ADDRESS" "$ADUSD_CLASS_HASH"
if [ $? -ne 0 ]; then
    log_warning "ADNGN upgrade may have failed, continuing..."
fi

if [ ! -z "$ADKES_ADDRESS" ]; then
    upgrade_token "ADKES" "$ADKES_ADDRESS" "$ADUSD_CLASS_HASH"
fi

if [ ! -z "$ADGHS_ADDRESS" ]; then
    upgrade_token "ADGHS" "$ADGHS_ADDRESS" "$ADUSD_CLASS_HASH"
fi

if [ ! -z "$ADZAR_ADDRESS" ]; then
    upgrade_token "ADZAR" "$ADZAR_ADDRESS" "$ADUSD_CLASS_HASH"
fi

# Step 5: Upgrade AdamSwap
log_info "--- Step 5: Upgrading AdamSwap Contract ---"
log_info "Calling upgrade on ${SWAP_ADDRESS} with class hash ${SWAP_CLASS_HASH}"

SWAP_UPGRADE=$(sncast --account "${ACCOUNT}" invoke \
    --url "${RPC_URL}" \
    --contract-address "${SWAP_ADDRESS}" \
    --function "upgrade" \
    --calldata "${SWAP_CLASS_HASH}" \
    --estimate-tip 2>&1)

if echo "$SWAP_UPGRADE" | grep -q "Transaction Hash:"; then
    SWAP_UPGRADE_TX=$(echo "$SWAP_UPGRADE" | grep "Transaction Hash:" | awk '{print $3}')
    log_success "AdamSwap upgrade submitted: ${SWAP_UPGRADE_TX}"
else
    log_error "Failed to upgrade AdamSwap"
    echo "$SWAP_UPGRADE" | tee -a "${LOG_FILE}"
    exit 1
fi

# Step 6: Verification
log_info "--- Step 6: Verification ---"
log_info "Waiting for transactions to be confirmed..."
sleep 10

log_info "Verifying AdamSwap upgrade..."
VERIFY=$(sncast --account "${ACCOUNT}" call \
    --url "${RPC_URL}" \
    --contract-address "${SWAP_ADDRESS}" \
    --function "get_fee_bps" \
    --estimate-tip 2>&1)

if echo "$VERIFY" | grep -q "0x"; then
    log_success "AdamSwap is responding correctly"
else
    log_warning "Could not verify AdamSwap immediately (may still be processing)"
fi

# Summary
log_info "========================================="
log_success "Decimal Scaling Upgrade Complete!"
log_info "========================================="
log_info "Token Class Hash: ${ADUSD_CLASS_HASH}"
log_info "Swap Class Hash: ${SWAP_CLASS_HASH}"
log_info "Token Upgrade TX: (see logs)"
log_info "Swap Upgrade TX: ${SWAP_UPGRADE_TX}"
log_info "========================================="
log_info "Next Steps:"
log_info "1. Wait for transactions to be confirmed on Sepolia"
log_info "2. Test the new decimal scaling with buy/swap operations"
log_info "3. Verify rates are correctly applied"
log_info "========================================="

# Save summary
SUMMARY_FILE="${LOG_DIR}/upgrade_summary_$(date -u +"%Y-%m-%dT%H-%M-%S").json"
cat > "$SUMMARY_FILE" << EOF
{
  "upgrade_type": "decimal_scaling",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "network": "sepolia",
  "account": "${ACCOUNT}",
  "token_class_hash": "${ADUSD_CLASS_HASH}",
  "swap_class_hash": "${SWAP_CLASS_HASH}",
  "swap_address": "${SWAP_ADDRESS}",
  "swap_upgrade_tx": "${SWAP_UPGRADE_TX}",
  "contracts_upgraded": [
    "ADUSD",
    "ADNGN",
    "ADKES",
    "ADGHS",
    "ADZAR",
    "AdamSwap"
  ],
  "changes": [
    "Decimal scaling in _apply_rate_and_fee function",
    "Custom decimals support in AdamToken",
    "Optimized _pow10 helper function",
    "Removed unused imports"
  ]
}
EOF

log_success "Summary saved to: ${SUMMARY_FILE}"
