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

# Role hashes
MINTER_ROLE="0x4d494e5445525f524f4c45"
BURNER_ROLE="0x4255524e45525f524f4c45"

# Log file
LOG_DIR="deployment_logs"
LOG_FILE="${LOG_DIR}/grant_new_token_roles_$(date -u +"%Y-%m-%dT%H-%M-%S").log"
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
log_info "Grant Roles for New Tokens"
log_info "========================================="
log_info "Network: ${RPC_URL}"
log_info "Account: ${ACCOUNT}"
log_info "Swap Address: ${SWAP_ADDRESS}"
log_info "ADKES Address: ${ADKES_ADDRESS}"
log_info "ADGHS Address: ${ADGHS_ADDRESS}"
log_info "ADZAR Address: ${ADZAR_ADDRESS}"
log_info "MINTER_ROLE: ${MINTER_ROLE}"
log_info "BURNER_ROLE: ${BURNER_ROLE}"
log_info "========================================="

# Function to grant role
grant_role() {
    local token_address=$1
    local role=$2
    local role_name=$3
    local token_name=$4
    
    log_info ""
    log_info "Granting ${role_name} on ${token_name} to swap contract..."
    
    RESULT=$(sncast --account "${ACCOUNT}" invoke \
        --url "${RPC_URL}" \
        --contract-address "${token_address}" \
        --function "grant_role" \
        --calldata "${role}" "${SWAP_ADDRESS}" 2>&1)
    
    if echo "$RESULT" | grep -q "Transaction Hash:"; then
        TX_HASH=$(echo "$RESULT" | grep "Transaction Hash:" | awk '{print $3}')
        log_success "${role_name} granted on ${token_name}: ${TX_HASH}"
        sleep 3
        return 0
    else
        log_warning "Failed to grant ${role_name} on ${token_name} (may already be granted)"
        echo "$RESULT" | tee -a "${LOG_FILE}"
        return 1
    fi
}

# Grant roles for ADKES
log_info ""
log_info "--- ADKES Token ---"
grant_role "${ADKES_ADDRESS}" "${MINTER_ROLE}" "MINTER_ROLE" "ADKES"
ADKES_MINTER_SUCCESS=$?
grant_role "${ADKES_ADDRESS}" "${BURNER_ROLE}" "BURNER_ROLE" "ADKES"
ADKES_BURNER_SUCCESS=$?

# Grant roles for ADGHS
log_info ""
log_info "--- ADGHS Token ---"
grant_role "${ADGHS_ADDRESS}" "${MINTER_ROLE}" "MINTER_ROLE" "ADGHS"
ADGHS_MINTER_SUCCESS=$?
grant_role "${ADGHS_ADDRESS}" "${BURNER_ROLE}" "BURNER_ROLE" "ADGHS"
ADGHS_BURNER_SUCCESS=$?

# Grant roles for ADZAR
log_info ""
log_info "--- ADZAR Token ---"
grant_role "${ADZAR_ADDRESS}" "${MINTER_ROLE}" "MINTER_ROLE" "ADZAR"
ADZAR_MINTER_SUCCESS=$?
grant_role "${ADZAR_ADDRESS}" "${BURNER_ROLE}" "BURNER_ROLE" "ADZAR"
ADZAR_BURNER_SUCCESS=$?

log_info ""
log_info "========================================="
log_success "Role Grant Process Complete!"
log_info "========================================="

# Summary
log_info ""
log_info "Summary:"
if [ $ADKES_MINTER_SUCCESS -eq 0 ] && [ $ADKES_BURNER_SUCCESS -eq 0 ]; then
    log_success "ADKES: All roles granted"
else
    log_warning "ADKES: Some roles may have failed"
fi

if [ $ADGHS_MINTER_SUCCESS -eq 0 ] && [ $ADGHS_BURNER_SUCCESS -eq 0 ]; then
    log_success "ADGHS: All roles granted"
else
    log_warning "ADGHS: Some roles may have failed"
fi

if [ $ADZAR_MINTER_SUCCESS -eq 0 ] && [ $ADZAR_BURNER_SUCCESS -eq 0 ]; then
    log_success "ADZAR: All roles granted"
else
    log_warning "ADZAR: Some roles may have failed"
fi

log_info "========================================="
log_info "Log file: ${LOG_FILE}"
log_info ""
log_info "Next Steps:"
log_info "1. Set exchange rates for the new tokens"
log_info "2. Test buy/sell operations with new tokens"
log_info "========================================="
