#!/bin/bash

# Upgrade script for token contracts with decimal scaling fixes
# This script upgrades all token contracts (ADUSD, ADNGN, ADKES, ADGHS, ADZAR)

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
ADUSD_ADDRESS="${ADUSD_ADDRESS}"
ADNGN_ADDRESS="${ADNGN_ADDRESS}"
ADKES_ADDRESS="${ADKES_ADDRESS}"
ADGHS_ADDRESS="${ADGHS_ADDRESS}"
ADZAR_ADDRESS="${ADZAR_ADDRESS}"

LOG_DIR="deployment_logs"
LOG_FILE="${LOG_DIR}/upgrade_tokens_decimal_scaling_$(date -u +"%Y-%m-%dT%H-%M-%S").log"
mkdir -p "${LOG_DIR}"

log() { echo -e "${2}[$(date -u +"%Y-%m-%dT%H:%M:%S")]${NC} $1" | tee -a "${LOG_FILE}"; }
log_success() { log "✓ $1" "${GREEN}"; }
log_error() { log "✗ $1" "${RED}"; }
log_info() { log "→ $1" "${BLUE}"; }
log_warning() { log "⚠ $1" "${YELLOW}"; }

if [ -z "$RPC_URL" ] || [ -z "$ACCOUNT" ]; then
    log_error "Missing required environment variables"
    log_info "Required: STARKNET_RPC_URL, DEPLOYER_ACCOUNT"
    exit 1
fi

log_info "========================================="
log_info "Token Contracts Upgrade - Decimal Scaling"
log_info "========================================="
log_info "Network: Sepolia"
log_info "Account: ${ACCOUNT}"
log_info "========================================="

# Token class hash (from previous declaration)
# This is the class hash for AdamToken with custom decimals support
TOKEN_CLASS_HASH="0x06660fdb3cf78cbeaac6d32190976c5b06f93e274ee80c8bf393389f4dd0de57"

log_info "Using Token Class Hash: ${TOKEN_CLASS_HASH}"

# Function to upgrade a token contract
upgrade_token() {
    local token_name=$1
    local token_address=$2
    
    if [ -z "$token_address" ]; then
        log_warning "Skipping ${token_name} - address not set"
        return 0
    fi
    
    log_info "Upgrading ${token_name} at ${token_address}..."
    
    UPGRADE_RESULT=$(sncast --account "${ACCOUNT}" invoke \
        --url "${RPC_URL}" \
        --contract-address "${token_address}" \
        --function "upgrade" \
        --calldata "${TOKEN_CLASS_HASH}" \
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
log_info "--- Upgrading Token Contracts ---"

upgrade_token "ADUSD" "$ADUSD_ADDRESS"
upgrade_token "ADNGN" "$ADNGN_ADDRESS"
upgrade_token "ADKES" "$ADKES_ADDRESS"
upgrade_token "ADGHS" "$ADGHS_ADDRESS"
upgrade_token "ADZAR" "$ADZAR_ADDRESS"

log_info "========================================="
log_success "Token Upgrades Complete!"
log_info "========================================="
log_info "Token Class Hash: ${TOKEN_CLASS_HASH}"
log_info "Check logs for transaction hashes"
log_info "========================================="
log_info "Next Steps:"
log_info "1. Wait for transactions to be confirmed"
log_info "2. Verify token decimals are correct"
log_info "3. Test buy/swap flows"
log_info "========================================="
