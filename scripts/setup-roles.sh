#!/bin/bash

# Adam Protocol Role Setup Script
# Run this after deployment to configure contract permissions

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Load environment
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Default values
ACCOUNT="${DEPLOYER_ACCOUNT:-adam-deployer}"
NETWORK="${STARKNET_NETWORK:-sepolia}"
RPC_URL="${STARKNET_RPC_URL:-https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_10/5QQMV6kqa3iDaH_EbNhTw}"

# Role hashes (keccak256 of role names)
MINTER_ROLE="${MINTER_ROLE:-0x4d494e5445525f524f4c45}"  # MINTER_ROLE
BURNER_ROLE="${BURNER_ROLE:-0x4255524e45525f524f4c45}"  # BURNER_ROLE

usage() {
    echo "Usage: $0 --adusd ADDRESS --adngn ADDRESS --pool ADDRESS --swap ADDRESS"
    echo ""
    echo "Options:"
    echo "  --adusd ADDRESS    ADUSD token contract address"
    echo "  --adngn ADDRESS    ADNGN token contract address"
    echo "  --pool ADDRESS     Pool contract address"
    echo "  --swap ADDRESS     Swap contract address"
    echo "  --account NAME     Deployer account name (default: adam-deployer)"
    echo "  --network NAME     Network (default: sepolia)"
    echo "  --rpc-url URL      RPC URL"
    echo "  --help             Show this help"
    echo ""
    echo "Example:"
    echo "  $0 --adusd 0x123... --adngn 0x456... --pool 0x789... --swap 0xabc..."
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --adusd)
            ADUSD="$2"
            shift 2
            ;;
        --adngn)
            ADNGN="$2"
            shift 2
            ;;
        --pool)
            POOL="$2"
            shift 2
            ;;
        --swap)
            SWAP="$2"
            shift 2
            ;;
        --account)
            ACCOUNT="$2"
            shift 2
            ;;
        --network)
            NETWORK="$2"
            shift 2
            ;;
        --rpc-url)
            RPC_URL="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Validate required parameters
if [ -z "$ADUSD" ] || [ -z "$ADNGN" ] || [ -z "$POOL" ] || [ -z "$SWAP" ]; then
    echo -e "${RED}Error: Missing required parameters${NC}"
    usage
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Adam Protocol Role Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Network: $NETWORK"
echo "Account: $ACCOUNT"
echo ""
echo "Contracts:"
echo "  ADUSD: $ADUSD"
echo "  ADNGN: $ADNGN"
echo "  Pool:  $POOL"
echo "  Swap:  $SWAP"
echo ""

# Function to execute sncast command
execute_sncast() {
    local contract=$1
    local function=$2
    local calldata=$3
    local description=$4

    echo -e "${YELLOW}→${NC} $description"
    
    if sncast --account "$ACCOUNT" --url "$RPC_URL" \
        invoke --contract-address "$contract" \
        --function "$function" \
        --calldata $calldata; then
        echo -e "${GREEN}✓${NC} Success"
    else
        echo -e "${RED}✗${NC} Failed"
        return 1
    fi
    echo ""
}

# Grant MINTER_ROLE to swap on ADUSD
execute_sncast "$ADUSD" "grant_role" "$MINTER_ROLE $SWAP" \
    "Granting MINTER_ROLE to swap contract on ADUSD"

# Grant BURNER_ROLE to swap on ADUSD
execute_sncast "$ADUSD" "grant_role" "$BURNER_ROLE $SWAP" \
    "Granting BURNER_ROLE to swap contract on ADUSD"

# Grant MINTER_ROLE to swap on ADNGN
execute_sncast "$ADNGN" "grant_role" "$MINTER_ROLE $SWAP" \
    "Granting MINTER_ROLE to swap contract on ADNGN"

# Grant BURNER_ROLE to swap on ADNGN
execute_sncast "$ADNGN" "grant_role" "$BURNER_ROLE $SWAP" \
    "Granting BURNER_ROLE to swap contract on ADNGN"

# Set swap contract in pool
execute_sncast "$POOL" "set_swap_contract" "$SWAP" \
    "Setting swap contract address in pool"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Role setup completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
