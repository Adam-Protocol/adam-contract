#!/bin/bash

# Load environment variables
source .env

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Checking Exchange Rates${NC}"
echo -e "${BLUE}=========================================${NC}"

# Function to check rate
check_rate() {
    local from=$1
    local to=$2
    local pair_name=$3
    
    echo -e "${BLUE}Checking rate: ${pair_name}${NC}"
    
    RESULT=$(sncast --account "${DEPLOYER_ACCOUNT}" call \
        --url "${STARKNET_RPC_URL}" \
        --contract-address "${SWAP_ADDRESS}" \
        --function "get_rate" \
        --calldata "${from}" "${to}" 2>&1)
    
    if echo "$RESULT" | grep -q "0x0 0x0"; then
        echo -e "${RED}✗ Rate NOT set (0)${NC}"
        return 1
    else
        echo -e "${GREEN}✓ Rate is set${NC}"
        echo "$RESULT" | grep -A 1 "response:"
        return 0
    fi
}

echo ""
echo -e "${BLUE}--- USDC to New Tokens ---${NC}"
check_rate "${USDC_ADDRESS}" "${ADKES_ADDRESS}" "USDC -> ADKES"
check_rate "${USDC_ADDRESS}" "${ADGHS_ADDRESS}" "USDC -> ADGHS"
check_rate "${USDC_ADDRESS}" "${ADZAR_ADDRESS}" "USDC -> ADZAR"

echo ""
echo -e "${BLUE}--- New Tokens to USDC ---${NC}"
check_rate "${ADKES_ADDRESS}" "${USDC_ADDRESS}" "ADKES -> USDC"
check_rate "${ADGHS_ADDRESS}" "${USDC_ADDRESS}" "ADGHS -> USDC"
check_rate "${ADZAR_ADDRESS}" "${USDC_ADDRESS}" "ADZAR -> USDC"

echo ""
echo -e "${BLUE}=========================================${NC}"
