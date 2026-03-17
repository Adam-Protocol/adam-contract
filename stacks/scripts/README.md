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

### init-v2-manual.md
**Purpose**: Step-by-step manual initialization guide for deployed contracts

**Contains**:
- Contract initialization commands
- Role setup (minter, burner, admin, pauser)
- Exchange rate configuration
- Verification steps

**When to use**: After running `deploy-complete.sh`, follow this guide to initialize and configure the deployed contracts.

## USDCX Utility Scripts

These scripts are for managing the test USDC token (USDCX) used in development and testing.

### deploy-usdcx.ts
**Purpose**: Deploy USDCX test token to testnet

**Usage**:
```bash
npx tsx scripts/deploy-usdcx.ts
```

**Requirements**: 
- Node.js and npm installed
- STACKS_DEPLOYER_PRIVATE_KEY in .env file
- Testnet STX for deployment fees

### quick-deploy-usdcx.sh
**Purpose**: Quick deployment wrapper for USDCX

**Usage**:
```bash
./scripts/quick-deploy-usdcx.sh
```

### mint-usdcx.ts
**Purpose**: Mint USDCX tokens to a specified address

**Usage**:
```bash
npx tsx scripts/mint-usdcx.ts <recipient-address> <amount>
```

**Example**:
```bash
# Mint 1000 USDCX to wallet
npx tsx scripts/mint-usdcx.ts ST2NEB84ASENDXKYGJPQW86YXQCEFEX2ZQPG87ND 1000000000
```

### check-usdcx-balance.ts
**Purpose**: Check USDCX balance for an address

**Usage**:
```bash
npx tsx scripts/check-usdcx-balance.ts <address>
```

**Example**:
```bash
npx tsx scripts/check-usdcx-balance.ts ST2NEB84ASENDXKYGJPQW86YXQCEFEX2ZQPG87ND
```

## Deployment Workflow

### For New Deployments

1. **Prepare environment**:
   ```bash
   # Ensure .env has your deployer key
   echo 'STACKS_DEPLOYER_PRIVATE_KEY="your mnemonic here"' > .env
   ```

2. **Get testnet STX**:
   - Visit: https://explorer.hiro.so/sandbox/faucet?chain=testnet
   - Request STX for your deployer address

3. **Run complete deployment**:
   ```bash
   ./scripts/deploy-complete.sh testnet
   ```

4. **Initialize contracts**:
   - Follow instructions in `scripts/init-v2-manual.md`
   - Use Stacks Explorer or clarinet console

5. **Deploy USDCX (if needed)**:
   ```bash
   ./scripts/quick-deploy-usdcx.sh
   ```

6. **Test the system**:
   ```bash
   # Mint test USDCX
   npx tsx scripts/mint-usdcx.ts <your-address> 1000000000
   
   # Check balance
   npx tsx scripts/check-usdcx-balance.ts <your-address>
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
