# Adam Protocol - Stacks Contracts

Bitcoin-secured transparent stablecoin system on Stacks blockchain.

> [!NOTE]
> **Privacy vs Transparency**: Unlike the Starknet implementation which uses zero-knowledge proofs for privacy, the Stacks implementation provides transparent, Bitcoin-secured stablecoins. Transaction amounts are visible on-chain, providing regulatory clarity while leveraging Bitcoin's security.

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

**Transparency Note**: All balances and transfers are visible on-chain, providing regulatory clarity and Bitcoin-level security.

**Roles:**
- `contract-owner` - Can grant/revoke roles, upgrade contract
- `minter` - Can mint new tokens (typically AdamSwap contract)
- `burner` - Can burn tokens (typically AdamSwap contract)

**Key Functions:**
- `mint` - Create new tokens (minter only)
- `burn` - Destroy tokens (burner only)
- `transfer` - Standard SIP-010 transfer
- `get-balance` - Check token balance

### AdamSwap

Core exchange contract handling all buy/sell/swap operations.

**Key Functions:**
- `buy` - Purchase Adam stablecoins with USDC (amounts visible on-chain)
- `sell` - Redeem Adam stablecoins (triggers backend offramp)
- `swap` - Exchange between Adam stablecoins (e.g., ADUSD ↔ ADNGN)
- `set-rate` - Update exchange rates (rate-setter only)

**Transparency:**
All operations emit transaction amounts on-chain. This provides regulatory clarity and allows for standard blockchain explorers to track transactions. No privacy layer is implemented on Stacks.

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
- Bitcoin-secured through Stacks blockchain
- Transparent transactions for regulatory compliance
- Rate updates require dedicated rate-setter role
- No privacy features - all amounts visible on-chain

## License

MIT
