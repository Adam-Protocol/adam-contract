# Quick Start Guide

Get Adam Protocol Stacks contracts running in 5 minutes.

## Prerequisites

Install Clarinet:
```bash
brew install clarinet
```

## Local Development

### 1. Validate Contracts

```bash
cd adam-contract/stacks
clarinet check
```

### 2. Run Tests

```bash
clarinet test
```

### 3. Start Local Blockchain

```bash
clarinet integrate
```

### 4. Interact with Contracts

Open console:
```bash
clarinet console
```

Initialize and test:
```clarity
;; Initialize ADUSD token
(contract-call? .adam-token-adusd initialize "Adam USD" "ADUSD" u6 tx-sender)

;; Mint tokens
(contract-call? .adam-token-adusd mint u1000000 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Check balance
(contract-call? .adam-token-adusd get-balance 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

## Testnet Deployment

### 1. Get Testnet STX

Visit [Hiro Faucet](https://explorer.hiro.so/sandbox/faucet?chain=testnet)

### 2. Configure Account

Edit `settings/Testnet.toml` with your mnemonic.

### 3. Deploy

```bash
./scripts/deploy.sh --network testnet --setup-roles
```

### 4. Verify

Check deployment on [Testnet Explorer](https://explorer.hiro.so/?chain=testnet)

## Next Steps

- Read [DEPLOYMENT.md](./DEPLOYMENT.md) for detailed deployment guide
- Review [README.md](./README.md) for architecture overview
- Check contract code in `contracts/` directory
- Explore tests in `tests/` directory

## Common Commands

```bash
# Validate contracts
clarinet check

# Run tests
clarinet test

# Generate deployment plan
clarinet deployments generate --testnet

# Deploy to testnet
clarinet deployments apply --testnet

# Open console
clarinet console

# Start local devnet
clarinet integrate
```

## Need Help?

- Full documentation: [DEPLOYMENT.md](./DEPLOYMENT.md)
- Stacks docs: https://docs.stacks.co
- Clarinet docs: https://docs.hiro.so/clarinet
