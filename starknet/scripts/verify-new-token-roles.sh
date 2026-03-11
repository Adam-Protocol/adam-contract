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

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Verifying Roles for New Tokens${NC}"
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Swap Address: ${SWAP_ADDRESS}${NC}"
echo ""

# Function to check role
check_role() {
    local token_address=$1
    local role=$2
    local role_name=$3
    local token_name=$4
    
    echo -e "${BLUE}Checking ${role_name} on ${token_name}...${NC}"
    
    RESULT=$(sncast --account "${ACCOUNT}" call \
        --url "${RPC_URL}" \
        --contract-address "${token_address}" \
        --function "has_role" \
        --calldata "${role}" "${SWAP_ADDRESS}" 2>&1)
    
    if echo "$RESULT" | grep -q "0x1"; then
        echo -e "${GREEN}✓ ${role_name} is granted${NC}"
        return 0
    else
        echo -e "${RED}✗ ${role_name} is NOT granted${NC}"
        echo "$RESULT"
        return 1
    fi
}

# Check ADKES
echo -e "${YELLOW}--- ADKES Token ---${NC}"
check_role "${ADKES_ADDRESS}" "${MINTER_ROLE}" "MINTER_ROLE" "ADKES"
ADKES_MINTER=$?
check_role "${ADKES_ADDRESS}" "${BURNER_ROLE}" "BURNER_ROLE" "ADKES"
ADKES_BURNER=$?
echo ""

# Check ADGHS
echo -e "${YELLOW}--- ADGHS Token ---${NC}"
check_role "${ADGHS_ADDRESS}" "${MINTER_ROLE}" "MINTER_ROLE" "ADGHS"
ADGHS_MINTER=$?
check_role "${ADGHS_ADDRESS}" "${BURNER_ROLE}" "BURNER_ROLE" "ADGHS"
ADGHS_BURNER=$?
echo ""

# Check ADZAR
echo -e "${YELLOW}--- ADZAR Token ---${NC}"
check_role "${ADZAR_ADDRESS}" "${MINTER_ROLE}" "MINTER_ROLE" "ADZAR"
ADZAR_MINTER=$?
check_role "${ADZAR_ADDRESS}" "${BURNER_ROLE}" "BURNER_ROLE" "ADZAR"
ADZAR_BURNER=$?
echo ""

# Summary
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}=========================================${NC}"

ALL_OK=0

if [ $ADKES_MINTER -eq 0 ] && [ $ADKES_BURNER -eq 0 ]; then
    echo -e "${GREEN}✓ ADKES: All roles OK${NC}"
else
    echo -e "${RED}✗ ADKES: Missing roles${NC}"
    ALL_OK=1
fi

if [ $ADGHS_MINTER -eq 0 ] && [ $ADGHS_BURNER -eq 0 ]; then
    echo -e "${GREEN}✓ ADGHS: All roles OK${NC}"
else
    echo -e "${RED}✗ ADGHS: Missing roles${NC}"
    ALL_OK=1
fi

if [ $ADZAR_MINTER -eq 0 ] && [ $ADZAR_BURNER -eq 0 ]; then
    echo -e "${GREEN}✓ ADZAR: All roles OK${NC}"
else
    echo -e "${RED}✗ ADZAR: Missing roles${NC}"
    ALL_OK=1
fi

echo -e "${BLUE}=========================================${NC}"

if [ $ALL_OK -eq 0 ]; then
    echo -e "${GREEN}✓ All roles configured correctly!${NC}"
else
    echo -e "${RED}✗ Some roles are missing. Re-run grant script.${NC}"
fi
