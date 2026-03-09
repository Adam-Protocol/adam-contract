#!/bin/bash

# Load environment variables
source .env

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RPC_URL="${STARKNET_RPC_URL}"
ACCOUNT="${DEPLOYER_ACCOUNT}"
SWAP_ADDRESS="${SWAP_ADDRESS}"
ADKES_ADDRESS="${ADKES_ADDRESS}"
ADGHS_ADDRESS="${ADGHS_ADDRESS}"
ADZAR_ADDRESS="${ADZAR_ADDRESS}"

# Log file
LOG_DIR="deployment_logs"
LOG_FILE="${LOG_DIR}/upgrade_and_set_tokens_$(date -u +"%Y-%m-%dT%H-%M-%S").log"
mkdir -p "${LOG_DIR}"

# Logging function
log() {
    echo -e "${2}[$(date -u +"%Y-%m-%dT%H:%M:%S")]${NC} $1" | tee -a "${LOG_FILE}"
}

log_success() {
    log "✓ $1" "${GREEN}"
}

log_error() {
    log "✗ $1" "${RED}"
}

log_info() {
    log "→ $1" "${BLUE}"
}

log_warning() {
    log "! $1" "${YELLOW}"
}

# Check required environment variables
if [ -z "$RPC_URL" ] || [ -z "$ACCOUNT" ] || [ -z "$SWAP_ADDRESS" ]; then
    log_error "Missing required environment variables"
    log_info "Required: STARKNET_RPC_URL, DEPLOYER_ACCOUNT, SWAP_ADDRESS"
    exit 1
fi

if [ -z "$ADKES_ADDRESS" ] || [ -z "$ADGHS_ADDRESS" ] || [ -z "$ADZAR_ADDRESS" ]; then
    log_error "Missing token addresses"
    log_info "Required: ADKES_ADDRESS, ADGHS_ADDRESS, ADZAR_ADDRESS"
    exit 1
fi

log_info "========================================="
log_info "Adam Swap Contract Upgrade & Token Setup"
log_info "========================================="
log_info "Network: ${RPC_URL}"
log_info "Account: ${ACCOUNT}"
log_info "Swap Address: ${SWAP_ADDRESS}"
log_info "ADKES Address: ${ADKES_ADDRESS}"
log_info "ADGHS Address: ${ADGHS_ADDRESS}"
log_info "ADZAR Address: ${ADZAR_ADDRESS}"
log_info "========================================="

# Step 1: Build the contract
log_info ""
log_info "--- Step 1: Building Contract ---"
scarb build
if [ $? -ne 0 ]; then
    log_error "Failed to build contract"
    exit 1
fi
log_success "Contract built successfully"

# Step 2: Declare the new AdamSwap implementation
log_info ""
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
    log_warning "AdamSwap already declared, computing class hash..."
    NEW_CLASS_HASH=$(starkli class-hash target/dev/adam_swap_AdamSwap.contract_class.json)
    log_info "Computed class hash: ${NEW_CLASS_HASH}"
else
    log_error "Failed to declare AdamSwap"
    echo "$SWAP_DECLARE" | tee -a "${LOG_FILE}"
    exit 1
fi

# Step 3: Upgrade the contract
log_info ""
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

# Step 4: Set ADKES address
log_info ""
log_info "--- Step 4: Setting ADKES Address ---"
log_info "Setting ADKES address to: ${ADKES_ADDRESS}"

ADKES_RESULT=$(sncast --account "${ACCOUNT}" invoke \
    --url "${RPC_URL}" \
    --contract-address "${SWAP_ADDRESS}" \
    --function "set_adkes_address" \
    --calldata "${ADKES_ADDRESS}" 2>&1)

if echo "$ADKES_RESULT" | grep -q "Transaction Hash:"; then
    ADKES_TX_HASH=$(echo "$ADKES_RESULT" | grep "Transaction Hash:" | awk '{print $3}')
    log_success "ADKES address set successfully: ${ADKES_TX_HASH}"
    sleep 3
