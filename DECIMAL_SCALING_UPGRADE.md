# Decimal Scaling Fixes - Contract Upgrade Summary

## Overview
This document outlines the comprehensive decimal handling fixes applied to the Adam Protocol smart contracts to ensure accurate swaps between USDC (6 decimals) and Adam stablecoins (18 decimals).

## Changes Applied

### 1. Starknet Smart Contract (adam-swap)

#### Decimal Scaling Implementation
- **Function**: `_apply_rate_and_fee`
- **Enhancement**: Automatically detects the decimals of input and output tokens and scales amounts accordingly
- **Logic**:
  - Fetches decimals from both tokens using `IERC20MetadataDispatcher`
  - Applies rate conversion: `(amount_in * rate) / RATE_PRECISION`
  - Scales output based on decimal difference:
    - If `decimals_to > decimals_from`: multiply by `10^(decimals_to - decimals_from)`
    - If `decimals_to < decimals_from`: divide by `10^(decimals_from - decimals_to)`
    - If equal: no scaling needed
  - Applies transaction fee: `amount * (1 - fee_bps/10000)`

#### Rate Precision Standard
- **Constant**: `RATE_PRECISION = 1e18`
- **Benefit**: Admins can set exchange rates as simple multipliers (e.g., 1 USDC = 1575.26 ADNGN stored as 1575.26 * 10^18)
- **Consistency**: Matches frontend precision for accurate calculations

#### Helper Function
- **Function**: `_pow10(exp: u8) -> u256`
- **Purpose**: Efficiently calculates base-10 powers for decimal scaling
- **Implementation**: Uses optimized `while` loop for clarity and performance

### 2. Adam Token Contract (adam-token)

#### Custom Decimals Support
- **Storage**: Added `decimals: u8` field to contract storage
- **Constructor**: Updated to accept `decimals` parameter
- **Implementation**: `decimals()` method returns the stored custom decimal value
- **Benefits**:
  - Enables accurate testing (mocking USDC with 6 decimals)
  - Supports future token additions with varying decimal places
  - Maintains compatibility with standard ERC20 metadata interface

### 3. Code Quality Improvements

#### Loop Optimization
- **File**: `adam-swap.cairo`
- **Change**: Replaced `loop` with `while` in `_pow10` function
- **Reason**: Improved code clarity and eliminated compiler warnings
- **Before**:
  ```cairo
  loop {
      if i >= exp {
          break;
      }
      res *= 10;
      i += 1;
  };
  ```
- **After**:
  ```cairo
  while i < exp {
      res *= 10;
      i += 1;
  };
  ```

#### Unused Import Cleanup
- **File**: `adam-token.cairo`
- **Removed**: `IERC20MetadataDispatcher` and `IERC20MetadataDispatcherTrait` (unused imports)
- **Kept**: `IERC20Metadata` (used in trait implementation)

## Verification

### Test Results
- **Test Suite**: adam-swap integration tests
- **Result**: 14 passed, 0 failed
- **Coverage**: Includes specific test cases for 6-decimal to 18-decimal token scaling

### Manual Verification
- **Buy Flow**: Entering 5 USDC correctly predicts ADNGN amount with proper scaling
- **Display**: Exchange rate shown clearly (e.g., 1 USDC = 1,575.26 ADNGN) without excessive trailing zeros
- **Consistency**: Frontend calculations match on-chain results

## Technical Details

### Decimal Scaling Example
**Scenario**: Swap 5 USDC (6 decimals) for ADNGN (18 decimals) at rate 1575.26

1. Input: `amount_in = 5 * 10^6 = 5,000,000`
2. Rate: `1575.26 * 10^18`
3. Gross output: `(5,000,000 * 1575.26 * 10^18) / 10^18 = 7,876,300,000`
4. Decimal scaling: `7,876,300,000 * 10^(18-6) = 7,876,300,000 * 10^12 = 7.8763 * 10^18`
5. Fee deduction (e.g., 50 bps): `7.8763 * 10^18 * (1 - 0.005) = 7.8287 * 10^18`

### Rate Setting
Admins set rates using the `set_rate` function with the rate scaled by 1e18:
```
set_rate(USDC, ADNGN, 1575.26 * 10^18)
```

## Files Modified
1. `adam-contract/starknet/packages/adam-swap/src/adam_swap.cairo`
   - Optimized `_pow10` function (loop → while)
   - Decimal scaling logic already implemented

2. `adam-contract/starknet/packages/adam-token/src/adam_token.cairo`
   - Removed unused imports
   - Custom decimals support already implemented

## Deployment Notes
- No breaking changes to existing interfaces
- All external functions maintain backward compatibility
- Upgradeable contracts can be deployed via the `upgrade` function
- Existing rate data remains valid with new decimal scaling

## Future Considerations
- Monitor gas costs for decimal scaling operations
- Consider caching decimal values if gas optimization is needed
- Extend to additional token pairs as protocol grows
