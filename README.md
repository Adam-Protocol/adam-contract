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

Deployment is handled via a TypeScript script using `Starknet.js`.

1. Install dependencies: `npm install`
2. Configure `.env` with `DEPLOYER_ADDRESS`, `DEPLOYER_PRIVATE_KEY`, `STARKNET_RPC_URL` etc.
3. Run deploy: `npm run deploy`

The script will:
1. Declare all contract classes.
2. Deploy ADUSD, ADNGN, AdamPool, and AdamSwap.
3. Automatically configure roles (granting AdamSwap mint/burn permissions).
4. Save deployment details to `scripts/deployment.json`.
