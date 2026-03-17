#!/bin/bash

# Complete Adam Protocol Deployment Script
# Handles validation, deployment, and initialization in one flow

set -e

# Configuration
NETWORK="${1:-testnet}"
TREASURY_ADDRESS="${2:-}"
VERSION="${3:-v2}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "Adam Protocol Complete Deployment"
echo "========================================="
echo "Network: $NETWORK"
echo "Version: $VERSION"
echo ""

# Validate prerequisites
if ! command -v clarinet &> /dev/null; then
    echo -e "${RED}Error: clarinet is not installed${NC}"
    echo "Install from: https://github.com/hirosystems/clarinet"
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo -e "${RED}Error: npm is not installed${NC}"
    exit 1
fi

# Step 1: Validate contracts
echo -e "${YELLOW}Step 1: Validating contracts...${NC}"
clarinet check
if [ $? -ne 0 ]; then
    echo -e "${RED}Contract validation failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Contracts validated${NC}"
echo ""

# Step 2: Run tests
echo -e "${YELLOW}Step 2: Running tests...${NC}"
npm test
if [ $? -ne 0 ]; then
    echo -e "${RED}Tests failed. Continue anyway? (y/n)${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
echo -e "${GREEN}✓ Tests passed${NC}"
echo ""

# Step 3: Generate deployment plan
echo -e "${YELLOW}Step 3: Generating deployment plan...${NC}"
if [ "$NETWORK" = "mainnet" ]; then
    clarinet deployments generate --mainnet --high-cost
else
    clarinet deployments generate --testnet --medium-cost
fi
echo -e "${GREEN}✓ Deployment plan generated${NC}"
echo ""

# Step 4: Review and confirm
echo -e "${YELLOW}Step 4: Review deployment plan${NC}"
echo "Plan location: deployments/default.$NETWORK-plan.yaml"
echo ""
echo "Estimated cost will be shown in the next step."
echo -e "${YELLOW}Continue with deployment? (y/n)${NC}"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled"
    exit 0
fi

# Step 5: Deploy contracts
echo ""
echo -e "${YELLOW}Step 5: Deploying contracts to $NETWORK...${NC}"
clarinet deployments apply --$NETWORK

if [ $? -ne 0 ]; then
    echo -e "${RED}Deployment failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Contracts deployed${NC}"
echo ""

# Step 6: Post-deployment instructions
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo -e "${GREEN}Next Steps:${NC}"
echo ""
echo "1. Initialize contracts automatically:"
echo "   pnpm run init"
echo ""
echo "2. Or initialize manually using the guide:"
echo "   See: scripts/init-v2-manual.md"
echo ""
echo "3. Update backend configuration:"
echo "   File: adam-backend/.env"
echo "   Add V2 contract addresses"
echo ""
echo "4. Update frontend configuration:"
echo "   File: adam-app/src/lib/chains/config.ts"
echo "   Add V2 contract addresses"
echo ""
echo "5. Test with small transactions before going live"
echo ""
echo "Deployment summary saved to:"
echo "  deployments/default.$NETWORK-plan.yaml"
echo ""
echo -e "${GREEN}Deployment successful!${NC}"
