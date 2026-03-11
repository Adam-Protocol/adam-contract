#!/bin/bash

# Post-Deployment Role Setup Script
# Sets up minter/burner roles and swap contract authorization

set -e

NETWORK="testnet"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --network)
      NETWORK="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "========================================="
echo "Adam Protocol Role Setup"
echo "========================================="
echo "Network: $NETWORK"
echo ""

# Load deployment addresses from summary
DEPLOYMENT_FILE="deployments/deployment_summary_$NETWORK.json"

if [ ! -f "$DEPLOYMENT_FILE" ]; then
    echo "Error: Deployment summary not found: $DEPLOYMENT_FILE"
    echo "Please run deploy.sh first"
    exit 1
fi

echo "This script will guide you through setting up roles."
echo "You'll need to execute these contract calls manually using:"
echo "- Clarinet console"
echo "- Stacks Explorer Sandbox"
echo "- Stacks CLI"
echo ""

echo "========================================="
echo "Step 1: Grant Minter Role to AdamSwap"
echo "========================================="
echo ""
echo "Execute these contract calls:"
echo ""
echo "(contract-call? .adam-token-adusd set-minter .adam-swap true)"
echo "(contract-call? .adam-token-adngn set-minter .adam-swap true)"
echo ""
read -p "Press Enter when complete..."

echo ""
echo "========================================="
echo "Step 2: Grant Burner Role to AdamSwap"
echo "========================================="
echo ""
echo "Execute these contract calls:"
echo ""
echo "(contract-call? .adam-token-adusd set-burner .adam-swap true)"
echo "(contract-call? .adam-token-adngn set-burner .adam-swap true)"
echo ""
read -p "Press Enter when complete..."

echo ""
echo "========================================="
echo "Step 3: Set Swap Contract in Pool"
echo "========================================="
echo ""
echo "Execute this contract call:"
echo ""
echo "(contract-call? .adam-pool set-swap-contract .adam-swap)"
echo ""
read -p "Press Enter when complete..."

echo ""
echo "========================================="
echo "Step 4: Initialize Exchange Rates"
echo "========================================="
echo ""
echo "Set initial rates (example: 1:1 for USDC:ADUSD):"
echo ""
echo "(contract-call? .adam-swap set-rate .usdc-token .adam-token-adusd u1000000000000000000)"
echo "(contract-call? .adam-swap set-rate .adam-token-adusd .usdc-token u1000000000000000000)"
echo ""
echo "For ADNGN (example: 1 USD = 1500 NGN):"
echo "(contract-call? .adam-swap set-rate .usdc-token .adam-token-adngn u1500000000000000000000)"
echo ""
read -p "Press Enter when complete..."

echo ""
echo "========================================="
echo "Setup Complete!"
echo "========================================="
echo ""
echo "Verification checklist:"
echo "□ AdamSwap can mint ADUSD"
echo "□ AdamSwap can mint ADNGN"
echo "□ AdamSwap can burn ADUSD"
echo "□ AdamSwap can burn ADNGN"
echo "□ Pool recognizes AdamSwap"
echo "□ Exchange rates are set"
echo ""
echo "Test with small transactions before going live!"
