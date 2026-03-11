# Adam Protocol Contracts

Scarb workspace containing three Cairo 2.x smart contracts for the Adam Protocol, a privacy-first stablecoin system on Starknet.

## Workspace Structure

```
adam-contract/
├── Scarb.toml                  # Workspace root
├── package.json                # Script dependencies (Starknet.js)
├── scripts/
│   └── deploy.ts               # Deployment script
└── packages/
    ├── adam_token/             # ERC-20 (deployed as ADUSD & ADNGN)
    ├── adam_pool/              # Nullifier registry (double-spend prevention)
    └── adam_swap/              # Buy / Sell / Swap logic
```

> [!NOTE]
> All shared logic (errors, events, interfaces) has been inlined into each package to ensure they are self-contained and modular.

## Contracts

### `AdamToken`
Standard upgradeable ERC-20. Deployed **twice** — once as ADUSD, once as ADNGN.

| Role | Holder | Permission |
|---|---|---|
| `DEFAULT_ADMIN_ROLE` | Deployer | Grant roles |
| `MINTER_ROLE` | AdamSwap | `mint()` |
| `BURNER_ROLE` | AdamSwap | `burn()` |
| `PAUSER_ROLE` | Deployer | `pause()` / `unpause()` |
| `UPGRADER_ROLE` | Deployer | `upgrade(new_class_hash)` |

### `AdamPool`
Nullifier registry. Tracks Pedersen commitments and spent nullifiers.

- `register_commitment(commitment, token)` — called by AdamSwap on every buy/swap
- `spend_nullifier(nullifier)` — called by AdamSwap on every sell
- Double-spend panics with `'adam: nullifier spent'`

### `AdamSwap`
Core exchange contract. Upgradeable.

| Function | Description |
|---|---|
| `buy(token_in, amount_in, token_out, commitment)` | Deposit USDC → mint ADUSD/ADNGN |
| `sell(token_in, amount, nullifier, commitment)` | Burn ADUSD/ADNGN → triggers backend offramp |
| `swap(token_in, amount_in, token_out, min_out, commitment)` | ADUSD ↔ ADNGN at live rate |
| `set_rate(from, to, rate)` | Rate setter (backend service wallet, `RATE_SETTER_ROLE`) |

## Privacy

All `buy`, `sell`, and `swap` events emit **only commitment/nullifier hashes** — never amounts. Amounts are computed client-side and committed via `pedersen(amount, secret)`.

## Development

```bash
# Build all packages
scarb build

# Test all packages (snforge required)
snforge test

# Test a single package
cd packages/adam_token && snforge test
```

## Deployment

### Quick Start

```bash
# Install dependencies
pnpm install

# Check your environment configuration
./scripts/check-env.sh

# Deploy to testnet with automatic role setup
./scripts/deploy.sh --usdc $USDC_ADDRESS --owner $DEPLOYER_ADDRESS --setup-roles
```

### Documentation

- **[Quick Start Guide](./DEPLOY_QUICK_START.md)** - Deploy in 5 minutes
- **[Full Deployment Guide](./DEPLOYMENT.md)** - Comprehensive documentation
- **[Role Setup Script](./scripts/setup-roles.sh)** - Configure permissions separately

### What the Script Does

1. Builds all contracts with `scarb build`
2. Declares all contract classes to Starknet
3. Deploys ADUSD, ADNGN, AdamPool, and AdamSwap
4. Optionally configures roles (with `--setup-roles` flag):
   - Grants MINTER_ROLE to AdamSwap on both tokens
   - Grants BURNER_ROLE to AdamSwap on both tokens
   - Sets swap contract address in pool
5. Saves deployment summary to `deployment_logs/deployment_summary_<network>.json`

### Deployment Options

```bash
# Basic deployment
./scripts/deploy.sh --usdc 0x... --owner 0x...

# With custom fee (0.5%)
./scripts/deploy.sh --usdc 0x... --owner 0x... --fee 50

# Deploy to mainnet
./scripts/deploy.sh --usdc 0x... --owner 0x... --network mainnet

# Using npm/pnpm
pnpm deploy -- --usdc 0x... --owner 0x...
```
