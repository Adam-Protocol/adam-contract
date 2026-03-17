#!/bin/bash

# Post-Deployment Initialization for V2 Contracts
# Initializes V2 contracts and sets up roles after deployment

set -e

NETWORK="${1:-testnet}"
DEPLOYER_ADDRESS="STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191"
TREASURY_ADDRESS="${2:-STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191}"

echo "========================================="
echo "V2 Post-Deployment Initialization"
echo "========================================="
echo "Network: $NETWORK"
echo "Deployer: $DEPLOYER_ADDRESS"
echo "Treasury: $TREASURY_ADDRESS"
echo ""

# V2 Contract addresses
ADUSD="$DEPLOYER_ADDRESS.adam-token-adusd-v2"
ADNGN="$DEPLOYER_ADDRESS.adam-token-adngn-v2"
ADKES="$DEPLOYER_ADDRESS.adam-token-adkes-v2"
ADGHS="$DEPLOYER_ADDRESS.adam-token-adghs-v2"
ADZAR="$DEPLOYER_ADDRESS.adam-token-adzar-v2"
USDCX="$DEPLOYER_ADDRESS.usdcx"
SWAP="$DEPLOYER_ADDRESS.adam-swap-v2"

echo "Step 1: Initialize tokens..."
stx call $ADUSD initialize '"Adam USD"' '"ADUSD"' u6 "'$DEPLOYER_ADDRESS" --network $NETWORK
stx call $ADNGN initialize '"Adam NGN"' '"ADNGN"' u6 "'$DEPLOYER_ADDRESS" --network $NETWORK
stx call $ADKES initialize '"Adam KES"' '"ADKES"' u6 "'$DEPLOYER_ADDRESS" --network $NETWORK
stx call $ADGHS initialize '"Adam GHS"' '"ADGHS"' u6 "'$DEPLOYER_ADDRESS" --network $NETWORK
stx call $ADZAR initialize '"Adam ZAR"' '"ADZAR"' u6 "'$DEPLOYER_ADDRESS" --network $NETWORK
echo "✓ Tokens initialized"
echo ""

echo "Step 2: Initialize swap contract with treasury..."
stx call $SWAP initialize \
  "'$DEPLOYER_ADDRESS" \
  "'$TREASURY_ADDRESS" \
  "'$USDCX" \
  "'$ADUSD" \
  "'$ADNGN" \
  "'$ADKES" \
  "'$ADGHS" \
  "'$ADZAR" \
  u50 \
  --network $NETWORK
echo "✓ Swap initialized with treasury"
echo ""

echo "Step 3: Grant admin roles..."
stx call $ADUSD set-admin "'$DEPLOYER_ADDRESS" true --network $NETWORK
stx call $ADNGN set-admin "'$DEPLOYER_ADDRESS" true --network $NETWORK
stx call $ADKES set-admin "'$DEPLOYER_ADDRESS" true --network $NETWORK
stx call $ADGHS set-admin "'$DEPLOYER_ADDRESS" true --network $NETWORK
stx call $ADZAR set-admin "'$DEPLOYER_ADDRESS" true --network $NETWORK
stx call $SWAP set-admin "'$DEPLOYER_ADDRESS" true --network $NETWORK
echo "✓ Admin roles granted"
echo ""

echo "Step 4: Grant minter roles to swap contract..."
stx call $ADUSD set-minter "'$SWAP" true --network $NETWORK
stx call $ADNGN set-minter "'$SWAP" true --network $NETWORK
stx call $ADKES set-minter "'$SWAP" true --network $NETWORK
stx call $ADGHS set-minter "'$SWAP" true --network $NETWORK
stx call $ADZAR set-minter "'$SWAP" true --network $NETWORK
echo "✓ Minter roles granted"
echo ""

echo "Step 5: Grant burner roles to swap contract..."
stx call $ADUSD set-burner "'$SWAP" true --network $NETWORK
stx call $ADNGN set-burner "'$SWAP" true --network $NETWORK
stx call $ADKES set-burner "'$SWAP" true --network $NETWORK
stx call $ADGHS set-burner "'$SWAP" true --network $NETWORK
stx call $ADZAR set-burner "'$SWAP" true --network $NETWORK
echo "✓ Burner roles granted"
echo ""

echo "Step 6: Set initial exchange rates..."
# USDC <-> ADUSD (1:1)
stx call $SWAP set-rate "'$USDCX" "'$ADUSD" u1000000000000000000 --network $NETWORK
stx call $SWAP set-rate "'$ADUSD" "'$USDCX" u1000000000000000000 --network $NETWORK

# USDC <-> ADNGN (1 USD = 1500 NGN)
stx call $SWAP set-rate "'$USDCX" "'$ADNGN" u1500000000000000000000 --network $NETWORK
stx call $SWAP set-rate "'$ADNGN" "'$USDCX" u666666666666666666 --network $NETWORK

# ADUSD <-> ADNGN
stx call $SWAP set-rate "'$ADUSD" "'$ADNGN" u1500000000000000000000 --network $NETWORK
stx call $SWAP set-rate "'$ADNGN" "'$ADUSD" u666666666666666666 --network $NETWORK
echo "✓ Exchange rates set"
echo ""

echo "========================================="
echo "V2 Initialization Complete!"
echo "========================================="
echo ""
echo "Contract Addresses (update in your config):"
echo "  ADUSD_V2: $ADUSD"
echo "  ADNGN_V2: $ADNGN"
echo "  ADKES_V2: $ADKES"
echo "  ADGHS_V2: $ADGHS"
echo "  ADZAR_V2: $ADZAR"
echo "  SWAP_V2: $SWAP"
echo ""
echo "New Features Available:"
echo "  ✓ Role-Based Access Control (admins, pausers, rate-setters)"
echo "  ✓ Treasury management for fee collection"
echo "  ✓ Structured events (BuyExecuted, SellExecuted, SwapExecuted)"
echo "  ✓ Getter functions for all token addresses"
echo ""
echo "Next steps:"
echo "1. Verify contracts on explorer"
echo "2. Test with small transactions"
echo "3. Update backend configuration"
echo "4. Update frontend configuration"
