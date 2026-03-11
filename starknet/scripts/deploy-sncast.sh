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
OWNER="${DEPLOYER_ADDRESS}"
USDC="${USDC_ADDRESS}"
DEFAULT_FEE_BPS="${DEFAULT_FEE_BPS:-30}"
MAX_FEE_BPS="${MAX_FEE_BPS:-1000}"

# Log file
LOG_DIR="deployment_logs"
LOG_FILE="${LOG_DIR}/deploy_$(date -u +"%Y-%m-%dT%H-%M-%S").log"
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

# Function to convert string to ByteArray format for sncast
# ByteArray format: pending_word_len word1 word2... pending_word pending_word_len
string_to_bytearray() {
    local str="$1"
    local hex=$(echo -n "$str" | xxd -p | tr -d '\n')
    local len=${#str}
    echo "0 0x${hex} ${len}"
}

# Check required environment variables
if [ -z "$RPC_URL" ] || [ -z "$ACCOUNT" ] || [ -z "$OWNER" ] || [ -z "$USDC" ]; then
    log_error "Missing required environment variables"
    log_info "Required: STARKNET_RPC_URL, DEPLOYER_ACCOUNT, DEPLOYER_ADDRESS, USDC_ADDRESS"
    exit 1
fi

log_info "========================================="
log_info "Adam Protocol Deployment"
log_info "========================================="
log_info "Network: ${RPC_URL}"
log_info "Account: ${ACCOUNT}"
log_info "Owner: ${OWNER}"
log_info "USDC: ${USDC}"
log_info "========================================="

# Step 1: Declare AdamToken
log_info ""
log_info "--- Step 1: Declaring AdamToken ---"
ADAM_TOKEN_DECLARE=$(sncast --account "${ACCOUNT}" declare \
    --url "${RPC_URL}" \
    --contract-name AdamToken \
    --package adam_token 2>&1)

if echo "$ADAM_TOKEN_DECLARE" | grep -q "Class Hash:"; then
    ADAM_TOKEN_CLASS_HASH=$(echo "$ADAM_TOKEN_DECLARE" | grep "Class Hash:" | awk '{print $3}')
    log_success "AdamToken declared with class hash: ${ADAM_TOKEN_CLASS_HASH}"
elif echo "$ADAM_TOKEN_DECLARE" | grep -q "is already declared"; then
    # Extract class hash from error message or compute it
    log_warning "AdamToken already declared, computing class hash..."
    ADAM_TOKEN_CLASS_HASH=$(starkli class-hash target/dev/adam_token_AdamToken.contract_class.json)
    log_info "Computed class hash: ${ADAM_TOKEN_CLASS_HASH}"
else
    log_error "Failed to declare AdamToken"
    echo "$ADAM_TOKEN_DECLARE" | tee -a "${LOG_FILE}"
    exit 1
fi

# Step 2: Deploy ADUSD Token
log_info ""
log_info "--- Step 2: Deploying ADUSD Token ---"
ADUSD_NAME_BA=$(string_to_bytearray "${ADUSD_NAME:-Adam USD}")
ADUSD_SYMBOL_BA=$(string_to_bytearray "${ADUSD_SYMBOL:-ADUSD}")

log_info "Deploying ADUSD with:"
log_info "  Name: ${ADUSD_NAME:-Adam USD}"
log_info "  Symbol: ${ADUSD_SYMBOL:-ADUSD}"
log_info "  Owner: ${OWNER}"

ADUSD_DEPLOY=$(sncast --account "${ACCOUNT}" deploy \
    --url "${RPC_URL}" \
    --class-hash "${ADAM_TOKEN_CLASS_HASH}" \
    --constructor-calldata ${ADUSD_NAME_BA} ${ADUSD_SYMBOL_BA} "${OWNER}" 2>&1)

if echo "$ADUSD_DEPLOY" | grep -q "Contract Address:"; then
    ADUSD_ADDRESS=$(echo "$ADUSD_DEPLOY" | grep "Contract Address:" | awk '{print $3}')
    log_success "ADUSD deployed at: ${ADUSD_ADDRESS}"
else
    log_error "Failed to deploy ADUSD"
    echo "$ADUSD_DEPLOY" | tee -a "${LOG_FILE}"
    exit 1
fi

# Step 3: Deploy ADNGN Token
log_info ""
log_info "--- Step 3: Deploying ADNGN Token ---"
ADNGN_NAME_BA=$(string_to_bytearray "${ADNGN_NAME:-Adam NGN}")
ADNGN_SYMBOL_BA=$(string_to_bytearray "${ADNGN_SYMBOL:-ADNGN}")

log_info "Deploying ADNGN with:"
log_info "  Name: ${ADNGN_NAME:-Adam NGN}"
log_info "  Symbol: ${ADNGN_SYMBOL:-ADNGN}"
log_info "  Owner: ${OWNER}"

ADNGN_DEPLOY=$(sncast --account "${ACCOUNT}" deploy \
    --url "${RPC_URL}" \
    --class-hash "${ADAM_TOKEN_CLASS_HASH}" \
    --constructor-calldata ${ADNGN_NAME_BA} ${ADNGN_SYMBOL_BA} "${OWNER}" 2>&1)

if echo "$ADNGN_DEPLOY" | grep -q "Contract Address:"; then
    ADNGN_ADDRESS=$(echo "$ADNGN_DEPLOY" | grep "Contract Address:" | awk '{print $3}')
    log_success "ADNGN deployed at: ${ADNGN_ADDRESS}"
else
    log_error "Failed to deploy ADNGN"
    echo "$ADNGN_DEPLOY" | tee -a "${LOG_FILE}"
    exit 1
fi

# Step 4: Declare AdamPool
log_info ""
log_info "--- Step 4: Declaring AdamPool ---"
ADAM_POOL_DECLARE=$(sncast --account "${ACCOUNT}" declare \
    --url "${RPC_URL}" \
    --contract-name AdamPool \
    --package adam_pool 2>&1)

if echo "$ADAM_POOL_DECLARE" | grep -q "Class Hash:"; then
    ADAM_POOL_CLASS_HASH=$(echo "$ADAM_POOL_DECLARE" | grep "Class Hash:" | awk '{print $3}')
    log_success "AdamPool declared with class hash: ${ADAM_POOL_CLASS_HASH}"
elif echo "$ADAM_POOL_DECLARE" | grep -q "is already declared"; then
    log_warning "AdamPool already declared, computing class hash..."
    ADAM_POOL_CLASS_HASH=$(starkli class-hash target/dev/adam_pool_AdamPool.contract_class.json)
    log_info "Computed class hash: ${ADAM_POOL_CLASS_HASH}"
else
    log_error "Failed to declare AdamPool"
    echo "$ADAM_POOL_DECLARE" | tee -a "${LOG_FILE}"
    exit 1
fi

# Step 5: Deploy AdamPool
log_info ""
log_info "--- Step 5: Deploying AdamPool ---"
log_info "Deploying AdamPool with owner: ${OWNER}"

POOL_DEPLOY=$(sncast --account "${ACCOUNT}" deploy \
    --url "${RPC_URL}" \
    --class-hash "${ADAM_POOL_CLASS_HASH}" \
    --constructor-calldata "${OWNER}" 2>&1)

if echo "$POOL_DEPLOY" | grep -q "Contract Address:"; then
    POOL_ADDRESS=$(echo "$POOL_DEPLOY" | grep "Contract Address:" | awk '{print $3}')
    log_success "AdamPool deployed at: ${POOL_ADDRESS}"
else
    log_error "Failed to deploy AdamPool"
    echo "$POOL_DEPLOY" | tee -a "${LOG_FILE}"
    exit 1
fi

# Step 6: Declare AdamSwap
log_info ""
log_info "--- Step 6: Declaring AdamSwap ---"
ADAM_SWAP_DECLARE=$(sncast --account "${ACCOUNT}" declare \
    --url "${RPC_URL}" \
    --contract-name AdamSwap \
    --package adam_swap 2>&1)

if echo "$ADAM_SWAP_DECLARE" | grep -q "Class Hash:"; then
    ADAM_SWAP_CLASS_HASH=$(echo "$ADAM_SWAP_DECLARE" | grep "Class Hash:" | awk '{print $3}')
    log_success "AdamSwap declared with class hash: ${ADAM_SWAP_CLASS_HASH}"
elif echo "$ADAM_SWAP_DECLARE" | grep -q "is already declared"; then
    log_warning "AdamSwap already declared, computing class hash..."
    ADAM_SWAP_CLASS_HASH=$(starkli class-hash target/dev/adam_swap_AdamSwap.contract_class.json)
    log_info "Computed class hash: ${ADAM_SWAP_CLASS_HASH}"
else
    log_error "Failed to declare AdamSwap"
    echo "$ADAM_SWAP_DECLARE" | tee -a "${LOG_FILE}"
    exit 1
fi

# Step 7: Deploy AdamSwap
log_info ""
log_info "--- Step 7: Deploying AdamSwap ---"
log_info "Deploying AdamSwap with:"
log_info "  Owner: ${OWNER}"
log_info "  Treasury: ${OWNER}"
log_info "  USDC: ${USDC}"
log_info "  ADUSD: ${ADUSD_ADDRESS}"
log_info "  ADNGN: ${ADNGN_ADDRESS}"
log_info "  Pool: ${POOL_ADDRESS}"
log_info "  Fee BPS: ${DEFAULT_FEE_BPS}"

SWAP_DEPLOY=$(sncast --account "${ACCOUNT}" deploy \
    --url "${RPC_URL}" \
    --class-hash "${ADAM_SWAP_CLASS_HASH}" \
    --constructor-calldata \
        "${OWNER}" \
        "${OWNER}" \
        "${USDC}" \
        "${ADUSD_ADDRESS}" \
        "${ADNGN_ADDRESS}" \
        "${POOL_ADDRESS}" \
        "${DEFAULT_FEE_BPS}" 2>&1)

if echo "$SWAP_DEPLOY" | grep -q "Contract Address:"; then
    SWAP_ADDRESS=$(echo "$SWAP_DEPLOY" | grep "Contract Address:" | awk '{print $3}')
    log_success "AdamSwap deployed at: ${SWAP_ADDRESS}"
else
    log_error "Failed to deploy AdamSwap"
    echo "$SWAP_DEPLOY" | tee -a "${LOG_FILE}"
    exit 1
fi

# Save deployment summary
log_info ""
log_info "========================================="
log_info "Deployment Summary"
log_info "========================================="
log_success "All contracts deployed successfully!"
log_info ""
log_info "Deployed Contracts:"
log_info "  ADUSD Token: ${ADUSD_ADDRESS}"
log_info "  ADNGN Token: ${ADNGN_ADDRESS}"
log_info "  Adam Pool:   ${POOL_ADDRESS}"
log_info "  Adam Swap:   ${SWAP_ADDRESS}"
log_info "  USDC:        ${USDC}"
log_info "========================================="

# Save to JSON file
SUMMARY_FILE="${LOG_DIR}/deployment_summary_sepolia.json"
cat > "${SUMMARY_FILE}" <<EOF
{
  "network": "sepolia",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%S")Z",
  "contracts": {
    "adusd": "${ADUSD_ADDRESS}",
    "adngn": "${ADNGN_ADDRESS}",
    "pool": "${POOL_ADDRESS}",
    "swap": "${SWAP_ADDRESS}",
    "usdc": "${USDC}"
  },
  "classHashes": {
    "adamToken": "${ADAM_TOKEN_CLASS_HASH}",
    "adamPool": "${ADAM_POOL_CLASS_HASH}",
    "adamSwap": "${ADAM_SWAP_CLASS_HASH}"
  }
}
EOF

log_success "Deployment summary saved to: ${SUMMARY_FILE}"
log_info "Log file: ${LOG_FILE}"
