#!/usr/bin/env tsx
/**
 * Update adam-swap-v2 to use usdcx-v3
 * Usage: pnpm tsx scripts/update-usdcx-address.ts
 */

import {
  makeContractCall,
  broadcastTransaction,
  AnchorMode,
  PostConditionMode,
  contractPrincipalCV,
} from '@stacks/transactions';
import { STACKS_TESTNET } from '@stacks/network';
import { generateWallet, getStxAddress } from '@stacks/wallet-sdk';
import dotenv from 'dotenv';

dotenv.config();

const MNEMONIC = process.env.STACKS_DEPLOYER_PRIVATE_KEY?.replace(/"/g, '') || '';
const network = STACKS_TESTNET;
const API_URL = 'https://api.testnet.hiro.so';

async function getWalletInfo() {
  const wallet = await generateWallet({ secretKey: MNEMONIC, password: '' });
  const account = wallet.accounts[0];
  return {
    address: getStxAddress({ account, network: 'testnet' }),
    privateKey: account.stxPrivateKey,
  };
}

async function waitForTx(txid: string) {
  console.log(`  ⏳ Waiting for ${txid} ...`);
  for (let i = 0; i < 30; i++) {
    try {
      const res = await fetch(`${API_URL}/extended/v1/tx/${txid}`);
      const data = await res.json();
      if (data.tx_status === 'success') { console.log('  ✅ Confirmed'); return true; }
      if (data.tx_status?.includes('abort')) { console.log(`  ❌ Aborted: ${data.tx_status}`); return false; }
    } catch (_) {}
    await new Promise(r => setTimeout(r, 10_000));
  }
  return false;
}

async function main() {
  const { address, privateKey } = await getWalletInfo();

  console.log('Updating adam-swap-v2 usdc address to usdcx-v3...');
  console.log(`Deployer: ${address}`);

  const tx = await makeContractCall({
    contractAddress: address,
    contractName: 'adam-swap-v2',
    functionName: 'set-usdc-address',
    functionArgs: [contractPrincipalCV(address, 'usdcx-v3')],
    senderKey: privateKey,
    network,
    anchorMode: AnchorMode.Any,
    postConditionMode: PostConditionMode.Allow,
  });

  const result = await broadcastTransaction({ transaction: tx, network });

  if ('error' in result) {
    console.error('❌ Failed:', result.error);
    if ('reason' in result) console.error('Reason:', result.reason);
    process.exit(1);
  }

  console.log(`  TX: ${result.txid}`);
  console.log(`  Explorer: https://explorer.hiro.so/txid/${result.txid}?chain=testnet`);
  await waitForTx(result.txid);

  console.log('\n✅ adam-swap-v2 now uses usdcx-v3');
  console.log(`   USDC address: ${address}.usdcx-v3`);
}

main().catch(console.error);
