#!/bin/bash

# Deploy only V2 contracts to testnet
# This creates new contract instances with updated features

set -e

NETWORK="${1:-testnet}"

echo "========================================="
echo "Adam Protocol V2 Deployment"
echo "========================================="
echo "Network: $NETWORK"
echo ""

# Validate contracts
echo "Step 1: Validating contracts..."
clarinet check
echo "✓ Contracts validated"
echo ""

# Generate deployment plan for V2 only
echo "Step 2: Generating V2 deployment plan..."

# Create a custom deployment plan
cat > deployments/v2.testnet-plan.yaml << 'EOF'
---
id: 1
name: V2 Testnet deployment
network: testnet
stacks-node: "https://api.testnet.hiro.so"
bitcoin-node: "http://blockstack:blockstacksystem@bitcoind.testnet.stacks.co:18332"
plan:
  batches:
    - id: 0
      transactions:
        - contract-publish:
            contract-name: adam-token-adusd-v2
            expected-sender: STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191
            cost: 64730
            path: contracts/adam-token.clar
            anchor-block-only: true
            clarity-version: 2
        - contract-publish:
            contract-name: adam-token-adngn-v2
            expected-sender: STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191
            cost: 64730
            path: contracts/adam-token.clar
            anchor-block-only: true
            clarity-version: 2
        - contract-publish:
            contract-name: adam-token-adkes-v2
            expected-sender: STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191
            cost: 64730
            path: contracts/adam-token.clar
            anchor-block-only: true
            clarity-version: 2
        - contract-publish:
            contract-name: adam-token-adghs-v2
            expected-sender: STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191
            cost: 64730
            path: contracts/adam-token.clar
            anchor-block-only: true
            clarity-version: 2
        - contract-publish:
            contract-name: adam-token-adzar-v2
            expected-sender: STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191
            cost: 64730
            path: contracts/adam-token.clar
            anchor-block-only: true
            clarity-version: 2
        - contract-publish:
            contract-name: adam-swap-v2
            expected-sender: STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191
            cost: 145190
            path: contracts/adam-swap.clar
            anchor-block-only: true
            clarity-version: 2
      epoch: "2.5"
EOF

echo "✓ V2 deployment plan created"
echo ""

# Deploy
echo "Step 3: Deploying V2 contracts..."
clarinet deployments apply -p deployments/v2.testnet-plan.yaml

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================="
    echo "V2 Deployment Complete!"
    echo "========================================="
    echo ""
    echo "Contract addresses:"
    echo "  adam-token-adusd-v2: STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adusd-v2"
    echo "  adam-token-adngn-v2: STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adngn-v2"
    echo "  adam-token-adkes-v2: STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adkes-v2"
    echo "  adam-token-adghs-v2: STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adghs-v2"
    echo "  adam-token-adzar-v2: STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adzar-v2"
    echo "  adam-swap-v2: STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-swap-v2"
    echo ""
    echo "Next steps:"
    echo "1. Run: ./scripts/post-deploy-init-v2.sh $NETWORK <TREASURY_ADDRESS>"
    echo "2. Update backend config with V2 contract addresses"
    echo "3. Update frontend config with V2 contract addresses"
else
    echo "Deployment failed."
    exit 1
fi
