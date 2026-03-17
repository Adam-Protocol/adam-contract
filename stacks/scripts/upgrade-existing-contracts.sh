#!/bin/bash

# Upgrade Existing Contracts Configuration
# This script updates the existing deployed contracts with new role configurations

set -e

NETWORK="${1:-testnet}"
DEPLOYER_ADDRESS="STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191"
TREASURY_ADDRESS="${2:-STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191}"

echo "========================================="
echo "Upgrading Existing Contract Configuration"
echo "========================================="
echo "Network: $NETWORK"
echo "Deployer: $DEPLOYER_ADDRESS"
echo "Treasury: $TREASURY_ADDRESS"
echo ""

# Contract addresses
ADUSD="$DEPLOYER_ADDRESS.adam-token-adusd"
ADNGN="$DEPLOYER_ADDRESS.adam-token-adngn"
ADKES="$DEPLOYER_ADDRESS.adam-token-adkes"
ADGHS="$DEPLOYER_ADDRESS.adam-token-adghs"
ADZAR="$DEPLOYER_ADDRESS.adam-token-adzar"
SWAP="$DEPLOYER_ADDRESS.adam-swap"

echo "⚠️  WARNING: The existing contracts don't have the new features."
echo "The deployed contracts are immutable and cannot be upgraded."
echo ""
echo "To use the new features (RBAC, treasury, structured events), you need to:"
echo "1. Deploy new contract instances with different names, OR"
echo "2. Deploy from a different address"
echo ""
echo "Options:"
echo "  A) Deploy new contracts with -v2 suffix (recommended)"
echo "  B) Deploy from a new address"
echo "  C) Continue using existing contracts (no new features)"
echo ""
echo "Choose option (A/B/C):"
read -r option

case $option in
  [Aa])
    echo ""
    echo "To deploy V2 contracts:"
    echo "1. Update Clarinet.toml to add -v2 suffix to contract names"
    echo "2. Run: clarinet deployments generate --testnet"
    echo "3. Run: clarinet deployments apply --testnet"
    echo "4. Run: ./scripts/post-deploy-init.sh testnet $TREASURY_ADDRESS"
    ;;
  [Bb])
    echo ""
    echo "To deploy from new address:"
    echo "1. Update settings/Testnet.toml with new mnemonic"
    echo "2. Get testnet STX from faucet"
    echo "3. Run: clarinet deployments apply --testnet"
    echo "4. Run: ./scripts/post-deploy-init.sh testnet $TREASURY_ADDRESS"
    ;;
  [Cc])
    echo ""
    echo "Continuing with existing contracts (no upgrade)."
    echo "Note: New features will not be available."
    ;;
  *)
    echo "Invalid option. Exiting."
    exit 1
    ;;
esac
