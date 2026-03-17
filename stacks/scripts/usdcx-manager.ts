#!/usr/bin/env tsx

/**
 * USDCX Token Manager
 * Consolidated script for deploying, minting, and checking USDCX test token
 * 
 * Usage:
 *   npx tsx scripts/usdcx-manager.ts deploy
 *   npx tsx scripts/usdcx-manager.ts mint <recipient> <amount>
 *   npx tsx scripts/usdcx-manager.ts balance <address>
 *   npx tsx scripts/usdcx-manager.ts quick-setup
 */

import {
  makeContractDeploy,
  makeContractCall,
  broadcastTransaction,
  callReadOnlyFunction,
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

// Helper to get wallet info
async function getWalletInfo() {
  if (!MNEMONIC) {
    console.error('❌ Error: STACKS_DEPLOYER_PRIVATE_KEY not set in .env file');
    process.exit(1);
  }

  const wallet = await generateWallet({
    secretKey: MNEMONIC,
    password: '',
  });
  
  const account = wallet.accounts[0];
  const address = getStxAddress({ account, network: 'testnet' });
  const privateKey = account.stxPrivateKey;

  return { address, privateKey };
}

// Helper to wait for transaction
async function waitForTransaction(txid: string, maxAttempts = 30): Promise<boolean> {
  console.log(`⏳ Waiting for transaction ${txid} to confirm...`);
  
  for (let i = 0; i < maxAttempts; i++) {
    try {
      const response = await fetch(`${network.url}/extended/v1/tx/${txid}`);
      const data = await response.json();
      
      if (data.tx_status === 'success') {
        console.log('✅ Transaction confirmed');
        return true;
      } else if (data.tx_status === 'abort_by_response' || data.tx_status === 'abort_by_post_condition') {
        console.log(`❌ Transaction failed: ${data.tx_status}`);
        return false;
      }
    } catch (e) {
      // Transaction not found yet
    }
    
    await new Promise(resolve => setTimeout(resolve, 10000));
  }
  
  console.log(`⚠️  Transaction not confirmed after ${maxAttempts * 10} seconds`);
  return false;
}

// Command: Deploy USDCX
async function deployUSDCX() {
  const { address, privateKey } = await getWalletInfo();

  console.log('========================================');
  console.log('🚀 Deploying USDCX Token Contract');
  console.log('========================================');
  console.log(`Deployer: ${address}`);
  console.log(`Network: Stacks Testnet\n`);
  
  const contractPath = path.join(__dirname, '../contracts/usdcx.clar');
  const contractSource = fs.readFileSync(contractPath, 'utf8');

  try {
    const txOptions = {
      contractName: 'usdcx',
      codeBody: contractSource,
      senderKey: privateKey,
      network,
      anchorMode: AnchorMode.Any,
      postConditionMode: PostConditionMode.Allow,
    };

    const transaction = await makeContractDeploy(txOptions);
    const result = await broadcastTransaction({ transaction, network });

    if ('error' in result) {
      console.error('❌ Deployment failed:', result.error);
      if ('reason' in result) {
        console.error('Reason:', result.reason);
      }
      process.exit(1);
    }

    console.log('✅ Contract deployed successfully!');
    console.log(`Transaction ID: ${result.txid}`);
    console.log(`Contract Address: ${address}.usdcx`);
    console.log(`\nView: https://explorer.hiro.so/txid/${result.txid}?chain=testnet`);
    
    await waitForTransaction(result.txid);
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

// Command: Mint USDCX
async function mintUSDCX(recipient?: string, amount?: string) {
  const { address, privateKey } = await getWalletInfo();
  
  const recipientAddress = recipient || address;
  const mintAmount = amount ? parseInt(amount) : 100_000000; // Default 100 USDCX

  console.log('========================================');
  console.log('💰 Minting USDCX Tokens');
  console.log('========================================');
  console.log(`Contract: ${address}.usdcx`);
  console.log(`Recipient: ${recipientAddress}`);
  console.log(`Amount: ${mintAmount / 1_000000} USDCX\n`);

  try {
    const txOptions = {
      contractAddress: address,
      contractName: 'usdcx',
      functionName: 'mint',
      functionArgs: [
        uintCV(mintAmount),
        standardPrincipalCV(recipientAddress),
      ],
      senderKey: privateKey,
      network,
      anchorMode: AnchorMode.Any,
      postConditionMode: PostConditionMode.Allow,
    };

    const transaction = await makeContractCall(txOptions);
    const result = await broadcastTransaction({ transaction, network });

    if ('error' in result) {
      console.error('❌ Minting failed:', result.error);
      if ('reason' in result) {
        console.error('Reason:', result.reason);
      }
      process.exit(1);
    }

    console.log('✅ Tokens minted successfully!');
    console.log(`Transaction ID: ${result.txid}`);
    console.log(`\nView: https://explorer.hiro.so/txid/${result.txid}?chain=testnet`);
    
    await waitForTransaction(result.txid);
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

// Command: Check Balance
async function checkBalance(checkAddress?: string) {
  const { address } = await getWalletInfo();
  const targetAddress = checkAddress || address;

  console.log('========================================');
  console.log('💰 Checking USDCX Balance');
  console.log('========================================');
  console.log(`Contract: ${address}.usdcx`);
  console.log(`Address: ${targetAddress}\n`);

  try {
    const result = await callReadOnlyFunction({
      contractAddress: address,
      contractName: 'usdcx',
      functionName: 'get-balance',
      functionArgs: [standardPrincipalCV(targetAddress)],
      network,
      senderAddress: targetAddress,
    });

    if (result.type === 'ok') {
      const balance = result.value.value;
      const formatted = Number(balance) / 1_000000;
      
      console.log('✅ Balance retrieved successfully!');
      console.log(`\nRaw: ${balance} micro-USDCX`);
      console.log(`Formatted: ${formatted} USDCX`);
    } else {
      console.error('❌ Failed to get balance:', result);
    }
  } catch (error) {
    console.error('❌ Error:', error);
    console.log('\n💡 Make sure the contract is deployed and confirmed.');
  }
}

// Command: Quick Setup (deploy + mint)
async function quickSetup() {
  console.log('========================================');
  console.log('⚡ USDCX Quick Setup');
  console.log('========================================\n');
  
  console.log('This will:');
  console.log('1. Deploy USDCX contract');
  console.log('2. Wait for confirmation');
  console.log('3. Mint 100 USDCX to deployer');
  console.log('4. Check balance\n');
  
  await deployUSDCX();
  
  console.log('\n⏳ Waiting 30 seconds for deployment to confirm...');
  await new Promise(resolve => setTimeout(resolve, 30000));
  
  await mintUSDCX();
  
  console.log('\n⏳ Waiting 30 seconds for minting to confirm...');
  await new Promise(resolve => setTimeout(resolve, 30000));
  
  await checkBalance();
  
  console.log('\n========================================');
  console.log('✅ Quick Setup Complete!');
  console.log('========================================');
}

// Main CLI handler
async function main() {
  const command = process.argv[2];
  
  switch (command) {
    case 'deploy':
      await deployUSDCX();
      break;
      
    case 'mint':
      const recipient = process.argv[3];
      const amount = process.argv[4];
      await mintUSDCX(recipient, amount);
      break;
      
    case 'balance':
      const checkAddr = process.argv[3];
      await checkBalance(checkAddr);
      break;
      
    case 'quick-setup':
      await quickSetup();
      break;
      
    default:
      console.log('USDCX Token Manager');
      console.log('==================\n');
      console.log('Usage:');
      console.log('  npx tsx scripts/usdcx-manager.ts deploy');
      console.log('  npx tsx scripts/usdcx-manager.ts mint [recipient] [amount]');
      console.log('  npx tsx scripts/usdcx-manager.ts balance [address]');
      console.log('  npx tsx scripts/usdcx-manager.ts quick-setup');
      console.log('\nExamples:');
      console.log('  npx tsx scripts/usdcx-manager.ts deploy');
      console.log('  npx tsx scripts/usdcx-manager.ts mint ST2NEB... 1000000000');
      console.log('  npx tsx scripts/usdcx-manager.ts balance ST2NEB...');
      console.log('  npx tsx scripts/usdcx-manager.ts quick-setup');
      process.exit(1);
  }
}

main().catch(console.error);