else
    log_error "Failed to set ADKES address"
    echo "$ADKES_RESULT" | tee -a "${LOG_FILE}"
    exit 1
fi

# Step 5: Set ADGHS address
log_info ""
log_info "--- Step 5: Setting ADGHS Address ---"
log_info "Setting ADGHS address to: ${ADGHS_ADDRESS}"

ADGHS_RESULT=$(sncast --account "${ACCOUNT}" invoke \
    --url "${RPC_URL}" \
    --contract-address "${SWAP_ADDRESS}" \
    --function "set_adghs_address" \
    --calldata "${ADGHS_ADDRESS}" 2>&1)

if echo "$ADGHS_RESULT" | grep -q "Transaction Hash:"; then
    ADGHS_TX_HASH=$(echo "$ADGHS_RESULT" | grep "Transaction Hash:" | awk '{print $3}')
    log_success "ADGHS address set successfully: ${ADGHS_TX_HASH}"
    sleep 3
else
    log_error "Failed to set ADGHS address"
    echo "$ADGHS_RESULT" | tee -a "${LOG_FILE}"
    exit 1
fi

# Step 6: Set ADZAR address
log_info ""
log_info "--- Step 6: Setting ADZAR Address ---"
log_info "Setting ADZAR address to: ${ADZAR_ADDRESS}"

ADZAR_RESULT=$(sncast --account "${ACCOUNT}" invoke \
    --url "${RPC_URL}" \
    --contract-address "${SWAP_ADDRESS}" \
    --function "set_adzar_address" \
    --calldata "${ADZAR_ADDRESS}" 2>&1)

if echo "$ADZAR_RESULT" | grep -q "Transaction Hash:"; then
    ADZAR_TX_HASH=$(echo "$ADZAR_RESULT" | grep "Transaction Hash:" | awk '{print $3}')
    log_success "ADZAR address set successfully: ${ADZAR_TX_HASH}"
    sleep 3
else
    log_error "Failed to set ADZAR address"
    echo "$ADZAR_RESULT" | tee -a "${LOG_FILE}"
    exit 1
fi

log_info ""
log_info "========================================="
log_success "Upgrade & Token Setup Complete!"
log_info "========================================="
log_info "New Class Hash: ${NEW_CLASS_HASH}"
log_info "Upgrade TX: ${UPGRADE_TX_HASH}"
log_info "ADKES TX: ${ADKES_TX_HASH}"
log_info "ADGHS TX: ${ADGHS_TX_HASH}"
log_info "ADZAR TX: ${ADZAR_TX_HASH}"
log_info "========================================="

# Save upgrade summary
SUMMARY_FILE="${LOG_DIR}/upgrade_and_tokens_summary_$(date -u +"%Y-%m-%dT%H-%M-%S").json"
cat > "${SUMMARY_FILE}" <<EOF
{
  "network": "sepolia",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%S")Z",
  "swapAddress": "${SWAP_ADDRESS}",
  "newClassHash": "${NEW_CLASS_HASH}",
  "upgradeTransactionHash": "${UPGRADE_TX_HASH}",
  "tokenAddresses": {
    "adkes": "${ADKES_ADDRESS}",
    "adghs": "${ADGHS_ADDRESS}",
    "adzar": "${ADZAR_ADDRESS}"
  },
  "transactionHashes": {
    "adkes": "${ADKES_TX_HASH}",
    "adghs": "${ADGHS_TX_HASH}",
    "adzar": "${ADZAR_TX_HASH}"
  }
}
EOF

log_success "Summary saved to: ${SUMMARY_FILE}"
log_info "Log file: ${LOG_FILE}"

log_info ""
log_info "========================================="
log_info "Next Steps:"
log_info "========================================="
log_info "1. Set exchange rates for ADKES, ADGHS, and ADZAR"
log_info "2. Grant MINTER_ROLE and BURNER_ROLE to swap contract for new tokens"
log_info "3. Update backend and frontend with new token addresses"
log_info "========================================="
