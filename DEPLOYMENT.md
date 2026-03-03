# Adam Protocol Deployment Guide

This guide explains how to deploy the Adam Protocol smart contracts to Starknet.

## Prerequisites

1. **Starknet CLI Tools**
   - Install `sncast` (Starknet Foundry): https://foundry-rs.github.io/starknet-foundry/
   - Install `scarb` (Cairo package manager): https://docs.swmansion.com/scarb/

2. **Node.js and Package Manager**
   - Node.js v18 or higher
   - pnpm, npm, or yarn

3. **Starknet Account**
   - Create and fund a Starknet account for deployment
   - Add your account using: `sncast account add`

4. **Environment Variables**
   - Copy `.env.example` to `.env`
   - Fill in your deployer private key and address

## Quick Start

### 1. Install Dependencies

```bash
cd adam-contract
pnpm install  # or npm install
```

### 2. Configure Environment

Edit `.env` file:

```env
# Starknet Account Configuration
DEPLOYER_PRIVATE_KEY=0x...
DEPLOYER_ADDRESS=0x...
DEPLOYER_ACCOUNT=adam-deployer

# Network Configuration
STARKNET_NETWORK=sepolia
STARKNET_RPC_URL=https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_10/5QQMV6kqa3iDaH_EbNhTw

# Contract Addresses (fill after deployment)
TREASURY_ADDRESS=0x...
USDC_ADDRESS=0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7

# Deployment Configuration
DEFAULT_FEE_BPS=30
MAX_FEE_BPS=1000
VERIFIER=walnut
DEPLOYMENT_LOG_DIR=deployment_logs

# Role Configuration
MINTER_ROLE=0x4d494e5445525f524f4c45
BURNER_ROLE=0x4255524e45525f524f4c45

# Contract Names
ADAM_TOKEN_NAME=adam_token
ADAM_POOL_NAME=adam_pool
ADAM_SWAP_NAME=adam_swap

# Token Configuration
ADUSD_NAME=Adam USD
ADUSD_SYMBOL=ADUSD
ADNGN_NAME=Adam NGN
ADNGN_SYMBOL=ADNGN
```

### 3. Deploy Contracts

#### Option A: Using the Bash Script (Recommended)

```bash
# Deploy to Sepolia testnet
./scripts/deploy.sh --usdc 0x<USDC_ADDRESS> --owner 0x<OWNER_ADDRESS>

# Deploy with role setup
./scripts/deploy.sh --usdc 0x<USDC_ADDRESS> --owner 0x<OWNER_ADDRESS> --setup-roles

# Deploy with custom fee (50 bps = 0.5%)
./scripts/deploy.sh --usdc 0x<USDC_ADDRESS> --owner 0x<OWNER_ADDRESS> --fee 50

# Deploy to mainnet
./scripts/deploy.sh --usdc 0x<USDC_ADDRESS> --owner 0x<OWNER_ADDRESS> --network mainnet
```

#### Option B: Using npm/pnpm

```bash
# Deploy to Sepolia
pnpm deploy -- --usdc 0x<USDC_ADDRESS> --owner 0x<OWNER_ADDRESS>

# Deploy to mainnet
pnpm deploy:mainnet -- --usdc 0x<USDC_ADDRESS> --owner 0x<OWNER_ADDRESS>
```

#### Option C: Using TypeScript Directly

```bash
npx ts-node scripts/deploy.ts --usdc 0x<USDC_ADDRESS> --owner 0x<OWNER_ADDRESS>
```

## Deployment Options

### Required Parameters

- `--usdc ADDRESS` - Address of the USDC token contract
- `--owner ADDRESS` - Address that will own all contracts (or set `DEPLOYER_ADDRESS` in `.env`)

### Optional Parameters

- `--treasury ADDRESS` - Treasury address for fees (defaults to owner)
- `--fee BPS` - Transaction fee in basis points (default: $DEFAULT_FEE_BPS = 0.3%, max: $MAX_FEE_BPS = 10%)
- `--network NETWORK` - Network to deploy to (default: $STARKNET_NETWORK)
- `--account ACCOUNT` - Deployer account name (default: $DEPLOYER_ACCOUNT)
- `--rpc-url URL` - Custom RPC URL
- `--setup-roles` - Automatically setup roles and permissions after deployment

## Deployment Process

The deployment script performs the following steps:

1. **Build Contracts** - Compiles all Cairo contracts using `scarb build`
2. **Deploy ADUSD Token** - Deploys the Adam USD stablecoin
3. **Deploy ADNGN Token** - Deploys the Adam NGN stablecoin
4. **Deploy Adam Pool** - Deploys the commitment/nullifier registry
5. **Deploy Adam Swap** - Deploys the main exchange contract
6. **Setup Roles** (if `--setup-roles` flag is used):
   - Grant MINTER_ROLE to swap contract on both tokens
   - Grant BURNER_ROLE to swap contract on both tokens
   - Set swap contract address in pool

