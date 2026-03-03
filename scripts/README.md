# Deployment Scripts

This directory contains scripts for deploying and managing Adam Protocol contracts on Starknet.

## Scripts Overview

### `deploy.ts`
Main TypeScript deployment script that handles the complete deployment process.

**Features:**
- Builds all contracts
- Declares contract classes
- Deploys all contracts in correct order
- Optionally sets up roles and permissions
- Generates detailed logs and deployment summaries

**Usage:**
```bash
npx ts-node scripts/deploy.ts --usdc 0x... --owner 0x... [OPTIONS]
```

### `deploy.sh`
Bash wrapper for the TypeScript deployment script with better UX.

**Features:**
- Colored output
- Automatic dependency installation
- Environment validation
- Error handling

**Usage:**
```bash
./scripts/deploy.sh --usdc 0x... --owner 0x... [OPTIONS]
```

### `setup-roles.sh`
Standalone script for configuring contract roles and permissions.

**Use this when:**
- You deployed without `--setup-roles` flag
- You need to reconfigure permissions
- You're setting up a new swap contract

**Usage:**
```bash
./scripts/setup-roles.sh \
  --adusd 0x... \
  --adngn 0x... \
  --pool 0x... \
  --swap 0x...
```

## Common Options

### Required
- `--usdc ADDRESS` - USDC token contract address
- `--owner ADDRESS` - Owner address for all contracts

### Optional
- `--treasury ADDRESS` - Treasury for fees (defaults to owner)
- `--fee BPS` - Fee in basis points (default: 30 = 0.3%)
- `--network NAME` - Network: sepolia or mainnet (default: sepolia)
- `--account NAME` - Starknet account name (default: adam-deployer)
- `--rpc-url URL` - Custom RPC endpoint
- `--setup-roles` - Automatically configure permissions

## Examples

### Basic Testnet Deployment
```bash
./scripts/deploy.sh \
  --usdc $USDC_ADDRESS \
  --owner $DEPLOYER_ADDRESS
```

### Production Deployment with Custom Settings
```bash
./scripts/deploy.sh \
  --usdc 0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8 \
  --owner 0x0456e6d7184cd79e3f5cc63397a5540e8aeef7fd2f136136dfd40caf122cba88 \
  --treasury 0x0789... \
  --fee 50 \
  --network mainnet \
  --setup-roles
```

### Setup Roles After Deployment
```bash
./scripts/setup-roles.sh \
  --adusd 0x0123... \
  --adngn 0x0456... \
  --pool 0x0789... \
  --swap 0x0abc...
```

## Output Files

### `deployment_logs/`
Directory containing all deployment logs and summaries.

**Files:**
- `deploy_<timestamp>.log` - Detailed deployment log
- `deployment_summary_<network>.json` - Contract addresses and metadata

**Example summary:**
```json
{
  "network": "sepolia",
  "timestamp": "2024-03-03T10:30:00.000Z",
  "contracts": {
    "adusd": "0x0123...",
    "adngn": "0x0456...",
    "pool": "0x0789...",
    "swap": "0x0abc...",
    "usdc": "0x049d..."
  },
  "classHashes": {
    "adam_token": "0x0def...",
    "adam_pool": "0x0fed...",
    "adam_swap": "0x0cba..."
  }
}
```

## Deployment Flow

```
1. Build Contracts
   └─> scarb build

2. Declare Contracts
   ├─> adam_token (for ADUSD)
   ├─> adam_token (for ADNGN)
   ├─> adam_pool
   └─> adam_swap

3. Deploy Contracts
   ├─> ADUSD Token
   ├─> ADNGN Token
   ├─> Adam Pool
   └─> Adam Swap

4. Setup Roles (optional)
   ├─> Grant MINTER_ROLE to swap on ADUSD
   ├─> Grant BURNER_ROLE to swap on ADUSD
   ├─> Grant MINTER_ROLE to swap on ADNGN
   ├─> Grant BURNER_ROLE to swap on ADNGN
   └─> Set swap address in pool

5. Save Summary
   └─> deployment_logs/deployment_summary_<network>.json
```

## Prerequisites

1. **Starknet Tools**
   - `sncast` (Starknet Foundry)
   - `scarb` (Cairo compiler)

2. **Node.js**
   - Node.js v18+
   - pnpm/npm/yarn

3. **Starknet Account**
   - Funded account on target network
   - Account added to sncast: `sncast account add`

4. **Environment Variables**
   - Copy `.env.example` to `.env`
   - Fill in deployer credentials

## Troubleshooting

### "Account not found"
```bash
# List accounts
sncast account list

# Add account
sncast account add --name adam-deployer
```

### "Insufficient funds"
Get testnet ETH from:
- https://faucet.goerli.starknet.io/
- https://www.alchemy.com/faucets/starknet-sepolia

### "Build failed"
```bash
# Clean and rebuild
scarb clean
scarb build
```

### "RPC connection failed"
Try alternative RPC endpoints in `.env`:
```env
STARKNET_RPC_URL=https://free-rpc.nethermind.io/sepolia-juno/v0_7
```

## Security Notes

- Never commit `.env` file
- Use hardware wallet for mainnet deployments
- Test thoroughly on testnet first
- Review all contract addresses before proceeding
- Keep deployment logs secure

## Support

For detailed documentation, see:
- [Quick Start Guide](../DEPLOY_QUICK_START.md)
- [Full Deployment Guide](../DEPLOYMENT.md)
- [Main README](../README.md)
