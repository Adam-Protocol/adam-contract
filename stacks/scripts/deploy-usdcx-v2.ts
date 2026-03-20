#!/usr/bin/env tsx

/**
 * Deploy usdcx-v2 and mint 200 USDCX to a recipient
 * Usage: pnpm tsx scripts/deploy-usdcx-v2.ts
 */

import {
  makeContractDeploy,
  makeContractCall,
  broadcastTransaction,
  AnchorMode,
  PostConditionMode,
  uintCV,
  standardPrincipalCV,
} from '@stacks/transactions';
import { STACKS_TESTNET } from '@stacks/network';
import { generateWallet, getStxAddress } from '@stacks/wallet-sdk';
import * as fs from 'fs';
import * as path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const MNEMONIC = process.env.STACKS_DEPLOYER_PRIVATE_KEY?.replace(/"/g, '') || '';
const network = STACKS_TESTNET;
const API_URL = 'https://api.testnet.hiro.so';

// 200 USDCX with 6 decimals
const MINT_RECIPIENT = 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191';
const MINT_AMOUNT = 200_000_000; // 200 USDCX (6 decimals)
const CONTRACT_NAME = 'usdcx-v3';
const CONTRACT_FILE = 'usdcx-v3.clar';

async function getWalletInfo() {
  if (!MNEMONIC) {
    console.error('❌ STACKS_DEPLOYER_PRIVATE_KEY not set in .env');
    process.exit(1);
  }
  const wallet = await generateWallet({ secretKey: MNEMONIC, password: '' });
  const account = wallet.accounts[0];
  const address = getStxAddress({ account, network: 'testnet' });
  return { address, privateKey: account.stxPrivateKey };
}

async function waitForTx(txid: string): Promise<boolean> {
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
  console.log('  ⚠️  Timed out');
  return false;
}

async function main() {
  const { address, privateKey } = await getWalletInfo();

  console.log('=========================================');
  console.log(`🚀 Deploy ${CONTRACT_NAME} + Mint 200 USDCX`);
  console.log('=========================================');
  console.log(`Deployer : ${address}`);
  console.log(`Recipient: ${MINT_RECIPIENT}`);
  console.log(`Amount   : ${MINT_AMOUNT / 1_000_000} USDCX\n`);

  // ── Step 1: Deploy ──────────────────────────────────────────────────────────
  console.log(`Step 1: Deploying ${CONTRACT_NAME}...`);
  const contractSource = fs.readFileSync(
    path.join(__dirname, `../contracts/${CONTRACT_FILE}`),
    'utf8',
  );

  const deployTx = await makeContractDeploy({
    contractName: CONTRACT_NAME,
    codeBody: contractSource,
    senderKey: privateKey,
    network,
    anchorMode: AnchorMode.Any,
    postConditionMode: PostConditionMode.Allow,
  });

  const deployResult = await broadcastTransaction({ transaction: deployTx, network });

  if ('error' in deployResult) {
    console.error('❌ Deploy failed:', deployResult.error);
    if ('reason' in deployResult) console.error('Reason:', deployResult.reason);
    process.exit(1);
  }

  console.log(`  TX: ${deployResult.txid}`);
  console.log(`  Explorer: https://explorer.hiro.so/txid/${deployResult.txid}?chain=testnet`);
  const deployed = await waitForTx(deployResult.txid);
  if (!deployed) { console.error('Deploy did not confirm — aborting'); process.exit(1); }

  // ── Step 2: Mint ────────────────────────────────────────────────────────────
  console.log('\nStep 2: Minting 200 USDCX...');
  const mintTx = await makeContractCall({
    contractAddress: address,
    contractName: CONTRACT_NAME,
    functionName: 'mint',
    functionArgs: [uintCV(MINT_AMOUNT), standardPrincipalCV(MINT_RECIPIENT)],
    senderKey: privateKey,
    network,
    anchorMode: AnchorMode.Any,
    postConditionMode: PostConditionMode.Allow,
  });

  const mintResult = await broadcastTransaction({ transaction: mintTx, network });

  if ('error' in mintResult) {
    console.error('❌ Mint failed:', mintResult.error);
    if ('reason' in mintResult) console.error('Reason:', mintResult.reason);
    process.exit(1);
  }

  console.log(`  TX: ${mintResult.txid}`);
  console.log(`  Explorer: https://explorer.hiro.so/txid/${mintResult.txid}?chain=testnet`);
  await waitForTx(mintResult.txid);

  // ── Done ────────────────────────────────────────────────────────────────────
  console.log('\n=========================================');
  console.log('✅ Done!');
  console.log('=========================================');
  console.log(`Contract : ${address}.${CONTRACT_NAME}`);
  console.log(`Balance  : 200 USDCX minted to ${MINT_RECIPIENT}`);
  console.log('\nFrontend .env updated automatically.');
  console.log('\nNext: update adam-swap-v2 to point to new usdcx:');
  console.log(`  call set-usdc-address with ${address}.${CONTRACT_NAME}`);
}

main().catch(console.error);
