# adam-contract — Claude Context

## What This Is

Smart contract suite for Adam Protocol, split across two chains:

| Sub-directory | Chain | Language | Toolchain |
|---|---|---|---|
| `starknet/` | Starknet (Sepolia testnet / Mainnet) | Cairo | Scarb + Starknet Foundry (`snforge`) |
| `stacks/` | Stacks (testnet / mainnet) | Clarity | Clarinet 2.0 |

Both chains implement the same three logical contracts: **token**, **pool**, and **swap** — but with different privacy properties (see below).

---

## starknet/ — Cairo Contracts

### Workspace Layout (`Scarb.toml`)

```
starknet/
├── Scarb.toml                  # Workspace definition
├── packages/
│   ├── adam-token/             # ERC-20 base (ADUSD & ADNGN)
│   │   └── src/adam_token.cairo
│   ├── adam-pool/              # Nullifier registry (privacy)
│   │   └── src/adam_pool.cairo
│   └── adam-swap/              # Exchange logic
│       └── src/adam_swap.cairo
└── scripts/
    ├── deploy.sh               # Full deployment + role setup
    └── ...
```

**Dependencies** (managed in `Scarb.toml`):
- `starknet = "2.15.0"`
- `openzeppelin = "2.0.0"` — ERC20, AccessControl, Pausable, Upgradeable
- `snforge_std = "0.54.1"` — test utilities

### Contract Architecture

#### AdamToken (`packages/adam-token`)
- ERC-20 token deployed twice: once as **ADUSD**, once as **ADNGN**.
- Custom `decimals` stored in contract storage (configurable at deploy time; currently 6).
- OpenZeppelin components: `ERC20`, `PausableComponent`, `AccessControlComponent`, `UpgradeableComponent`.
- **Roles**:
  | Role | Capability |
  |---|---|
  | `DEFAULT_ADMIN_ROLE` | Grant/revoke all roles |
  | `MINTER_ROLE` | `mint(recipient, amount)` |
  | `BURNER_ROLE` | `burn(from, amount)` |
  | `PAUSER_ROLE` | `pause()` / `unpause()` |
  | `UPGRADER_ROLE` | `upgrade(new_class_hash)` |

- Mint/burn are protected — only the **AdamSwap** contract should hold these roles in production.

#### AdamPool (`packages/adam-pool`)
- Commitment / nullifier registry — core of Starknet privacy.
- On `buy`: registers a commitment hash on-chain.
- On `sell`: checks the nullifier has not been spent, then marks it spent.
- No token logic here — purely a registry.

#### AdamSwap (`packages/adam-swap`)
- Orchestrates buy, sell, and swap operations.
- Holds `MINTER_ROLE` and `BURNER_ROLE` on both token contracts.
- Reads live USD/NGN rate from storage (set by `RATE_SETTER_ROLE`).
- Dynamically adjusts for token decimal differences during swaps.

### Building & Testing

```bash
cd adam-contract/starknet
scarb build           # Compile all packages
snforge test          # Run all tests
snforge test -p adam-token  # Test a single package
```

### Deployment

```bash
./scripts/deploy.sh \
  --usdc $USDC_ADDRESS \
  --owner $DEPLOYER_ADDRESS \
  --setup-roles
```

After deploying, always run `pnpm run verify-roles` from `adam-backend` to confirm role assignments.

The Alchemy Sepolia RPC is pre-configured in `Scarb.toml` under `[tool.sncast.sepolia]`.

### Key Conventions (Cairo)

1. **Decimals**: Contracts store decimals dynamically. Do **not** assume 18. Use `IERC20MetadataDispatcher` to query decimals before scaling amounts.
2. **Roles over ownership**: No `Ownable` pattern — all access is via `AccessControl`. Grant the minimal required role.
3. **Upgradeable pattern**: Use `UpgradeableComponent` for all contracts. The `UPGRADER_ROLE` holder can call `upgrade(new_class_hash)`. Keep upgrade logic separate from business logic.
4. **Error handling**: All errors use the `Errors` module constants (e.g., `Errors::ZERO_ADDRESS`, `Errors::ZERO_AMOUNT`). Add new errors there.
5. **Testing**: Use `snforge_std` cheatcodes (`start_prank`, `stop_prank`, `start_mock_call`) to simulate callers and contract responses. Never test without mocking caller addresses.

---

## stacks/ — Clarity Contracts

### Layout

```
stacks/
├── Clarinet.toml               # Project config
├── contracts/
│   ├── adam-token-v3.clar      # SIP-010 fungible token
│   ├── adam-swap-v3.clar       # Swap & exchange logic
│   ├── usdcx-v3.clar           # Mock USDC for testing
│   └── traits/                 # SIP-010 trait definition
├── tests/                      # Vitest test files
├── scripts/                    # Deployment scripts
│   └── deploy-complete.sh
└── deployments/                # Deployment artifacts (addresses)
```

### Contract Architecture

#### adam-token-v3 (SIP-010 Token)
- Implements the `ft-trait` (SIP-010 standard).
- Transparent — all amounts are visible on-chain.
- Deployed as ADUSD and ADNGN (separate deployments).
- **6 decimals** (aligned with Starknet implementation and USDC).
- Mint/burn protected by contract owner.

#### adam-swap-v3
- Buy: user sends STX/USDC, receives minted ADUSD/ADNGN.
- Sell: user burns tokens, triggers backend to initiate fiat transfer.
- Swap: ADUSD ↔ ADNGN at live rate.
- Exchange rate stored in contract storage; updated by the deployer/rate-setter address.

#### usdcx-v3
- Mock USDC for testnet. Mintable by anyone — testing only.

### Building & Testing

```bash
cd adam-contract/stacks
clarinet check          # Type-check all contracts
clarinet test           # Run all tests (Simnet)
```

Tests use **Vitest** + `@hirosystems/clarinet-sdk`. See `vitest.config.ts`.

### Deployment

```bash
./scripts/deploy-complete.sh testnet
pnpm run init           # Initialize contracts (set rates, grant roles)
```

After deployment, contract addresses are written to `deployments/`. Update `adam-backend/.env` and `adam-app/.env` accordingly.

### Key Conventions (Clarity)

1. **Decidable language**: Clarity is interpreted and decidable — no loops with unbounded iteration required. Keep functions simple.
2. **Post-conditions**: Use `(as-contract ...)` and `(contract-call? ...)` post-conditions to prevent unexpected token transfers.
3. **Principal checks**: Always assert `(is-eq tx-sender expected-principal)` for admin operations.
4. **No private keys in scripts**: Deploy scripts read keys from `.env`. Never hard-code them.
5. **Decimal alignment**: Both `adam-token-v3` and the Starknet `AdamToken` use 6 decimals. Keep them in sync.

---

## Cross-Chain Notes

- Both chains expose the same **logical API** (buy, sell, swap) but the implementations differ significantly.
- The `adam-backend` abstracts these via `StarknetService` and `StacksService`.
- When updating contract interfaces, update **both** the contract and the corresponding backend service method signatures.
- Exchange rates must be kept in sync across chains (the backend pushes rates to both chains separately).

---

## Security Checklist (Before Mainnet)

- [ ] All minter/burner roles granted **only** to swap contract (not deployer EOA)
- [ ] Admin role transferred to a multisig
- [ ] Rate-setter role validated via `pnpm run verify-roles`
- [ ] Contracts audited externally
- [ ] Deployment done from a hardware wallet
- [ ] Testnet smoke tests passing across both chains
