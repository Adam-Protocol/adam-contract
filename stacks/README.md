# Adam Protocol - Stacks Contracts

Privacy-first stablecoin system on Stacks blockchain, implementing the same architecture as the Starknet deployment.

## Overview

The Adam Protocol on Stacks consists of three core smart contracts written in Clarity:

- **adam-token** - SIP-010 compliant fungible token (deployed as ADUSD, ADNGN, etc.)
- **adam-pool** - Nullifier registry for double-spend prevention
- **adam-swap** - Core exchange logic for buy/sell/swap operations

## Architecture

```
adam-contract/stacks/
├── contracts/
│   ├── adam-token.clar          # SIP-010 token with mint/burn
│   ├── adam-pool.clar           # Commitment & nullifier registry
│   ├── adam-swap.clar           # Exchange contract
│   └── traits/
│       └── sip-010-trait.clar   # Standard token trait
├── tests/
│   ├── adam-token_test.clar
│   ├── adam-pool_test.clar
│   └── adam-swap_test.clar
├── settings/
│   ├── Devnet.toml
│   ├── Testnet.toml
│   └── Mainnet.toml
├── Clarinet.toml
└── README.md
```

## Contracts

### AdamToken

Standard SIP-010 fungible token with role-based access control. Deployed multiple times for different currencies (ADUSD, ADNGN, ADKES, ADGHS, ADZAR).

**Roles:**
- `contract-owner` - Can grant/revoke roles, upgrade contract
- `minter` - Can mint new tokens (typically AdamSwap contract)
- `burner` - Can burn tokens (typically AdamSwap contract)

**Key Functions:**
- `mint` - Create new tokens (minter only)
- `burn` - Destroy tokens (burner only)
- `transfer` - Standard SIP-010 transfer
- `get-balance` - Check token balance

### AdamPool

Nullifier registry that prevents double-spending through commitment tracking.

**Key Functions:**
- `register-commitment` - Record a new commitment (swap contract only)
- `spend-nullifier` - Mark a nullifier as spent (swap contract only)
- `is-commitment-registered` - Check if commitment exists
- `is-nullifier-spent` - Check if nullifier was used

### AdamSwap

Core exchange contract handling all buy/sell/swap operations with privacy-preserving commitments.

**Key Functions:**
- `buy` - Purchase Adam stablecoins with USDC
- `sell` - Redeem Adam stablecoins (triggers backend offramp)
- `swap` - Exchange between Adam stablecoins (e.g., ADUSD ↔ ADNGN)
- `set-rate` - Update exchange rates (rate-setter only)

**Privacy:**
All operations emit only commitment/nullifier hashes, never amounts. Amounts are computed client-side using Pedersen commitments.

## Development

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) v2.0+
- Stacks CLI (optional, for deployment)

### Setup

```bash
cd adam-contract/stacks
clarinet check
```

### Testing

Run all tests:
```bash
clarinet test
```

Run specific test file:
```bash
clarinet test tests/adam-token_test.clar
```

### Local Development

Start a local devnet:
```bash
clarinet integrate
```

## Deployment

### Testnet Deployment

1. Configure your testnet account in `settings/Testnet.toml`
2. Request testnet STX from the [faucet](https://explorer.hiro.so/sandbox/faucet?chain=testnet)
3. Generate deployment plan:
```bash
clarinet deployments generate --testnet
```
4. Deploy contracts:
```bash
clarinet deployments apply --testnet
```

### Mainnet Deployment

1. **Security checklist:**
   - Complete security audit
   - Test thoroughly on testnet
   - Backup deployment keys
   - Use hardware wallet for deployment

2. Generate mainnet deployment plan:
```bash
clarinet deployments generate --mainnet --high-cost
```

3. Deploy to mainnet:
```bash
clarinet deployments apply --mainnet
```

## Post-Deployment Setup

After deploying all contracts, you need to configure roles and permissions:

1. **Grant minter role to AdamSwap on all tokens:**
```clarity
(contract-call? .adam-token-adusd set-minter .adam-swap true)
(contract-call? .adam-token-adngn set-minter .adam-swap true)
```

2. **Grant burner role to AdamSwap on all tokens:**
```clarity
(contract-call? .adam-token-adusd set-burner .adam-swap true)
(contract-call? .adam-token-adngn set-burner .adam-swap true)
```

3. **Set swap contract in pool:**
```clarity
(contract-call? .adam-pool set-swap-contract .adam-swap)
```

4. **Initialize exchange rates in AdamSwap:**
```clarity
;; USDC -> ADUSD (1:1)
(contract-call? .adam-swap set-rate .usdc-token .adam-token-adusd u1000000000000000000)
```

## Security Considerations

- All contracts are immutable once deployed
- Role-based access control protects critical functions
- Nullifier registry prevents double-spending
- Privacy preserved through commitment-only events
- Rate updates require dedicated rate-setter role

## License

MIT
