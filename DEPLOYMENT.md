# Adam Protocol Deployment Guide

## Deployment Summary

Successfully deployed Adam Protocol contracts to Starknet Sepolia testnet on **March 4, 2026**.

### Deployed Contracts

| Contract | Address | Explorer Link |
|----------|---------|---------------|
| ADUSD Token | `0x025a17a3eb413707e65a725f78d796506114aaaa1a5855f6bb4a4e94a02b4abf` | [View on Starkscan](https://sepolia.starkscan.co/contract/0x025a17a3eb413707e65a725f78d796506114aaaa1a5855f6bb4a4e94a02b4abf) |
| ADNGN Token | `0x00cbd26c24bc30faef27cfb428e8c813a88b80f6590e45f5b318ae9cc608fea6` | [View on Starkscan](https://sepolia.starkscan.co/contract/0x00cbd26c24bc30faef27cfb428e8c813a88b80f6590e45f5b318ae9cc608fea6) |
| Adam Pool | `0x04cfa9660c0acca29ffc3a3a41777c38f5c7ba56c84b1c76eccf185e4494259d` | [View on Starkscan](https://sepolia.starkscan.co/contract/0x04cfa9660c0acca29ffc3a3a41777c38f5c7ba56c84b1c76eccf185e4494259d) |
| Adam Swap | `0x028cdc030654f1e6604257b0d93599e8d2dae1f161dbe0a3fb0eb90da660bd1c` | [View on Starkscan](https://sepolia.starkscan.co/contract/0x028cdc030654f1e6604257b0d93599e8d2dae1f161dbe0a3fb0eb90da660bd1c) |
| USDC (Reference) | `0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7` | [View on Starkscan](https://sepolia.starkscan.co/contract/0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7) |

### Class Hashes

| Contract | Class Hash |
|----------|------------|
| AdamToken | `0x057a2d9808836e35975301de3318ec275a49c7bd1274589fc2d73450fdae30b9` |
| AdamPool | `0x02f8de695fd88a8c4d4f80004f5e5d4ca8e6b67cd570d38ec2d0c5b2ad401b80` |
| AdamSwap | `0x019a3e1e0b34acbf00113fdd23cbfc4d85035bf9822c509679be6fad72063f02` |

### Configuration

- **Network**: Starknet Sepolia Testnet
- **RPC URL**: `https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_10/5QQMV6kqa3iDaH_EbNhTw`
- **Owner/Admin**: `0x0456e6d7184cd79e3f5cc63397a5540e8aeef7fd2f136136dfd40caf122cba88`
- **Treasury**: `0x0456e6d7184cd79e3f5cc63397a5540e8aeef7fd2f136136dfd40caf122cba88`
- **Fee (BPS)**: 30 (0.3%)

## How to Deploy

### Prerequisites

1. Install Scarb (Cairo package manager)
2. Install Starknet Foundry (sncast)
3. Install starkli (for class hash computation)
4. Configure your Starknet account in sncast

### Environment Setup

Create a `.env` file with the following variables:

```bash
# Starknet Account Configuration
DEPLOYER_PRIVATE_KEY=<your_private_key>
DEPLOYER_ADDRESS=<your_account_address>
DEPLOYER_ACCOUNT=<your_account_name_in_sncast>

# Network Configuration
STARKNET_NETWORK=sepolia
STARKNET_RPC_URL=https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_10/<your_api_key>

# Contract Addresses
USDC_ADDRESS=0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7

# Deployment Configuration
DEFAULT_FEE_BPS=30
MAX_FEE_BPS=1000

# Token Configuration
ADUSD_NAME="Adam USD"
ADUSD_SYMBOL="ADUSD"
ADNGN_NAME="Adam NGN"
ADNGN_SYMBOL="ADNGN"
```

### Build Contracts

```bash
scarb build
```

### Deploy

Run the deployment script:

```bash
bash ./scripts/deploy-sncast.sh
```

The script will:
1. Declare AdamToken contract
2. Deploy ADUSD token
3. Deploy ADNGN token
4. Declare AdamPool contract
5. Deploy AdamPool
6. Declare AdamSwap contract
7. Deploy AdamSwap
8. Save deployment summary to `deployment_logs/deployment_summary_sepolia.json`

### Verify Deployment

Check the deployment log file in `deployment_logs/` directory for detailed transaction information.

## Contract Architecture

### AdamToken (ERC20)
- Upgradeable ERC20 token with role-based access control
- Supports minting, burning, and pausing
- Roles: MINTER, BURNER, PAUSER, UPGRADER, ADMIN

### AdamPool
- Manages commitments and nullifiers for privacy
- Tracks token balances and user commitments
- Owner-controlled for administrative functions

### AdamSwap
- Core exchange contract for buying, selling, and swapping tokens
- Supports USDC ↔ ADUSD/ADNGN exchanges
- Configurable exchange rates and fees
- Pausable for emergency situations
- Roles: RATE_SETTER, PAUSER, UPGRADER, ADMIN

## Next Steps

1. **Grant Roles**: Assign appropriate roles to backend services
2. **Set Exchange Rates**: Configure initial exchange rates for token pairs
3. **Fund Treasury**: Add liquidity to the treasury for operations
4. **Test Transactions**: Perform test buy/sell/swap operations
5. **Update Backend**: Configure backend with deployed contract addresses
6. **Update Frontend**: Configure frontend with deployed contract addresses

## Useful Commands

### Check Contract Info
```bash
# Get contract class hash
starkli class-hash target/dev/adam_token_AdamToken.contract_class.json

# Call contract (read)
sncast call --contract-address <address> --function <function_name> --url <rpc_url>

# Invoke contract (write)
sncast invoke --contract-address <address> --function <function_name> --calldata <args> --url <rpc_url> --account <account>
```

### Grant Roles
```bash
# Grant MINTER_ROLE to backend
sncast invoke \
  --contract-address <token_address> \
  --function grant_role \
  --calldata <MINTER_ROLE> <backend_address> \
  --url <rpc_url> \
  --account <account>
```

## Troubleshooting

### Common Issues

1. **RPC Version Mismatch**: Ensure you're using RPC v0_10 endpoint
2. **ByteArray Format**: Use format `0 0xHEXSTRING length` for string parameters
3. **Account Not Found**: Make sure your account is configured in sncast
4. **Insufficient Funds**: Ensure your account has enough ETH for gas fees

### Support

For issues or questions, refer to:
- [Starknet Documentation](https://docs.starknet.io/)
- [Scarb Documentation](https://docs.swmansion.com/scarb/)
- [Starknet Foundry Documentation](https://foundry-rs.github.io/starknet-foundry/)
