# Adam Contract Scripts

This directory contains scripts for deploying and managing Adam Protocol smart contracts.

## Upgrade Scripts (New Currency Support)

### Quick Start
```bash
./setup-new-currencies.sh
```
Master script that runs the complete upgrade process.

### Individual Scripts

#### 1. `deploy-currencies.sh`
Deploys the new currency tokens (ADKES, ADGHS, ADZAR).

**Usage:**
```bash
./deploy-currencies.sh
```

**Output:** Token addresses saved to `deployment_logs/currencies_deployment_*.json`

**Next:** Update your `.env` file with the new addresses.

---

#### 2. `upgrade-swap.sh`
Upgrades the existing swap contract to support new tokens.

**Usage:**
```bash
./upgrade-swap.sh
```

**What it does:**
- Builds the updated contract
- Declares new implementation (gets new class hash)
- Calls `upgrade()` on existing swap contract

**Output:** Upgrade details saved to `deployment_logs/upgrade_summary_*.json`

---

#### 3. `configure-new-tokens.sh`
Sets the new token addresses in the upgraded swap contract.

**Usage:**
```bash
./configure-new-tokens.sh
```

**Requires:** ADKES_ADDRESS, ADGHS_ADDRESS, ADZAR_ADDRESS in `.env`

**What it does:**
- Calls `set_adkes_address()`
- Calls `set_adghs_address()`
- Calls `set_adzar_address()`

---

#### 4. `grant-roles-new-tokens.sh`
Grants MINTER_ROLE and BURNER_ROLE to swap contract for each new token.

**Usage:**
```bash
./grant-roles-new-tokens.sh
```

**What it does:**
- Grants MINTER_ROLE to swap for ADKES, ADGHS, ADZAR
- Grants BURNER_ROLE to swap for ADKES, ADGHS, ADZAR

---

#### 5. `verify-upgrade.sh`
Verifies that the upgrade was successful.

**Usage:**
```bash
./verify-upgrade.sh
```

**Checks:**
- ✓ Token addresses are set in swap contract
- ✓ Roles are granted correctly
- ✓ Exchange rates are configured

---

## Original Deployment Scripts

### `deploy-sncast.sh`
Original deployment script for the entire Adam Protocol (USDC, ADUSD, ADNGN, Pool, Swap).

**Usage:**
```bash
./deploy-sncast.sh
```

---

## Environment Variables Required

### For Deployment
```bash
STARKNET_RPC_URL=https://starknet-sepolia.public.blastapi.io/rpc/v0_7
DEPLOYER_ACCOUNT=your-account-name
DEPLOYER_ADDRESS=0x...
```

### For New Currencies
```bash
SWAP_ADDRESS=0x...
ADKES_ADDRESS=0x...
ADGHS_ADDRESS=0x...
ADZAR_ADDRESS=0x...
USDC_ADDRESS=0x...
```

---

## Typical Workflow

### First Time Setup
```bash
# Deploy everything from scratch
./deploy-sncast.sh
```

### Adding New Currencies
```bash
# Option 1: Automated
./setup-new-currencies.sh

# Option 2: Step by step
./deploy-currencies.sh
# Update .env with new addresses
./upgrade-swap.sh
./configure-new-tokens.sh
./grant-roles-new-tokens.sh
# Set rates using backend or sncast
./verify-upgrade.sh
```

---

## Logs and Output

All scripts save logs to `../deployment_logs/`:
- `deploy_currencies_*.log` - Currency deployment logs
- `upgrade_swap_*.log` - Upgrade logs
- `configure_tokens_*.log` - Configuration logs
- `currencies_deployment_*.json` - Currency addresses
- `upgrade_summary_*.json` - Upgrade details

---

## Troubleshooting

### Script fails with "permission denied"
```bash
chmod +x scripts/*.sh
```

### "Missing required environment variables"
Check your `.env` file has all required variables.

### "Transaction failed"
- Check your account has enough ETH for gas
- Verify RPC URL is correct and accessible
- Check account name matches your Starknet account

### "adam: invalid token" error
Run the upgrade scripts to add support for new tokens.

---

## Documentation

- `../QUICKSTART.md` - Quick start guide
- `../UPGRADE_GUIDE.md` - Detailed upgrade documentation
- `../UPGRADE_SUMMARY.md` - Summary of changes made

---

## Support

For issues or questions:
1. Check the logs in `../deployment_logs/`
2. Review the documentation files
3. Verify your `.env` configuration
4. Run `./verify-upgrade.sh` to diagnose issues
