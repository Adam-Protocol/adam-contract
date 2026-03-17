# V2 Deployment Summary

## Deployment Date
March 17, 2026

## Network
Stacks Testnet

## What's New in V2

### 1. Treasury Management
- Added dedicated `treasury-address` variable for fee collection
- USDC from buy operations now goes to treasury instead of contract
- Admin function `set-treasury-address` to update treasury

### 2. Complete Getter Functions
- `get-treasury-address()`
- `get-adusd-address()`
- `get-adngn-address()`
- `get-adkes-address()`
- `get-adghs-address()`
- `get-adzar-address()`

### 3. Role-Based Access Control (RBAC)
Three role types with dedicated management:
- **Admins**: Manage other roles and token addresses
- **Rate Setters**: Update exchange rates
- **Pausers**: Pause/unpause contracts
- **Minters**: Mint tokens (token contract)
- **Burners**: Burn tokens (token contract)

New functions:
- `set-admin`, `set-rate-setter`, `set-pauser` (adam-swap)
- `set-admin`, `set-minter`, `set-burner`, `set-pauser` (adam-token)
- `is-admin`, `is-rate-setter`, `is-pauser` (read-only)

### 4. Structured Events
Replaced generic print statements with structured events:
- `BuyExecuted` (with timestamp)
- `SellExecuted` (with timestamp)
- `SwapExecuted` (with timestamp)
- `RateUpdated` (with timestamp)
- `Mint`, `Burn`, `Transfer` (in adam-token)

### 5. Enhanced Token Address Management
All token setters now:
- Require admin role (not just owner)
- Include proper zero-address validation
- Consistent error handling

## Deployed Contracts

### Token Contracts
- **ADUSD V2**: `STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adusd-v2`
- **ADNGN V2**: `STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adngn-v2`
- **ADKES V2**: `STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adkes-v2`
- **ADGHS V2**: `STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adghs-v2`
- **ADZAR V2**: `STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adzar-v2`

### Swap Contract
- **Adam Swap V2**: `STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-swap-v2`

### Supporting Contracts
- **USDCX**: `STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.usdcx` (existing)

## Deployment Cost
Total: 0.468840 STX

## Next Steps

### 1. Initialize Contracts
Follow the instructions in `scripts/init-v2-manual.md` to:
- Initialize all token contracts
- Initialize swap contract with treasury
- Grant minter/burner roles
- Set exchange rates

### 2. Update Backend
Update `adam-backend/.env`:
```env
STACKS_ADUSD_CONTRACT=STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adusd-v2
STACKS_ADNGN_CONTRACT=STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adngn-v2
STACKS_ADKES_CONTRACT=STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adkes-v2
STACKS_ADGHS_CONTRACT=STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adghs-v2
STACKS_ADZAR_CONTRACT=STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adzar-v2
STACKS_SWAP_CONTRACT=STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-swap-v2
```

### 3. Update Frontend
Update `adam-app/src/lib/chains/config.ts` with V2 contract addresses.

### 4. Test Operations
Test with small amounts:
- Buy ADUSD with USDC
- Swap ADUSD to ADNGN
- Sell ADUSD back

### 5. Grant Backend Roles
Once backend is updated, grant it rate-setter role:
```clarity
(contract-call? .adam-swap-v2 set-rate-setter '<BACKEND_ADDRESS> true)
```

## Verification Links

View contracts on Stacks Explorer:
- [adam-swap-v2](https://explorer.hiro.so/txid/STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-swap-v2?chain=testnet)
- [adam-token-adusd-v2](https://explorer.hiro.so/txid/STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adusd-v2?chain=testnet)

## Migration from V1

If you have users on V1 contracts:
1. Announce migration timeline
2. Provide migration tool/instructions
3. Keep V1 contracts operational during transition
4. Gradually migrate liquidity to V2
