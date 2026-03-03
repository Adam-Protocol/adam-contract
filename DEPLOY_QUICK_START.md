# Quick Start: Deploy Adam Protocol

## 1. Setup (One-time)

```bash
# Install dependencies
cd adam-contract
pnpm install

# Configure environment
cp .env.example .env
# Edit .env with your deployer credentials
```

## 2. Deploy to Testnet

```bash
# Simple deployment
./scripts/deploy.sh \
  --usdc 0x<USDC_ADDRESS> \
  --owner 0x<OWNER_ADDRESS>

# With automatic role setup (recommended)
./scripts/deploy.sh \
  --usdc 0x<USDC_ADDRESS> \
  --owner 0x<OWNER_ADDRESS> \
  --setup-roles
```

## 3. Check Results

```bash
# View deployment summary
cat deployment_logs/deployment_summary_sepolia.json
```

## 4. Update Backend

Copy the contract addresses from the deployment summary to your backend `.env`:

```env
ADUSD_ADDRESS=0x...
ADNGN_ADDRESS=0x...
POOL_ADDRESS=0x...
SWAP_ADDRESS=0x...
```

## Common Commands

```bash
# Deploy with custom fee (0.5%)
./scripts/deploy.sh --usdc 0x... --owner 0x... --fee 50

# Deploy to mainnet
./scripts/deploy.sh --usdc 0x... --owner 0x... --network mainnet

# Use custom RPC
./scripts/deploy.sh --usdc 0x... --owner 0x... --rpc-url https://...

# Get help
./scripts/deploy.sh --help
```

## Deployment Order

The script automatically deploys in this order:
1. ADUSD Token
2. ADNGN Token  
3. Adam Pool
4. Adam Swap
5. Role Setup (if --setup-roles flag is used)

## What You Need

- ✅ Funded Starknet account
- ✅ USDC contract address (testnet or mainnet)
- ✅ Owner address (your wallet)
- ✅ Treasury address (optional, defaults to owner)

## Testnet USDC Addresses

### Sepolia
You may need to deploy a test USDC or use an existing one:
- Check Starkscan for available test tokens
- Or deploy your own ERC20 for testing

## After Deployment

1. Save the contract addresses from `deployment_logs/deployment_summary_sepolia.json`
2. Update your backend configuration
3. Test the contracts with your frontend/backend
4. Monitor transactions on Starkscan

## Need Help?

See [DEPLOYMENT.md](./DEPLOYMENT.md) for detailed documentation.
