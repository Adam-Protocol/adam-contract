#!/bin/bash

# Adam Protocol Deployment Script
# This script deploys the Adam Protocol contracts to Starknet

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default values
NETWORK="${STARKNET_NETWORK:-sepolia}"
SETUP_ROLES="false"

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --owner ADDRESS          Owner address (required, or set DEPLOYER_ADDRESS in .env)"
    echo "  --treasury ADDRESS       Treasury address (optional, defaults to owner)"
    echo "  --usdc ADDRESS          USDC contract address (required)"
    echo "  --fee BPS               Fee in basis points (optional, default: \$DEFAULT_FEE_BPS = 0.3%)"
    echo "  --network NETWORK       Network to deploy to (default: \$STARKNET_NETWORK)"
    echo "  --account ACCOUNT       Deployer account name (default: \$DEPLOYER_ACCOUNT)"
    echo "  --rpc-url URL           RPC URL (optional)"
    echo "  --setup-roles           Setup roles and permissions after deployment"
    echo "  --help                  Display this help message"
    echo ""
    echo "Examples:"
    echo "  # Deploy to Sepolia testnet"
    echo "  $0 --usdc 0x123... --owner 0x456..."
    echo ""
    echo "  # Deploy with custom fee and setup roles"
    echo "  $0 --usdc 0x123... --owner 0x456... --fee 50 --setup-roles"
    echo ""
    echo "  # Deploy to mainnet"
    echo "  $0 --usdc 0x123... --owner 0x456... --network mainnet"
    exit 1
}

# Parse command line arguments
ARGS=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            usage
            ;;
        --setup-roles)
            SETUP_ROLES="true"
            ARGS="$ARGS --setupRoles true"
            shift
            ;;
        *)
            ARGS="$ARGS $1"
            shift
            ;;
    esac
done

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}Warning: .env file not found. Make sure environment variables are set.${NC}"
fi

# Check if node_modules exists
if [ ! -d node_modules ]; then
    echo -e "${YELLOW}Installing dependencies...${NC}"
    pnpm install || npm install
fi

# Run the deployment
echo -e "${GREEN}Starting Adam Protocol deployment...${NC}"
echo ""

npx ts-node scripts/deploy.ts $ARGS

# Check if deployment was successful
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Deployment completed successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Check deployment_logs/ directory for detailed logs and contract addresses."
else
    echo ""
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}Deployment failed!${NC}"
    echo -e "${RED}========================================${NC}"
    echo ""
    echo "Check deployment_logs/ directory for error details."
    exit 1
fi
