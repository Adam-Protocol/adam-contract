#!/usr/bin/env tsx

/**
 * Update Treasury Address Script
 * Changes the treasury address in the swap contract
 * 
 * Usage: pnpm run update-treasury <new-treasury-address>
 */

import {
  makeContractCall,
  broadcastTransaction,
  AnchorMode,
  PostConditionMode,
  standardPrincipalCV,
} from '@stacks/transactions';
import { STACKS_TESTNET, STACKS_MAINNET } from '@stacks/network';
import { generateWallet, getStxAddress } from '@stacks/wallet-sdk';
import dotenv from 'dotenv';

dotenv.config();

const MNEMONIC = process.env.STACKS_DEPLOYER_PRIVATE_KEY?.replace(/"/g, '') || '';
const NETWORK_TYPE = process.env.STACKS_NETWORK || 'testnet';
const network = NETWORK_TYPE === 'mainnet' ? STACKS_MAINNET : STACKS_TESTNET;
const API_URL = NETWORK_TYPE === 'mainnet' ? 'https://api.hiro.so' : 'https://api.testnet.hiro.so';

async function getWalletInfo() {
  if (!MNEMONIC) {
    console.error('❌ Error: STACKS_DEPLOYER_PRIVATE_KEY not set in .env');
    process.exit(1);
  }

  const wallet = await generateWallet({
    secretKey: MNEMONIC,
    password: '',
  });
  
  const account = wallet.accounts[0];
  const address = getStxAddress({ account, network: NETWORK_TYPE === 'mainnet' ? 'mainnet' : 'testnet' });
  const privateKey = account.stxPrivateKey;

  return { address, privateKey };
}

async function waitForTx(txid: string): Promise<boolean> {
  console.log(`⏳ Waiting for transaction ${txid.slice(0, 8)}...`);
  
  for (let i = 0; i < 30; i++) {
    try {
      const response = await fetch(`${API_URL}/extended/v1/tx/${txid}`);
      const data = await response.json();
      
      if (data.tx_status === 'success') {
        console.log(`✅ Transaction confirmed`);
        return true;
      } else if (data.tx_status?.includes('abort')) {
        console.log(`❌ Transaction failed: ${data.tx_status}`);
        return false;
      }
    } catch (e) {}
    
    await new Promise(resolve => setTimeout(resolve, 10000));
  }
  
  console.log(`⚠️  Transaction timeout`);
  return false;
}

async function main() {
  const newTreasuryAddress = process.argv[2];
  
  if (!newTreasuryAddress) {
    console.error('❌ Error: Please provide a new treasury address');
    console.error('Usage: pnpm run update-treasury <new-treasury-address>');
    process.exit(1);
  }

  // Validate address format
  const isTestnet = NETWORK_TYPE === 'testnet';
  const expectedPrefix = isTestnet ? 'ST' : 'SP';
  
  if (!newTreasuryAddress.startsWith(expectedPrefix)) {
    console.error(`❌ Error: Invalid address for ${NETWORK_TYPE}`);
    console.error(`Expected address starting with '${expectedPrefix}', got '${newTreasuryAddress.substring(0, 2)}'`);
    process.exit(1);
  }
  
  // Validate address length (Stacks addresses are 40-41 characters)
  if (newTreasuryAddress.length < 40 || newTreasuryAddress.length > 42) {
    console.error(`❌ Error: Invalid address length: ${newTreasuryAddress.length}`);
    console.error(`Stacks addresses should be 40-42 characters`);
    process.exit(1);
  }

  const { address, privateKey } = await getWalletInfo();

  console.log('=========================================');
  console.log('🔄 Updating Treasury Address');
  console.log('=========================================');
  console.log(`Network: ${NETWORK_TYPE}`);
  console.log(`Deployer: ${address}`);
  console.log(`New Treasury: ${newTreasuryAddress}`);
  console.log('');

  const txOptions = {
    contractAddress: address,
    contractName: 'adam-swap-v2',
    functionName: 'set-treasury-address',
    functionArgs: [standardPrincipalCV(newTreasuryAddress)],
    senderKey: privateKey,
    network,
    anchorMode: AnchorMode.Any,
    postConditionMode: PostConditionMode.Allow,
  };

  console.log('📤 Broadcasting transaction...');
  const transaction = await makeContractCall(txOptions);
  const result = await broadcastTransaction({ transaction, network });

  if ('error' in result) {
    console.error(`❌ Failed:`, result.error);
    if ('reason' in result) {
      console.error(`Reason:`, result.reason);
    }
    process.exit(1);
  }

  console.log(`Transaction ID: ${result.txid}`);
  await waitForTx(result.txid);

  console.log('');
  console.log('✅ Treasury address updated successfully!');
  console.log(`View transaction: https://explorer.hiro.so/txid/${result.txid}?chain=${NETWORK_TYPE}`);
}

main().catch(console.error);
