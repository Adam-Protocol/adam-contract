# Stacks vs Starknet Implementation Comparison

This document compares the Stacks (Clarity) and Starknet (Cairo) implementations of Adam Protocol.

## Architecture Parity

Both implementations follow the same three-contract architecture:

| Component | Starknet | Stacks | Purpose |
|-----------|----------|--------|---------|
| Token | `adam_token` | `adam-token` | SIP-010/ERC-20 fungible token |
| Pool | `adam_pool` | `adam-pool` | Nullifier registry |
| Swap | `adam_swap` | `adam-swap` | Exchange logic |

## Language Differences

### Cairo (Starknet)

```cairo
#[starknet::contract]
pub mod AdamToken {
    use openzeppelin::token::erc20::ERC20Component;
    
    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
    }
}
```

### Clarity (Stacks)

```clarity
(define-fungible-token adam-token)

(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-minter tx-sender) ERR-NOT-MINTER)
    (ft-mint? adam-token amount recipient)
  )
)
```

## Key Differences

### 1. Type System

**Starknet (Cairo)**
- Strongly typed with explicit types
- `u256`, `felt252`, `ContractAddress`
- Struct-based storage

**Stacks (Clarity)**
- Strongly typed with inference
- `uint`, `principal`, `(buff 32)`
- Map-based storage

### 2. Access Control

**Starknet**
```cairo
use openzeppelin::access::accesscontrol::AccessControlComponent;
self.accesscontrol.assert_only_role(MINTER_ROLE);
```

**Stacks**
```clarity
(define-map minters principal bool)
(asserts! (is-minter tx-sender) ERR-NOT-MINTER)
```

### 3. Error Handling

**Starknet**
```cairo
assert(!owner.is_zero(), Errors::ZERO_ADDRESS);
```

**Stacks**
```clarity
(define-constant ERR-ZERO-ADDRESS (err u104))
(asserts! (not (is-eq recipient 'SP000000000000000000002Q6VF78)) ERR-ZERO-ADDRESS)
```

### 4. Events

**Starknet**
```cairo
#[derive(Drop, starknet::Event)]
pub struct CommitmentRegistered {
    #[key]
    pub commitment: felt252,
    pub token: ContractAddress,
    pub timestamp: u64,
}
```

**Stacks**
```clarity
(print { 
  event: "buy",
  commitment: commitment,
  token-out: token-out,
  block-height: block-height
})
```

### 5. Contract Calls

**Starknet**
```cairo
IAdamTokenDispatcher { contract_address: token_out }.mint(caller, amount_out);
```

**Stacks**
```clarity
(contract-call? token-out mint amount-out caller)
```

## Feature Parity Matrix

| Feature | Starknet | Stacks | Notes |
|---------|----------|--------|-------|
| SIP-010/ERC-20 | ✅ | ✅ | Standard token interface |
| Mint/Burn | ✅ | ✅ | Role-based access |
| Pausable | ✅ | ⚠️ | Not implemented in Stacks (can be added) |
| Upgradeable | ✅ | ❌ | Clarity contracts are immutable |
| Commitment Registry | ✅ | ✅ | Identical functionality |
| Nullifier Tracking | ✅ | ✅ | Identical functionality |
| Buy/Sell/Swap | ✅ | ✅ | Same logic |
| Rate Management | ✅ | ✅ | Same precision (1e18) |
| Fee Management | ✅ | ✅ | Basis points (BPS) |
| Privacy Events | ✅ | ✅ | Commitment-only emissions |

## Storage Patterns

### Starknet Storage

```cairo
#[storage]
struct Storage {
    commitments: Map<felt252, bool>,
    nullifiers: Map<felt252, bool>,
    swap_contract: ContractAddress,
}
```

### Stacks Storage

```clarity
(define-map commitments 
  (buff 32) 
  {
    registered: bool,
    token: principal,
    timestamp: uint
  }
)

(define-data-var swap-contract (optional principal) none)
```

## Testing Approaches

### Starknet (snforge)

```cairo
#[test]
fn test_mint_success() {
    let token_addr = deploy_adam_token("Adam USD", "ADUSD", owner());
    let token = IAdamTokenDispatcher { contract_address: token_addr };
    
    start_cheat_caller_address(token_addr, owner());
    token.mint(alice(), 1000);
    stop_cheat_caller_address(token_addr);
    
    assert(token.balance_of(alice()) == 1000, 'wrong balance');
}
```

### Stacks (Clarinet)

```clarity
(define-public (test-mint-success)
  (let
    (
      (mint-result (contract-call? .adam-token-adusd mint u1000000 wallet-1))
      (balance (unwrap-panic (contract-call? .adam-token-adusd get-balance wallet-1)))
    )
    (asserts! (is-ok mint-result) (err u10))
    (asserts! (is-eq balance u1000000) (err u11))
    (ok true)
  )
)
```

## Deployment Differences

### Starknet

- Uses Scarb for building
- Declares class hash first
- Deploys instances from class
- Can upgrade contracts
- Uses Starknet.js for scripting

### Stacks

- Uses Clarinet for building
- Deploys contract code directly
- Immutable after deployment
- No upgrade mechanism
- Uses Stacks.js for scripting

## Gas/Fee Considerations

### Starknet

- Gas fees in ETH (L1) or STRK (L2)
- Lower fees due to L2 scaling
- Batch transactions for efficiency

### Stacks

- Fees in STX
- Anchored to Bitcoin security
- Fee estimation via Clarinet

## Security Considerations

### Both Implementations

✅ Role-based access control
✅ Zero-amount checks
✅ Zero-address validation
✅ Nullifier double-spend prevention
✅ Commitment uniqueness
✅ Privacy-preserving events

### Starknet-Specific

✅ Pausable for emergency stops
✅ Upgradeable for bug fixes
⚠️ Upgrade risk if keys compromised

### Stacks-Specific

✅ Immutable (no upgrade risk)
✅ Bitcoin-anchored finality
⚠️ No pause mechanism (add if needed)
⚠️ No upgrades (must redeploy)

## Recommendations

### When to Use Starknet

- Need upgradeability
- Want pause functionality
- Prefer lower transaction fees
- Building on Ethereum ecosystem

### When to Use Stacks

- Want immutability guarantee
- Prefer Bitcoin security model
- Building on Bitcoin ecosystem
- Don't need upgrades

## Migration Path

If migrating between chains:

1. **State Export**: Export commitments and nullifiers
2. **Rate Sync**: Ensure exchange rates match
3. **User Migration**: Provide bridge or migration tool
4. **Gradual Rollout**: Test with small amounts first

## Conclusion

Both implementations provide equivalent functionality with different trade-offs:

- **Starknet**: More flexible (upgradeable, pausable)
- **Stacks**: More secure (immutable, Bitcoin-anchored)

Choose based on your security model and ecosystem preference.
