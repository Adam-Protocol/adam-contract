#!/usr/bin/env tsx
import { makeContractCall, broadcastTransaction, AnchorMode, PostConditionMode, contractPrincipalCV, boolCV } from '@stacks/transactions';
import { STACKS_TESTNET } from '@stacks/network';
import { generateWallet, getStxAddress } from '@stacks/wallet-sdk';
import dotenv from 'dotenv';
dotenv.config();

const MNEMONIC = process.env.STACKS_DEPLOYER_PRIVATE_KEY?.replace(/"/g, '') || '';
const network = STACKS_TESTNET;

async function run() {
  const wallet = await generateWallet({ secretKey: MNEMONIC, password: '' });
  const account = wallet.accounts[0];
  const address = getStxAddress({ account, network: 'testnet' });
  const privateKey = account.stxPrivateKey;

  const missing = [
    { contract: 'adam-token-adngn-v2', role: 'set-minter' },
    { contract: 'adam-token-adkes-v2', role: 'set-minter' }
  ];

  for (const item of missing) {
    console.log(`Fixing ${item.role} for ${item.contract}...`);
    const tx = await makeContractCall({
      contractAddress: address,
      contractName: item.contract,
      functionName: item.role,
      functionArgs: [contractPrincipalCV(address, 'adam-swap-v3'), boolCV(true)],
      senderKey: privateKey,
      network,
      anchorMode: AnchorMode.Any,
      postConditionMode: PostConditionMode.Allow,
    });
    const res = await broadcastTransaction({ transaction: tx, network });
    console.log(`  TX: ${res.txid}`);
    await new Promise(r => setTimeout(r, 15000)); // Wait a bit between broadcasts
  }
}
run().catch(console.error);
