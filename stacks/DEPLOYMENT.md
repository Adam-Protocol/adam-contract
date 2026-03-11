# Adam Protocol Stacks - Deployment Guide

Complete guide for deploying Adam Protocol smart contracts to Stacks blockchain.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Pre-Deployment Checklist](#pre-deployment-checklist)
3. [Local Testing](#local-testing)
4. [Testnet Deployment](#testnet-deployment)
5. [Mainnet Deployment](#mainnet-deployment)
6. [Post-Deployment Setup](#post-deployment-setup)
7. [Verification](#verification)
8. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools

- **Clarinet v2.0+** - Stacks smart contract development tool
  ```bash
  # Install via Homebrew (macOS/Linux)
  brew install clarinet
  
  # Or download from GitHub
  # https://github.com/hirosystems/clarinet/releases
  ```

- **Stacks CLI** (optional, for manual operations)
  ```bash
  npm install -g @stacks/cli
  ```

### Required Resources

- **Testnet STX** - Get from [Hiro Faucet](https://explorer.hiro.so/sandbox/faucet?chain=testnet)
- **Mainnet STX** - Purchase from exchanges or acquire through other means
- **Hardware Wallet** (recommended for mainnet) - Ledger or similar

## Pre-Deployment Checklist

Before deploying to any network:

- [ ] All contracts pass `clarinet check`
- [ ] All tests pass `clarinet test`
- [ ] Security audit completed (for mainnet)
- [ ] Deployment addresses documented
- [ ] Backup of deployment keys secured
- [ ] Network configuration verified
- [ ] Sufficient STX balance for deployment fees

## Local Testing

### 1. Validate Contracts

```bash
cd adam-contract/stacks
clarinet check
```

Expected output: All contracts should validate without errors.

### 2. Run Tests

```bash
clarinet test
```

All tests should pass. Review any warnings or failures.

### 3. Start Local Devnet

```bash
clarinet integrate
```

This starts a local Stacks blockchain for testing.

### 4. Test Contract Interactions

Open Clarinet console:
```bash
clarinet console
```

Test basic operations:
```clarity
;; Initialize token
(contract-call? .adam-token-adusd initialize "Adam USD" "ADUSD" u6 tx-sender)

;; Mint tokens
(contract-call? .adam-token-adusd mint u1000000 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Check balance
(contract-call? .adam-token-adusd get-balance 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

## Testnet Deployment

### 1. Configure Testnet Account

Edit `settings/Testnet.toml`:

```toml
[network]
name = "testnet"
node_rpc_address = "https://api.testnet.hiro.so"
deployment_fee_rate = 10

[accounts.deployer]
mnemonic = "your twenty four word mnemonic phrase here..."
```

### 2. Get Testnet STX

Visit the [Hiro Faucet](https://explorer.hiro.so/sandbox/faucet?chain=testnet) and request testnet STX for your deployer address.

Verify balance:
```bash
clarinet console --testnet
>> (stx-get-balance tx-sender)
```

### 3. Generate Deployment Plan

```bash
clarinet deployments generate --testnet --medium-cost
```

This creates `deployments/default.testnet-plan.yaml`. Review it carefully.

### 4. Deploy Contracts

```bash
./scripts/deploy.sh --network testnet
```

Or manually:
```bash
clarinet deployments apply --testnet
```

### 5. Save Deployment Info

The deployment summary is saved to:
```
deployments/deployment_summary_testnet.json
```

**Important:** Back up this file! It contains all deployed contract addresses.

### 6. Setup Roles

```bash
./scripts/setup-roles.sh --network testnet
```

Follow the prompts to configure roles and permissions.

## Mainnet Deployment

### ⚠️ Security Warnings

- **Contracts are immutable** - No changes possible after deployment
- **Test thoroughly on testnet first**
- **Use hardware wallet for deployment**
- **Complete security audit before mainnet**
- **Have incident response plan ready**

### 1. Security Audit

Before mainnet deployment:

- Complete professional security audit
- Review audit findings and implement fixes
- Re-audit if significant changes made
- Document all known limitations

### 2. Configure Mainnet Account

For maximum security, use encrypted mnemonic:

```bash
clarinet deployments encrypt
```

Enter your mnemonic and password when prompted. Add the encrypted output to `settings/Mainnet.toml`:

```toml
[network]
name = "mainnet"
node_rpc_address = "https://api.hiro.so"
deployment_fee_rate = 10

[accounts.deployer]
encrypted_mnemonic = "<ENCRYPTED_MNEMONIC_HERE>"
```

### 3. Verify Sufficient Balance

Mainnet deployment requires significant STX for fees. Estimate costs:

```bash
clarinet deployments generate --mainnet --high-cost
```

Review the `cost` field for each transaction in the generated plan.

### 4. Final Pre-Deployment Checks

- [ ] All testnet testing completed successfully
- [ ] Security audit passed
- [ ] Deployment keys backed up securely
- [ ] Team notified of deployment
- [ ] Monitoring systems ready
- [ ] Sufficient STX balance confirmed

### 5. Deploy to Mainnet

```bash
./scripts/deploy.sh --network mainnet
```

You'll be prompted to confirm before deployment proceeds.

### 6. Verify Deployment

Check contracts on [Stacks Explorer](https://explorer.hiro.so/):

```
https://explorer.hiro.so/txid/<transaction-id>?chain=mainnet
```

### 7. Setup Roles (Mainnet)

```bash
./scripts/setup-roles.sh --network mainnet
```

## Post-Deployment Setup

### 1. Grant Minter Roles

AdamSwap needs permission to mint tokens:

```clarity
(contract-call? .adam-token-adusd set-minter .adam-swap true)
(contract-call? .adam-token-adngn set-minter .adam-swap true)
(contract-call? .adam-token-adkes set-minter .adam-swap true)
(contract-call? .adam-token-adghs set-minter .adam-swap true)
(contract-call? .adam-token-adzar set-minter .adam-swap true)
```

### 2. Grant Burner Roles

AdamSwap needs permission to burn tokens:

```clarity
(contract-call? .adam-token-adusd set-burner .adam-swap true)
(contract-call? .adam-token-adngn set-burner .adam-swap true)
(contract-call? .adam-token-adkes set-burner .adam-swap true)
(contract-call? .adam-token-adghs set-burner .adam-swap true)
(contract-call? .adam-token-adzar set-burner .adam-swap true)
```

### 3. Configure Pool

Set the authorized swap contract:

```clarity
(contract-call? .adam-pool set-swap-contract .adam-swap)
```

### 4. Initialize Exchange Rates

Set initial rates (example values, adjust based on market):

```clarity
;; USDC <-> ADUSD (1:1)
(contract-call? .adam-swap set-rate .usdc-token .adam-token-adusd u1000000000000000000)
(contract-call? .adam-swap set-rate .adam-token-adusd .usdc-token u1000000000000000000)

;; USDC <-> ADNGN (1 USD = 1500 NGN)
(contract-call? .adam-swap set-rate .usdc-token .adam-token-adngn u1500000000000000000000)
(contract-call? .adam-swap set-rate .adam-token-adngn .usdc-token u666666666666666666)

;; ADUSD <-> ADNGN
(contract-call? .adam-swap set-rate .adam-token-adusd .adam-token-adngn u1500000000000000000000)
(contract-call? .adam-swap set-rate .adam-token-adngn .adam-token-adusd u666666666666666666)
```

### 5. Grant Rate Setter Role

Authorize backend service to update rates:

```clarity
(contract-call? .adam-swap set-rate-setter '<BACKEND_SERVICE_ADDRESS> true)
```

## Verification

### Contract Verification Checklist

- [ ] All contracts deployed successfully
- [ ] Contract addresses match deployment summary
- [ ] AdamSwap has minter role on all tokens
- [ ] AdamSwap has burner role on all tokens
- [ ] Pool recognizes AdamSwap as authorized
- [ ] Exchange rates are set correctly
- [ ] Fee percentage is correct
- [ ] Treasury address is correct

### Functional Testing

Test each operation with small amounts:

1. **Buy Test**
   - Transfer small amount of USDC
   - Verify ADUSD minted
   - Check commitment registered

2. **Swap Test**
   - Swap small ADUSD to ADNGN
   - Verify correct exchange rate applied
   - Check fee deduction

3. **Sell Test**
   - Sell small amount of ADUSD
   - Verify tokens burned
   - Check nullifier marked as spent

## Troubleshooting

### Deployment Fails

**Error: Insufficient STX balance**
- Solution: Add more STX to deployer account
- Use `--low-cost` flag to reduce fees

**Error: Contract already exists**
- Solution: Use different contract name or deployer address
- On testnet, can use fresh account

### Role Setup Issues

**Error: Unauthorized**
- Verify you're calling from contract owner address
- Check tx-sender matches expected owner

**Minting Fails**
- Verify minter role granted correctly
- Check AdamSwap contract address is correct

### Rate Issues

**Error: Rate not set**
- Set rate for both directions (A->B and B->A)
- Verify rate precision (use 1e18 multiplier)

### Connection Issues

**Cannot connect to node**
- Verify node RPC address in settings
- Try alternative endpoints:
  - Testnet: `https://api.testnet.hiro.so`
  - Mainnet: `https://api.hiro.so`

## Support

For issues or questions:

- GitHub Issues: [adam-protocol/issues](https://github.com/adam-protocol/adam-protocol/issues)
- Documentation: [docs.adam-protocol.com](https://docs.adam-protocol.com)
- Discord: [discord.gg/adam-protocol](https://discord.gg/adam-protocol)

## License

MIT License - See LICENSE file for details
