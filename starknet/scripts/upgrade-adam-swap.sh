#!/bin/bash

# Load environment variables
source .env

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

RPC_URL="${STARKNET_RPC_URL}"
ACCOUNT="${DEPLOYER_ACCOUNT}"
SWAP_ADDRESS="${SWAP_ADDRESS}"

LOG_DIR="deployment_logs"
LOG_FILE="${LOG_DIR}/upgrade_adam_swap_$(date -u +"%Y-%m-%dT%H-%M-%S").log"
mkdir -p "${LOG_DIR}"

log() { echo -e "${2}[$(date -u +"%Y-%m-%dT%H:%M:%S")]${NC} $1" | tee -a "${LOG_FILE}"; }
log_success() { log "✓ $1" "${GREEN}"; }
log_error() { log "✗ $1" "${RED}"; }
log_info() { log "→ $1" "${BLUE}"; }

if [ -z "$RPC_URL" ] || [ -z "$ACCOUNT" ] || [ -z "$SWAP_ADDRESS" ]; then
    log_error "Missing required environment variables"
    log_info "Required: STARKNET_RPC_URL, DEPLOYER_ACCOUNT, SWAP_ADDRESS"
    exit 1
fi

log_info "========================================="
log_info "Adam Swap Contract Upgrade"
log_info "========================================="
log_info "Network: ${RPC_URL}"
log_info "Account: ${ACCOUNT}"
log_info "Swap Address: ${SWAP_ADDRESS}"
log_info "========================================="

# Step 1: Build the contract
log_info "--- Step 1: Building Contract ---"
scarb build
if [ $? -ne 0 ]; then
    log_error "Failed to build contract"
    exit 1
fi
log_success "Contract built successfully"

# Step 2: Declare the new AdamSwap implementation
log_info "--- Step 2: Declaring New AdamSwap Implementation ---"
SWAP_DECLARE=$(sncast --account "${ACCOUNT}" declare \
    --url "${RPC_URL}" \
    --contract-name AdamSwap \
    --package adam_swap 2>&1)

if echo "$SWAP_DECLARE" | grep -q "Class Hash:"; then
    NEW_CLASS_HASH=$(echo "$SWAP_DECLARE" | grep "Class Hash:" | awk '{print $3}')
    log_success "AdamSwap declared with new class hash: ${NEW_CLASS_HASH}"
    log_info "Waiting for declaration to be confirmed..."
    sleep 10
elif echo "$SWAP_DECLARE" | grep -q "is already declared"; then
    log_info "AdamSwap already declared, computing class hash..."
    NEW_CLASS_HASH=$(starkli class-hash target/dev/adam_swap_AdamSwap.contract_class.json)
    log_info "Computed class hash: ${NEW_CLASS_HASH}"
else
    log_error "Failed to declare AdamSwap"
    echo "$SWAP_DECLARE" | tee -a "${LOG_FILE}"
    exit 1
fi

# Step 3: Upgrade the contract
log_info "--- Step 3: Upgrading Contract ---"
log_info "Calling upgrade function on ${SWAP_ADDRESS} with new class hash ${NEW_CLASS_HASH}"

UPGRADE_RESULT=$(sncast --account "${ACCOUNT}" invoke \
    --url "${RPC_URL}" \
    --contract-address "${SWAP_ADDRESS}" \
    --function "upgrade" \
    --calldata "${NEW_CLASS_HASH}" 2>&1)

if echo "$UPGRADE_RESULT" | grep -q "Transaction Hash:"; then
    UPGRADE_TX_HASH=$(echo "$UPGRADE_RESULT" | grep "Transaction Hash:" | awk '{print $3}')
    log_success "Upgrade transaction submitted: ${UPGRADE_TX_HASH}"
    log_info "Waiting for transaction confirmation..."
    sleep 5
else
    log_error "Failed to upgrade contract"
    echo "$UPGRADE_RESULT" | tee -a "${LOG_FILE}"
    exit 1
fi

log_info "========================================="
log_success "Adam Swap Upgrade Complete!"
log_info "New Class Hash: ${NEW_CLASS_HASH}"
log_info "Upgrade TX: ${UPGRADE_TX_HASH}"
log_info "========================================="
