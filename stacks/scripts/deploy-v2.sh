#!/bin/bash

# Deploy V2 contracts with updated features
# This deploys new contract instances with -v2 suffix

set -e

NETWORK="${1:-testnet}"

echo "========================================="
echo "Adam Protocol V2 Deployment"
echo "========================================="
echo "Network: $NETWORK"
echo ""

# Check if clarinet is installed
if ! command -v clarinet &> /dev/null; then
    echo "Error: clarinet is not installed"
    exit 1
fi

# Validate contracts
echo "Step 1: Validating contracts..."
clarinet check
echo "✓ Contracts validated"
echo ""

# Run tests
echo "Step 2: Running tests..."
npm test
echo "✓ Tests passed"
echo ""

# Deploy using clarinet
echo "Step 3: Deploying contracts to $NETWORK..."
echo ""
echo "Note: Since contracts already exist, you have two options:"
echo "1. Deploy to a new address (create new wallet)"
echo "2. Use contract-call to update existing contracts"
echo ""
echo "For immutable contracts, option 1 is recommended."
echo "The new contracts will have the updated features."
echo ""
echo "To deploy to a new address:"
echo "1. Update settings/Testnet.toml with a new mnemonic"
echo "2. Get testnet STX from https://explorer.hiro.so/sandbox/faucet?chain=testnet"
echo "3. Run: clarinet deployments apply --testnet"
echo ""
echo "Current deployer address: STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191"
echo ""
echo "Would you like to continue with deployment? (y/n)"
read -r response

if [[ "$response" =~ ^[Yy]$ ]]; then
    clarinet deployments apply --$NETWORK
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✓ Deployment successful!"
        echo ""
        echo "Next steps:"
        echo "1. Run: ./scripts/post-deploy-init.sh $NETWORK <TREASURY_ADDRESS>"
        echo "2. Update backend with new contract addresses"
        echo "3. Update frontend with new contract addresses"
    else
        echo ""
        echo "Deployment failed. Check the error above."
    fi
else
    echo "Deployment cancelled."
fi
