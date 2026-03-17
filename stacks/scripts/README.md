# Adam Protocol Stacks Scripts

This directory contains deployment and utility scripts for the Adam Protocol Stacks contracts.

## Main Deployment Scripts

### deploy-complete.sh
**Purpose**: Complete deployment workflow for Adam Protocol contracts

**Usage**:
```bash
./scripts/deploy-complete.sh [network] [treasury-address] [version]
```

**Parameters**:
- `network`: testnet or mainnet (default: testnet)
- `treasury-address`: Address to receive fees (optional)
- `version`: Contract version suffix (default: v2)

**What it does**:
1. Validates all contracts with `clarinet check`
2. Runs test suite
3. Generates deployment plan
4. Deploys contracts to specified network
5. Provides post-deployment instructions

**Example**:
```bash
# Deploy to testnet
./scripts/deploy-complete.sh testnet

# Deploy to mainnet with custom treasury
./scripts/deploy-complete.sh mainnet ST2TREASURY123... v2
```

### initialize-contracts.ts
**Purpose**: Automated initialization of deployed contracts with all necessary configuration

**Usage**:
```bash
pnpm run init
```

**What it does**:
1. Initializes all token contracts (ADUSD, ADNGN, ADKES, ADGHS, ADZAR)
2. Initializes swap contract with treasury and fee settings
3. Grants minter roles to swap contract
4. Grants burner roles to swap contract
5. Sets all exchange rates from .env configuration
6. Grants rate-setter role to backend (if configured)

**Configuration**: All settings are read from `.env` file:
- `STACKS_TREASURY_ADDRESS` - Treasury for fee collection
- `STACKS_BACKEND_ADDRESS` - Backend service for rate updates
- `SWAP_FEE_BPS` - Transaction fee (50 = 0.5%)
- `RATE_*` - Exchange rates for all token pairs
- `STACKS_NETWORK` - testnet or mainnet

**Example**:
```bash
# Configure .env first, then run
pnpm run init
```

### init-v2-manual.md
**Purpose**: Step-by-step manual initialization guide for deployed contracts

**Contains**:
- Contract initialization commands
- Role setup (minter, burner, admin, pauser)
- Exchange rate configuration
- Verification steps

**When to use**: If you prefer manual control or the automated script fails.

## USDCX Utility Scripts

These scripts are for managing the test USDC token (USDCX) used in development and testing.

### usdcx-manager.ts
**Purpose**: All-in-one USDCX token management tool

**Usage**:
```bash
# Show help
pnpm run usdcx

# Deploy USDCX contract
pnpm run usdcx:deploy

# Mint tokens to an address
pnpm run usdcx:mint <recipient-address> <amount>

# Check balance
pnpm run usdcx:balance <address>

# Quick setup (deploy + mint + check)
pnpm run usdcx:quick
```

**Examples**:
```bash
# Deploy USDCX
pnpm run usdcx:deploy

# Mint 1000 USDCX to wallet
pnpm run usdcx:mint ST2NEB84ASENDXKYGJPQW86YXQCEFEX2ZQPG87ND 1000000000

# Check balance
pnpm run usdcx:balance ST2NEB84ASENDXKYGJPQW86YXQCEFEX2ZQPG87ND

# Complete setup in one command
pnpm run usdcx:quick
```

**Requirements**: 
- Node.js and pnpm installed
- STACKS_DEPLOYER_PRIVATE_KEY in .env file
- Testnet STX for deployment fees

## Deployment Workflow

### For New Deployments

1. **Prepare environment**:
   ```bash
   # Copy example and configure
   cp .env.example .env
   
   # Edit .env with your values:
   # - STACKS_DEPLOYER_PRIVATE_KEY (required)
   # - STACKS_TREASURY_ADDRESS (optional, defaults to deployer)
   # - STACKS_BACKEND_ADDRESS (optional, for rate-setter role)
   # - Exchange rates (optional, defaults provided)
   ```

2. **Get testnet STX**:
   - Visit: https://explorer.hiro.so/sandbox/faucet?chain=testnet
   - Request STX for your deployer address

3. **Run complete deployment**:
   ```bash
   ./scripts/deploy-complete.sh testnet
   ```

4. **Initialize contracts automatically**:
   ```bash
   pnpm run init
   ```
   
   This will:
   - Initialize all tokens
   - Initialize swap with treasury
   - Grant all necessary roles
   - Set exchange rates
   - Configure backend access (if specified)

5. **Deploy USDCX (if needed)**:
   ```bash
   pnpm run usdcx:quick
   ```

6. **Test the system**:
   ```bash
   # Mint test USDCX
   pnpm run usdcx:mint <your-address> 1000000000
   
   # Check balance
   pnpm run usdcx:balance <your-address>
   
   # Test buy operation via frontend or backend
   ```

### For Updates

Since Stacks contracts are immutable:
1. Deploy new versions with different names (e.g., -v3)
2. Update Clarinet.toml with new contract entries
3. Run `deploy-complete.sh` again
4. Migrate users from old to new contracts

## Environment Variables

Required in `.env`:
```env
STACKS_DEPLOYER_PRIVATE_KEY="your twenty four word mnemonic phrase"
```

Optional:
```env
TREASURY_ADDRESS="ST..."  # Custom treasury for fees
```

## Network Endpoints

**Testnet**:
- RPC: https://api.testnet.hiro.so
- Explorer: https://explorer.hiro.so/?chain=testnet
- Faucet: https://explorer.hiro.so/sandbox/faucet?chain=testnet

**Mainnet**:
- RPC: https://api.hiro.so
- Explorer: https://explorer.hiro.so/?chain=mainnet

## Troubleshooting

### "Contract already exists" error
- Deploy with new contract name (add version suffix)
- Or use different deployer address

### "Insufficient STX" error
- Get more testnet STX from faucet
- For mainnet, ensure sufficient balance for fees

### "Runtime error" during initialization
- Check contract is deployed successfully
- Verify you're calling from correct address
- Check function parameters match expected types

### Tests failing
- Run `npm install` to ensure dependencies are up to date
- Check contract syntax with `clarinet check`
- Review test output for specific errors

## Support

For issues or questions:
- GitHub: https://github.com/Adam-Protocol/adam-contract
- Documentation: See DEPLOYMENT.md for detailed guide
