#!/bin/bash

# Quick USDCX Deployment Script
# This script automates the entire deployment and minting process

set -e

echo "🚀 USDCX Token Quick Deployment"
echo "================================"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found!"
    echo "Please create a .env file with your Stacks configuration."
    exit 1
fi

# Load environment variables
source .env

# Check required variables
if [ -z "$STACKS_DEPLOYER_PRIVATE_KEY" ] || [ -z "$STACKS_DEPLOYER_ADDRESS" ]; then
    echo "❌ Error: Missing required environment variables!"
    echo "Please set STACKS_DEPLOYER_PRIVATE_KEY and STACKS_DEPLOYER_ADDRESS in .env"
    exit 1
fi

echo "📋 Configuration:"
echo "   Deployer: $STACKS_DEPLOYER_ADDRESS"
echo "   Network: Stacks Testnet"
echo ""

# Step 1: Deploy contract
echo "Step 1/3: Deploying USDCX contract..."
echo "-------------------------------------"
pnpm run deploy:usdcx

if [ $? -ne 0 ]; then
    echo "❌ Deployment failed!"
    exit 1
fi

echo ""
echo "⏳ Waiting 30 seconds for deployment to confirm..."
sleep 30

# Step 2: Mint tokens
echo ""
echo "Step 2/3: Minting 100 USDCX tokens..."
echo "-------------------------------------"
pnpm run mint:usdcx

if [ $? -ne 0 ]; then
    echo "❌ Minting failed!"
    echo "💡 The contract might still be confirming. Wait a few minutes and run: pnpm run mint:usdcx"
    exit 1
fi

echo ""
echo "⏳ Waiting 30 seconds for minting to confirm..."
sleep 30

# Step 3: Check balance
echo ""
echo "Step 3/3: Checking balance..."
echo "-------------------------------------"
pnpm run check:usdcx

echo ""
echo "✅ Deployment Complete!"
echo "======================="
echo ""
echo "📝 Next steps:"
echo "   1. Update your .env with: STACKS_USDCx_ADDRESS=$STACKS_DEPLOYER_ADDRESS.usdcx"
echo "   2. Update your frontend configuration"
echo "   3. Test token transfers in your app"
echo ""
echo "🔗 View your tokens:"
echo "   https://explorer.hiro.so/address/$STACKS_DEPLOYER_ADDRESS?chain=testnet"
echo ""
