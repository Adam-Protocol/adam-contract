#!/usr/bin/env tsx

/**
 * Adam Swap V3 Initialization Script
 * Initializes the adam-swap-v3 contract with proper configuration
 * 
 * Usage: pnpm run v3:init
 */

import {
  makeContractCall,
  broadcastTransaction,
  AnchorMode,
  PostConditionMode,
  uintCV,
  standardPrincipalCV,
  contractPrincipalCV,
  stringAsciiCV,
  boolCV,
} from '@stacks/transactions';
import { STACKS_TESTNET, STACKS_MAINNET } from '@stacks/network';
import { generateWallet, getStxAddress } from '@stacks/wallet-sdk';
import dotenv from 'dotenv';

dotenv.config();

const MNEMONIC = process.env.STACKS_DEPLOYER_PRIVATE_KEY?.replace(/"/g, '') || '';
const NETWORK_TYPE = process.env.STACKS_NETWORK || 'testnet';
const network = NETWORK_TYPE === 'mainnet' ? STACKS_MAINNET : STACKS_TESTNET;
const API_URL = NETWORK_TYPE === 'mainnet' ? 'https://api.hiro.so' : 'https://api.testnet.hiro.so';

// Configuration from .env
const TREASURY_ADDRESS = process.env.STACKS_TREASURY_ADDRESS || '';
const BACKEND_ADDRESS = process.env.STACKS_BACKEND_ADDRESS || '';
const SWAP_FEE_BPS = process.env.SWAP_FEE_BPS || '50';

// Exchange rates from .env (in 1e6 precision)
const RATES = {
  USDC_ADUSD: process.env.RATE_USDC_ADUSD || '1000000',
  ADUSD_USDC: process.env.RATE_ADUSD_USDC || '1000000',
  USDC_ADNGN: process.env.RATE_USDC_ADNGN || '1383050000',
  ADNGN_USDC: process.env.RATE_ADNGN_USDC || '723',
  USDC_ADKES: process.env.RATE_USDC_ADKES || '129320000',
  ADKES_USDC: process.env.RATE_ADKES_USDC || '7733',
  USDC_ADGHS: process.env.RATE_USDC_ADGHS || '10910000',
  ADGHS_USDC: process.env.RATE_ADGHS_USDC || '91660',
  USDC_ADZAR: process.env.RATE_USDC_ADZAR || '17080000',
  ADZAR_USDC: process.env.RATE_ADZAR_USDC || '58548',
};

// Token configurations
const TOKENS = [
  { name: 'adusd', symbol: 'adusd', contract: 'adam-token-adusd-v3' },
  { name: 'adngn', symbol: 'adngn', contract: 'adam-token-adngn-v3' },
  { name: 'adkes', symbol: 'adkes', contract: 'adam-token-adkes-v3' },
  { name: 'adghs', symbol: 'adghs', contract: 'adam-token-adghs-v3' },
  { name: 'adzar', symbol: 'adzar', contract: 'adam-token-adzar-v3' },
];

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
  const address = getStxAddress({ account, network: NETWORK_TYPE });
  const privateKey = account.stxPrivateKey;

  return { address, privateKey };
}

async function waitForTx(txid: string): Promise<boolean> {
  console.log(`   ⏳ Waiting for ${txid.slice(0, 8)}...`);

  for (let i = 0; i < 60; i++) { // Increased timeout for testnet
    try {
      const response = await fetch(`${API_URL}/extended/v1/tx/${txid}`);
      const data = await response.json();

      if (data.tx_status === 'success') {
        console.log(`   ✅ Confirmed`);
        return true;
      } else if (data.tx_status?.includes('abort')) {
        console.log(`   ❌ Failed: ${data.tx_status}`);
        return false;
      }
    } catch (e) { }

    await new Promise(resolve => setTimeout(resolve, 10000));
  }

  console.log(`   ⚠️  Timeout`);
  return false;
}

async function callContract(
  contractName: string,
  functionName: string,
  args: any[],
  privateKey: string,
  address: string
) {
  const txOptions = {
    contractAddress: address,
    contractName,
    functionName,
    functionArgs: args,
    senderKey: privateKey,
    network,
    anchorMode: AnchorMode.Any,
    postConditionMode: PostConditionMode.Allow,
  };

  const transaction = await makeContractCall(txOptions);
  const result = await broadcastTransaction({ transaction, network });

  if ('error' in result) {
    console.error(`   ❌ Failed:`, result.error);
    if ('reason' in result) {
      console.error(`   Reason:`, result.reason);
    }
    return null;
  }

  return result.txid;
}

