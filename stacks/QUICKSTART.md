# Adam Protocol Stacks - Quick Start Guide

Get your Adam Protocol contracts deployed and running in minutes.

## Prerequisites

- Clarinet installed
- Node.js and pnpm installed
- Testnet STX (get from [faucet](https://explorer.hiro.so/sandbox/faucet?chain=testnet))

## Quick Deployment (3 Steps)

### 1. Configure Environment

```bash
cd adam-contract/stacks
cp .env.example .env
```

Edit `.env` and set your mnemonic:
```env
STACKS_DEPLOYER_PRIVATE_KEY="your twenty four word mnemonic phrase"
STACKS_TREASURY_ADDRESS="STY1..."  # Optional, defaults to deployer
```

### 2. Deploy Contracts

```bash
./scripts/deploy-complete.sh testnet
```

This will:
- Validate contracts
- Run tests
- Deploy all contracts to testnet
- Show deployment summary

### 3. Initialize Contracts

```bash
pnpm run init
```

This automatically:
- Initializes all 5 token contracts
- Initializes swap contract with treasury
- Grants minter/burner roles
- Sets all exchange rates
- Configures backend access (if specified)

**Done!** Your contracts are ready to use.

## Verify Deployment

Check your contracts on Stacks Explorer:
```
https://explorer.hiro.so/address/<YOUR_ADDRESS>?chain=testnet
```

## Test USDCX Setup (Optional)

If you need test USDC tokens:

```bash
# Deploy and mint USDCX in one command
pnpm run usdcx:quick

# Or step by step:
pnpm run usdcx:deploy
pnpm run usdcx:mint <address> 1000000000
pnpm run usdcx:balance <address>
```

## Update Your Apps

### Backend (.env)
```env
STACKS_NETWORK=testnet
STACKS_ADUSD_CONTRACT=<YOUR_ADDRESS>.adam-token-adusd-v2
STACKS_ADNGN_CONTRACT=<YOUR_ADDRESS>.adam-token-adngn-v2
STACKS_ADKES_CONTRACT=<YOUR_ADDRESS>.adam-token-adkes-v2
STACKS_ADGHS_CONTRACT=<YOUR_ADDRESS>.adam-token-adghs-v2
STACKS_ADZAR_CONTRACT=<YOUR_ADDRESS>.adam-token-adzar-v2
STACKS_SWAP_CONTRACT=<YOUR_ADDRESS>.adam-swap-v2
STACKS_USDCX_CONTRACT=<YOUR_ADDRESS>.usdcx
```

### Frontend (config.ts)
Update your chain configuration with the V2 contract addresses.

## Test Your Deployment

1. **Check USDCX balance**:
   ```bash
   pnpm run usdcx:balance <your-address>
   ```

2. **Test buy operation**:
   - Use your frontend or backend API
   - Buy small amount (e.g., 1 USDC worth)
   - Verify tokens minted
   - Verify treasury received USDC

3. **Test swap operation**:
   - Swap between Adam tokens
   - Verify exchange rate applied correctly
   - Verify fee deducted

## Configuration Reference

All settings in `.env`:

| Variable | Description | Default |
|----------|-------------|---------|
| `STACKS_DEPLOYER_PRIVATE_KEY` | 24-word mnemonic | Required |
| `STACKS_TREASURY_ADDRESS` | Fee collection address | Deployer |
| `STACKS_BACKEND_ADDRESS` | Backend service address | None |
| `SWAP_FEE_BPS` | Transaction fee (basis points) | 50 (0.5%) |
| `RATE_USDC_ADUSD` | USDC to ADUSD rate | 1:1 |
| `RATE_USDC_ADNGN` | USDC to ADNGN rate | 1:1500 |
| `RATE_USDC_ADKES` | USDC to ADKES rate | 1:150 |
| `RATE_USDC_ADGHS` | USDC to ADGHS rate | 1:15 |
| `RATE_USDC_ADZAR` | USDC to ADZAR rate | 1:18 |
| `STACKS_NETWORK` | Network to use | testnet |

## Troubleshooting

**"Contract already exists"**
- Contracts are already deployed
- Run `pnpm run init` to initialize them

**"Insufficient STX"**
- Get more from testnet faucet
- Each deployment costs ~0.5 STX

**"Transaction failed"**
- Check transaction on explorer
- Verify calling from correct address
- Ensure contract is confirmed first

## Need More Details?

- Full documentation: `DEPLOYMENT.md`
- Script reference: `scripts/README.md`
- Manual initialization: `scripts/init-v2-manual.md`
