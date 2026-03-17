# Manual V2 Contract Initialization

The V2 contracts have been deployed to testnet. Follow these steps to initialize them.

## Deployed Contract Addresses

- `adam-token-adusd-v2`: STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adusd-v2
- `adam-token-adngn-v2`: STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adngn-v2
- `adam-token-adkes-v2`: STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adkes-v2
- `adam-token-adghs-v2`: STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adghs-v2
- `adam-token-adzar-v2`: STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adzar-v2
- `adam-swap-v2`: STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-swap-v2

## Step 1: Initialize Tokens

Run these commands in clarinet console or via Stacks Explorer:

```clarity
;; Initialize ADUSD
(contract-call? .adam-token-adusd-v2 initialize "Adam USD" "ADUSD" u6 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191)

;; Initialize ADNGN
(contract-call? .adam-token-adngn-v2 initialize "Adam NGN" "ADNGN" u6 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191)

;; Initialize ADKES
(contract-call? .adam-token-adkes-v2 initialize "Adam KES" "ADKES" u6 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191)

;; Initialize ADGHS
(contract-call? .adam-token-adghs-v2 initialize "Adam GHS" "ADGHS" u6 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191)

;; Initialize ADZAR
(contract-call? .adam-token-adzar-v2 initialize "Adam ZAR" "ADZAR" u6 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191)
```

## Step 2: Initialize Swap Contract

```clarity
(contract-call? .adam-swap-v2 initialize
  'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191  ;; owner
  'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191  ;; treasury (update this!)
  'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.usdcx
  'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adusd-v2
  'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adngn-v2
  'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adkes-v2
  'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adghs-v2
  'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adzar-v2
  u50  ;; 0.5% fee
)
```

## Step 3: Grant Minter Roles

```clarity
(contract-call? .adam-token-adusd-v2 set-minter 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-swap-v2 true)
(contract-call? .adam-token-adngn-v2 set-minter 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-swap-v2 true)
(contract-call? .adam-token-adkes-v2 set-minter 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-swap-v2 true)
(contract-call? .adam-token-adghs-v2 set-minter 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-swap-v2 true)
(contract-call? .adam-token-adzar-v2 set-minter 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-swap-v2 true)
```

## Step 4: Grant Burner Roles

```clarity
(contract-call? .adam-token-adusd-v2 set-burner 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-swap-v2 true)
(contract-call? .adam-token-adngn-v2 set-burner 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-swap-v2 true)
(contract-call? .adam-token-adkes-v2 set-burner 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-swap-v2 true)
(contract-call? .adam-token-adghs-v2 set-burner 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-swap-v2 true)
(contract-call? .adam-token-adzar-v2 set-burner 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-swap-v2 true)
```

## Step 5: Set Exchange Rates

```clarity
;; USDC <-> ADUSD (1:1)
(contract-call? .adam-swap-v2 set-rate 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.usdcx 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adusd-v2 u1000000000000000000)
(contract-call? .adam-swap-v2 set-rate 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adusd-v2 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.usdcx u1000000000000000000)

;; USDC <-> ADNGN (1 USD = 1500 NGN)
(contract-call? .adam-swap-v2 set-rate 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.usdcx 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adngn-v2 u1500000000000000000000)
(contract-call? .adam-swap-v2 set-rate 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adngn-v2 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.usdcx u666666666666666666)

;; ADUSD <-> ADNGN
(contract-call? .adam-swap-v2 set-rate 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adusd-v2 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adngn-v2 u1500000000000000000000)
(contract-call? .adam-swap-v2 set-rate 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adngn-v2 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adusd-v2 u666666666666666666)
```

## Step 6: Verify Setup

```clarity
;; Check if swap has minter role
(contract-call? .adam-token-adusd-v2 is-minter 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-swap-v2)

;; Check fee
(contract-call? .adam-swap-v2 get-fee-bps)

;; Check treasury
(contract-call? .adam-swap-v2 get-treasury-address)

;; Check rate
(contract-call? .adam-swap-v2 get-rate 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.usdcx 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adusd-v2)
```

## Using Stacks Explorer

You can also execute these transactions via the Stacks Explorer:
https://explorer.hiro.so/sandbox/contract-call/STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191/adam-swap-v2?chain=testnet

## Update Backend Configuration

Update your backend `.env` file with the new V2 contract addresses:

```env
STACKS_ADUSD_CONTRACT=STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adusd-v2
STACKS_ADNGN_CONTRACT=STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adngn-v2
STACKS_ADKES_CONTRACT=STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adkes-v2
STACKS_ADGHS_CONTRACT=STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adghs-v2
STACKS_ADZAR_CONTRACT=STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-token-adzar-v2
STACKS_SWAP_CONTRACT=STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191.adam-swap-v2
```

## Update Frontend Configuration

Update your frontend configuration file with the new V2 addresses.