## Post-Deployment

### Manual Role Setup

If you didn't use `--setup-roles`, you need to manually configure permissions:

```bash
# Grant MINTER_ROLE to swap contract on ADUSD
sncast --account $DEPLOYER_ACCOUNT invoke \
  --contract-address <ADUSD_ADDRESS> \
  --function grant_role \
  --calldata $MINTER_ROLE <SWAP_ADDRESS>

# Grant BURNER_ROLE to swap contract on ADUSD
sncast --account $DEPLOYER_ACCOUNT invoke \
  --contract-address <ADUSD_ADDRESS> \
  --function grant_role \
  --calldata $BURNER_ROLE <SWAP_ADDRESS>

# Repeat for ADNGN...

# Set swap contract in pool
sncast --account $DEPLOYER_ACCOUNT invoke \
  --contract-address <POOL_ADDRESS> \
  --function set_swap_contract \
  --calldata <SWAP_ADDRESS>
```

### Verify Deployment

Check the `deployment_logs/` directory for:
- Detailed deployment logs
- `deployment_summary_<network>.json` with all contract addresses

### Update Backend Configuration

Update your backend `.env` file with the deployed contract addresses:

```env
ADUSD_ADDRESS=0x...
ADNGN_ADDRESS=0x...
POOL_ADDRESS=0x...
SWAP_ADDRESS=0x...
USDC_ADDRESS=0x...
```

## Contract Architecture

### AdamToken (ADUSD & ADNGN)
- ERC-20 compliant stablecoins
- Mintable/burnable by authorized contracts
- Pausable for emergency stops
- Upgradeable

**Constructor Parameters:**
- `name: ByteArray` - Token name
- `symbol: ByteArray` - Token symbol
- `owner: ContractAddress` - Initial owner with all roles

### AdamPool
- Registry for commitments and nullifiers
- Prevents double-spending
- Only callable by authorized swap contract

**Constructor Parameters:**
- `owner: ContractAddress` - Initial owner with admin role

### AdamSwap
- Main exchange contract
- Handles buy, sell, and swap operations
- Configurable exchange rates and fees
- Role-based access control

**Constructor Parameters:**
- `owner: ContractAddress` - Initial owner with all roles
- `treasury: ContractAddress` - Fee recipient
- `usdc_address: ContractAddress` - USDC token address
- `adusd_address: ContractAddress` - ADUSD token address
- `adngn_address: ContractAddress` - ADNGN token address
- `pool_address: ContractAddress` - Pool contract address
- `fee_bps: u16` - Transaction fee in basis points

## Troubleshooting

### Build Errors

```bash
# Clean and rebuild
scarb clean
scarb build
```

### Account Issues

```bash
# List accounts
sncast account list

# Add new account
sncast account add --name $DEPLOYER_ACCOUNT

# Import existing account
sncast account import --name $DEPLOYER_ACCOUNT --private-key $DEPLOYER_PRIVATE_KEY
```

### RPC Issues

Try alternative RPC endpoints:
- Alchemy: `https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_10/5QQMV6kqa3iDaH_EbNhTw/<API_KEY>`
- Infura: `https://starknet-sepolia.infura.io/v3/<API_KEY>`
- Public: `https://free-rpc.nethermind.io/sepolia-juno/v0_7`

### Insufficient Funds

Ensure your deployer account has enough ETH for:
- Contract declarations
- Contract deployments
- Role setup transactions

Get testnet ETH from:
- Starknet Faucet: https://faucet.goerli.starknet.io/
- Alchemy Faucet: https://www.alchemy.com/faucets/starknet-sepolia

## Network Information

### Sepolia Testnet
- Network ID: `sepolia`
- Chain ID: `SN_SEPOLIA`
- Explorer: https://sepolia.starkscan.co/

### Mainnet
- Network ID: `mainnet`
- Chain ID: `SN_MAIN`
- Explorer: https://starkscan.co/

## Security Considerations

1. **Private Keys** - Never commit `.env` file or expose private keys
2. **Owner Address** - Use a secure multisig wallet for mainnet deployments
3. **Treasury Address** - Consider using a separate treasury wallet
4. **Fee Configuration** - Start with conservative fees (0.3% = 30 bps)
5. **Role Management** - Carefully manage who has minter/burner/admin roles
6. **Testing** - Thoroughly test on testnet before mainnet deployment

## Support

For issues or questions:
- Check deployment logs in `deployment_logs/`
- Review contract tests: `scarb test`
- Consult Starknet documentation: https://docs.starknet.io/
