#!/bin/bash

# Environment Configuration Check Script
# Validates that all required environment variables are set

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Adam Protocol Environment Check${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if .env file exists
if [ -f .env ]; then
    echo -e "${GREEN}✓${NC} .env file found"
    # Load environment variables
    export $(cat .env | grep -v '^#' | xargs)
else
    echo -e "${YELLOW}!${NC} .env file not found"
    echo "  Copy .env.example to .env and fill in your values"
    exit 1
fi

# Required variables
REQUIRED_VARS=(
    "DEPLOYER_PRIVATE_KEY"
    "DEPLOYER_ADDRESS"
    "STARKNET_RPC_URL"
)

# Recommended variables
RECOMMENDED_VARS=(
    "DEPLOYER_ACCOUNT"
    "STARKNET_NETWORK"
    "TREASURY_ADDRESS"
    "USDC_ADDRESS"
    "DEFAULT_FEE_BPS"
    "MAX_FEE_BPS"
    "VERIFIER"
    "DEPLOYMENT_LOG_DIR"
    "MINTER_ROLE"
    "BURNER_ROLE"
    "ADAM_TOKEN_NAME"
    "ADAM_POOL_NAME"
    "ADAM_SWAP_NAME"
    "ADUSD_NAME"
    "ADUSD_SYMBOL"
    "ADNGN_NAME"
    "ADNGN_SYMBOL"
)

echo ""
echo -e "${GREEN}Required Variables:${NC}"
echo "-------------------"

all_required_ok=true
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo -e "${RED}✗${NC} $var is not set"
        all_required_ok=false
    else
        # Mask private key for security
        if [ "$var" = "DEPLOYER_PRIVATE_KEY" ]; then
            masked_value="${!var:0:10}...${!var: -10}"
            echo -e "${GREEN}✓${NC} $var: $masked_value"
        else
            echo -e "${GREEN}✓${NC} $var: ${!var}"
        fi
    fi
done

echo ""
echo -e "${GREEN}Recommended Variables:${NC}"
echo "-----------------------"

for var in "${RECOMMENDED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo -e "${YELLOW}!${NC} $var is not set (using default)"
    else
        echo -e "${GREEN}✓${NC} $var: ${!var}"
    fi
done

echo ""
echo -e "${GREEN}Network Configuration:${NC}"
echo "------------------------"

# Check RPC connectivity
if [ -n "$STARKNET_RPC_URL" ]; then
    echo -e "${GREEN}✓${NC} RPC URL: $STARKNET_RPC_URL"
    
    # Try to ping the RPC (optional)
    if command -v curl &> /dev/null; then
        echo -n "  Testing RPC connectivity... "
        if curl -s --head --request GET "$STARKNET_RPC_URL" | grep "200\|400\|405" > /dev/null; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}!${NC} Could not verify RPC connectivity"
        fi
    fi
fi

if [ -n "$STARKNET_NETWORK" ]; then
    echo -e "${GREEN}✓${NC} Network: $STARKNET_NETWORK"
fi

echo ""
echo -e "${GREEN}Account Configuration:${NC}"
echo "------------------------"

if [ -n "$DEPLOYER_ACCOUNT" ]; then
    echo -e "${GREEN}✓${NC} Account name: $DEPLOYER_ACCOUNT"
    
    # Check if account exists in sncast
    if command -v sncast &> /dev/null; then
        if sncast account list | grep -q "$DEPLOYER_ACCOUNT"; then
            echo -e "${GREEN}✓${NC} Account found in sncast"
        else
            echo -e "${YELLOW}!${NC} Account not found in sncast"
            echo "  Run: sncast account add --name $DEPLOYER_ACCOUNT"
        fi
    else
        echo -e "${YELLOW}!${NC} sncast not installed"
    fi
fi

echo ""
echo -e "${GREEN}Deployment Configuration:${NC}"
echo "---------------------------"

if [ -n "$DEFAULT_FEE_BPS" ]; then
    fee_percent=$(echo "scale=2; $DEFAULT_FEE_BPS / 100" | bc)
    echo -e "${GREEN}✓${NC} Default fee: $DEFAULT_FEE_BPS bps ($fee_percent%)"
fi

if [ -n "$MAX_FEE_BPS" ]; then
    max_fee_percent=$(echo "scale=2; $MAX_FEE_BPS / 100" | bc)
    echo -e "${GREEN}✓${NC} Max fee: $MAX_FEE_BPS bps ($max_fee_percent%)"
fi

if [ -n "$VERIFIER" ]; then
    echo -e "${GREEN}✓${NC} Verifier: $VERIFIER"
fi

echo ""
echo -e "${GREEN}Token Configuration:${NC}"
echo "---------------------"

if [ -n "$ADUSD_NAME" ] && [ -n "$ADUSD_SYMBOL" ]; then
    echo -e "${GREEN}✓${NC} ADUSD: $ADUSD_NAME ($ADUSD_SYMBOL)"
fi

if [ -n "$ADNGN_NAME" ] && [ -n "$ADNGN_SYMBOL" ]; then
    echo -e "${GREEN}✓${NC} ADNGN: $ADNGN_NAME ($ADNGN_SYMBOL)"
fi

echo ""
echo -e "${GREEN}Summary:${NC}"
echo "--------"

if [ "$all_required_ok" = true ]; then
    echo -e "${GREEN}✓ All required variables are set${NC}"
    echo ""
    echo "You're ready to deploy! Run:"
    echo "  ./scripts/deploy.sh --usdc \$USDC_ADDRESS --owner \$DEPLOYER_ADDRESS"
else
    echo -e "${RED}✗ Some required variables are missing${NC}"
    echo ""
    echo "Please set the missing variables in your .env file"
    exit 1
fi

echo ""
echo -e "${GREEN}Quick Commands:${NC}"
echo "---------------"
echo "  Deploy:        ./scripts/deploy.sh --usdc \$USDC_ADDRESS --owner \$DEPLOYER_ADDRESS"
echo "  Check env:     ./scripts/check-env.sh"
echo "  Setup roles:   ./scripts/setup-roles.sh --adusd <addr> --adngn <addr> --pool <addr> --swap <addr>"
echo "  Get help:      ./scripts/deploy.sh --help"