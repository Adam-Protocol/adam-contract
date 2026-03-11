#!/bin/bash

# Adam Protocol Stacks Deployment Script
# Usage: ./scripts/deploy.sh [--network testnet|mainnet] [--setup-roles]

set -e

# Default values
NETWORK="testnet"
SETUP_ROLES=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --network)
      NETWORK="$2"
      shift 2
      ;;
    --setup-roles)
      SETUP_ROLES=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--network testnet|mainnet] [--setup-roles]"
      exit 1
      ;;
  esac
done

echo "========================================="
echo "Adam Protocol Stacks Deployment"
echo "========================================="
echo "Network: $NETWORK"
echo "Setup Roles: $SETUP_ROLES"
echo ""

# Check if clarinet is installed
if ! command -v clarinet &> /dev/null; then
    echo "Error: clarinet is not installed"
    echo "Install from: https://github.com/hirosystems/clarinet"
    exit 1
fi

# Validate contracts
echo "Step 1: Validating contracts..."
clarinet check
if [ $? -ne 0 ]; then
    echo "Error: Contract validation failed"
    exit 1
fi
echo "✓ Contracts validated"
echo ""

# Run tests
echo "Step 2: Running tests..."
clarinet test
if [ $? -ne 0 ]; then
    echo "Warning: Some tests failed. Continue? (y/n)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
echo "✓ Tests completed"
echo ""

# Generate deployment plan
echo "Step 3: Generating deployment plan..."
if [ "$NETWORK" = "mainnet" ]; then
    clarinet deployments generate --mainnet --high-cost
else
    clarinet deployments generate --testnet --medium-cost
fi
echo "✓ Deployment plan generated"
echo ""

# Review deployment plan
echo "Step 4: Review deployment plan"
echo "Please review the deployment plan in deployments/default.$NETWORK-plan.yaml"
echo "Continue with deployment? (y/n)"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled"
    exit 0
fi

# Deploy contracts
echo "Step 5: Deploying contracts..."
clarinet deployments apply --$NETWORK
if [ $? -ne 0 ]; then
    echo "Error: Deployment failed"
    exit 1
fi
echo "✓ Contracts deployed"
echo ""

# Setup roles if requested
if [ "$SETUP_ROLES" = true ]; then
    echo "Step 6: Setting up roles..."
    echo "Note: Role setup requires manual contract calls"
    echo "Please run the post-deployment setup script:"
    echo "./scripts/setup-roles.sh --network $NETWORK"
fi

echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo "Network: $NETWORK"
echo "Deployment summary: deployments/deployment_summary_$NETWORK.json"
echo ""
echo "Next steps:"
echo "1. Verify contracts on explorer"
echo "2. Run setup-roles.sh to configure permissions"
echo "3. Set initial exchange rates"
echo "4. Test with small transactions"
