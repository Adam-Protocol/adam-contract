#!/usr/bin/env tsx

/**
 * Check Treasury Address Script
 * Reads the current treasury address from the swap contract
 * 
 * Usage: pnpm run check-treasury
 */

import { cvToJSON, ClarityValue } from '@stacks/transactions';
import { STACKS_TESTNET, STACKS_MAINNET, StacksNetwork } from '@stacks/network';
import { generateWallet, getStxAddress } from '@stacks/wallet-sdk';
import dotenv from 'dotenv';

dotenv.config();

const MNEMONIC = process.env.STACKS_DEPLOYER_PRIVATE_KEY?.replace(/"/g, '') || '';
const NETWORK_TYPE = process.env.STACKS_NETWORK || 'testnet';
const network = NETWORK_TYPE === 'mainnet' ? STACKS_MAINNET : STACKS_TESTNET;
const API_URL = NETWORK_TYPE === 'mainnet' ? 'https://api.hiro.so' : 'https://api.testnet.hiro.so';

async function callReadOnly(
  contractAddress: string,
  contractName: string,
  functionName: string,
  network: StacksNetwork,
  senderAddress: string
): Promise<ClarityValue> {
  const url = `${API_URL}/v2/contracts/call-read/${contractAddress}/${contractName}/${functionName}`;
  
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      sender: senderAddress,
      arguments: [],
    }),
  });

  const data = await response.json();
  if (!data.okay) {
    throw new Error(`Read-only call failed: ${data.cause}`);
  }

  return data.result as ClarityValue;
}

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
  const address = getStxAddress({ account, transactionVersion: NETWORK_TYPE === 'mainnet' ? 22 : 26 });

  return { address };
}

async function main() {
  const { address } = await getWalletInfo();

  console.log('=========================================');
  console.log('🔍 Checking Treasury Configuration');
  console.log('=========================================');
  console.log(`Network: ${NETWORK_TYPE}`);
  console.log(`Deployer: ${address}`);
  console.log('');

  try {
    const result = await callReadOnly(
      address,
      'adam-swap-v2',
      'get-treasury-address',
      network,
      address
    );

    const jsonResult = cvToJSON(result);
    const treasuryAddress = jsonResult.value?.value;

    console.log(`Current Treasury: ${treasuryAddress}`);
    console.log('');

    if (treasuryAddress === address) {
      console.log('⚠️  WARNING: Treasury address is the same as deployer!');
      console.log('');
      console.log('This will cause error (err u2) when the deployer tries to buy tokens');
      console.log('because ft-transfer? fails when sender and recipient are the same.');
      console.log('');
      console.log('Solutions:');
      console.log('1. Use a different wallet address for testing (recommended)');
      console.log('2. Update treasury address: pnpm run update-treasury <new-address>');
    } else {
      console.log('✅ Treasury address is different from deployer');
    }
  } catch (error) {
    console.error('❌ Failed to read treasury address:', error);
    console.error('Make sure the contract is deployed and initialized.');
  }
}

main().catch(console.error);
