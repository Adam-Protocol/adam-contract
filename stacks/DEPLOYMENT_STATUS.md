# Adam Protocol V3 - Deployment Status

## Network
Testnet

## Deployer Address
`STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191`

## Deployed Contracts

### Core Contracts
- ✅ `usdcx-v3` - Mock USDC token (6 decimals)
- ✅ `adam-swap-v3` - Main swap contract

### Adam Stablecoin Tokens (6 decimals each)
- ✅ `adam-token-adusd-v3` - US Dollar stablecoin
- ✅ `adam-token-adngn-v3` - Nigerian Naira stablecoin
- ✅ `adam-token-adkes-v3` - Kenyan Shilling stablecoin
- ✅ `adam-token-adghs-v3` - Ghanaian Cedi stablecoin
- ✅ `adam-token-adzar-v3` - South African Rand stablecoin

## Initialization Status

### Token Initialization
- ✅ All tokens initialized with 6 decimals
- ✅ Minter roles granted to adam-swap-v3
- ✅ Burner roles granted to adam-swap-v3

### Swap Contract Initialization
- ✅ Swap contract initialized
- ✅ Treasury address set to: `ST29FX0E5C5KD8J44B02S1ZXHK4PJBD211CXBF6W9`
- ✅ Fee set to: 0.5% (50 basis points)

### Exchange Rates
- ⚠️  USDC ↔ ADUSD: May need manual verification
- ✅ USDC ↔ ADNGN: Set
- ✅ USDC ↔ ADKES: Set
- ✅ USDC ↔ ADGHS: Set
- ✅ USDC ↔ ADZAR: Set

## Contract Addresses (Full)

```
USDC:  STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.usdcx-v3
SWAP:  STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-swap-v3
ADUSD: STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adusd-v3
ADNGN: STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adngn-v3
ADKES: STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adkes-v3
ADGHS: STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adghs-v3
ADZAR: STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adzar-v3
```

## Explorer Links

- [Deployer Address](https://explorer.hiro.so/address/STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191?chain=testnet)
- [Swap Contract](https://explorer.hiro.so/txid/STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-swap-v3?chain=testnet)

## Next Steps

1. ✅ Update frontend `.env` with v3 addresses (DONE)
2. ✅ Update backend `.env` with v3 addresses (DONE)
3. Restart frontend and backend applications
4. Test buy/sell/swap operations
5. Monitor transactions on testnet

## Maintenance Commands

```bash
# Deploy contracts
pnpm run v3:deploy

# Initialize contracts
pnpm run v3:init

# Update exchange rates
pnpm run v3:update-rates

# Check treasury balance
pnpm run check-treasury
```

## Notes

- All contracts use 6 decimal precision
- The swap contract has a 20% rate change limit for safety
- USDC ↔ ADUSD rates may have been set in a previous initialization
- All tokens have proper minter/burner roles configured