async function main() {
  const { address, privateKey } = await getWalletInfo();
  const treasury = TREASURY_ADDRESS || address;

  console.log('=========================================');
  console.log('🚀 Adam Protocol V3 Initialization');
  console.log('=========================================');
  console.log(`Network: ${NETWORK_TYPE}`);
  console.log(`Deployer: ${address}`);
  console.log(`Treasury: ${treasury}`);
  console.log(`Fee: ${Number(SWAP_FEE_BPS) / 100}%`);
  console.log('');

  // Step 1: Initialize tokens
  console.log('Step 1: Initializing tokens with 6 decimals...');
  for (const token of TOKENS) {
    console.log(`  ${token.symbol}...`);
    const txid = await callContract(
      token.contract,
      'initialize',
      [
        stringAsciiCV(token.name),
        stringAsciiCV(token.symbol),
        uintCV(6), // Set to 6 decimals
        standardPrincipalCV(address),
      ],
      privateKey,
      address
    );
    if (txid) await waitForTx(txid);
  }
  console.log('✅ Tokens initialized\n');

  // Step 2: Initialize swap
  console.log('Step 2: Initializing swap-v3 contract...');
  const swapTxid = await callContract(
    'adam-swap-v3',
    'initialize',
    [
      standardPrincipalCV(address),
      standardPrincipalCV(treasury),
      contractPrincipalCV(address, 'usdcx-v3'),
      contractPrincipalCV(address, 'adam-token-adusd-v3'),
      contractPrincipalCV(address, 'adam-token-adngn-v3'),
      contractPrincipalCV(address, 'adam-token-adkes-v3'),
      contractPrincipalCV(address, 'adam-token-adghs-v3'),
      contractPrincipalCV(address, 'adam-token-adzar-v3'),
      uintCV(parseInt(SWAP_FEE_BPS)),
    ],
    privateKey,
    address
  );
  if (swapTxid) await waitForTx(swapTxid);
  console.log('✅ Swap-v3 initialized\n');

  // Step 2: Grant minter roles
  console.log('Step 2: Granting minter roles to swap-v3...');
  for (const token of TOKENS) {
    console.log(`  ${token.symbol}...`);
    const txid = await callContract(
      token.contract,
      'set-minter',
      [contractPrincipalCV(address, 'adam-swap-v3'), boolCV(true)],
      privateKey,
      address
    );
    if (txid) await waitForTx(txid);
  }
  console.log('✅ Minter roles granted\n');

  // Step 3: Grant burner roles
  console.log('Step 3: Granting burner roles to swap-v3...');
  for (const token of TOKENS) {
    console.log(`  ${token.symbol}...`);
    const txid = await callContract(
      token.contract,
      'set-burner',
      [contractPrincipalCV(address, 'adam-swap-v3'), boolCV(true)],
      privateKey,
      address
    );
    if (txid) await waitForTx(txid);
  }
  console.log('✅ Burner roles granted\n');

  // Step 4: Set exchange rates
  console.log('Step 4: Setting exchange rates in swap-v3...');

  const rateConfigs = [
    { from: 'usdcx-v3', to: 'adam-token-adusd-v3', rate: RATES.USDC_ADUSD, label: 'USDC → ADUSD' },
    { from: 'adam-token-adusd-v3', to: 'usdcx-v3', rate: RATES.ADUSD_USDC, label: 'ADUSD → USDC' },
    { from: 'usdcx-v3', to: 'adam-token-adngn-v3', rate: RATES.USDC_ADNGN, label: 'USDC → ADNGN' },
    { from: 'adam-token-adngn-v3', to: 'usdcx-v3', rate: RATES.ADNGN_USDC, label: 'ADNGN → USDC' },
    { from: 'usdcx-v3', to: 'adam-token-adkes-v3', rate: RATES.USDC_ADKES, label: 'USDC → ADKES' },
    { from: 'adam-token-adkes-v3', to: 'usdcx-v3', rate: RATES.ADKES_USDC, label: 'ADKES → USDC' },
    { from: 'usdcx-v3', to: 'adam-token-adghs-v3', rate: RATES.USDC_ADGHS, label: 'USDC → ADGHS' },
    { from: 'adam-token-adghs-v3', to: 'usdcx-v3', rate: RATES.ADGHS_USDC, label: 'ADGHS → USDC' },
    { from: 'usdcx-v3', to: 'adam-token-adzar-v3', rate: RATES.USDC_ADZAR, label: 'USDC → ADZAR' },
    { from: 'adam-token-adzar-v3', to: 'usdcx-v3', rate: RATES.ADZAR_USDC, label: 'ADZAR → USDC' },
  ];

  for (const config of rateConfigs) {
    console.log(`  ${config.label}...`);
    const txid = await callContract(
      'adam-swap-v3',
      'set-rate',
      [
        contractPrincipalCV(address, config.from),
        contractPrincipalCV(address, config.to),
        uintCV(parseInt(config.rate)),
      ],
      privateKey,
      address
    );
    if (txid) await waitForTx(txid);
  }
  console.log('✅ Exchange rates set\n');

  // Step 5: Grant backend rate-setter role (if configured)
  if (BACKEND_ADDRESS) {
    console.log('Step 5: Granting backend rate-setter role...');
    const txid = await callContract(
      'adam-swap-v3',
      'set-rate-setter',
      [standardPrincipalCV(BACKEND_ADDRESS), boolCV(true)],
      privateKey,
      address
    );
    if (txid) await waitForTx(txid);
    console.log('✅ Backend role granted\n');
  }

  // Summary
  console.log('=========================================');
  console.log('✅ Initialization Complete!');
  console.log('=========================================');
  console.log('');
  console.log('Contract Addresses:');
  console.log(`  SWAP: ${address}.adam-swap-v3`);
  console.log(`  USDCX: ${address}.usdcx-v3`);
  console.log('');
  console.log(`View contracts: https://explorer.hiro.so/address/${address}?chain=${NETWORK_TYPE}`);
}

main().catch(console.error);
