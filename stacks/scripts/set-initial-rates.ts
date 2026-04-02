#!/usr/bin/env tsx

/**
 * Set initial rates for adam-swap-v3 (bypasses 20% limit for first-time setup)
 * This script sets rates one by one with proper nonce management
 */

import {
    makeContractCall,
    broadcastTransaction,
    AnchorMode,
    PostConditionMode,
    uintCV,
    contractPrincipalCV,
} from '@stacks/transactions';
import { STACKS_TESTNET, STACKS_MAINNET } from '@stacks/network';
import dotenv from 'dotenv';

dotenv.config();

// IMPORTANT: Use the actual deployer address from your frontend .env
const DEPLOYER_ADDRESS = 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191';
const NETWORK_TYPE = process.env.STACKS_NETWORK || 'testnet';
const network = NETWORK_TYPE === 'mainnet' ? STACKS_MAINNET : STACKS_TESTNET;
const API_URL = NETWORK_TYPE === 'mainnet' ? 'https://api.hiro.so' : 'https://api.testnet.hiro.so';

// Exchange rates from .env (in 1e6 precision)
const RATES = {
    USDC_ADUSD: '1000000',
    USDC_ADNGN: '1383050000',
    USDC_ADKES: '129320000',
    USDC_ADGHS: '10910000',
    USDC_ADZAR: '17080000',
};

async function getNonce(address: string): Promise<number> {
    try {
        const response = await fetch(`${API_URL}/v2/accounts/${address}?proof=0`);
        const data = await response.json();
        return data.nonce || 0;
    } catch (e) {
        console.error('Error fetching nonce:', e);
        return 0;
    }
}

async function main() {
    console.log('=========================================');
    console.log('📝 Manual Rate Setup Instructions');
    console.log('=========================================');
    console.log(`Network: ${NETWORK_TYPE}`);
    console.log(`Contract: ${DEPLOYER_ADDRESS}.adam-swap-v3`);
    console.log('');
    console.log('Since the mnemonic in .env doesn\'t match the deployer address,');
    console.log('you need to set rates manually using Leather wallet or Stacks Explorer.');
    console.log('');
    console.log('Option 1: Using Leather Wallet');
    console.log('------------------------------');
    console.log('1. Open Leather wallet and connect to testnet');
    console.log('2. Go to the contract call page');
    console.log(`3. Contract: ${DEPLOYER_ADDRESS}.adam-swap-v3`);
    console.log('4. Function: set-rate');
    console.log('5. Call it multiple times with these parameters:');
    console.log('');

    const rateConfigs = [
        { from: 'usdcx-v3', to: 'adam-token-adusd-v3', rate: RATES.USDC_ADUSD, label: 'USDC → ADUSD' },
        { from: 'usdcx-v3', to: 'adam-token-adngn-v3', rate: RATES.USDC_ADNGN, label: 'USDC → ADNGN' },
        { from: 'usdcx-v3', to: 'adam-token-adkes-v3', rate: RATES.USDC_ADKES, label: 'USDC → ADKES' },
        { from: 'usdcx-v3', to: 'adam-token-adghs-v3', rate: RATES.USDC_ADGHS, label: 'USDC → ADGHS' },
        { from: 'usdcx-v3', to: 'adam-token-adzar-v3', rate: RATES.USDC_ADZAR, label: 'USDC → ADZAR' },
    ];

    rateConfigs.forEach((config, index) => {
        console.log(`Call ${index + 1}: ${config.label}`);
        console.log(`  token-from: ${DEPLOYER_ADDRESS}.${config.from}`);
        console.log(`  token-to: ${DEPLOYER_ADDRESS}.${config.to}`);
        console.log(`  rate: ${config.rate}`);
        console.log('');
    });

    console.log('');
    console.log('Option 2: Using Stacks Explorer');
    console.log('--------------------------------');
    console.log(`1. Visit: https://explorer.hiro.so/txid/${DEPLOYER_ADDRESS}.adam-swap-v3?chain=${NETWORK_TYPE}`);
    console.log('2. Click "Call Function"');
    console.log('3. Select "set-rate" function');
    console.log('4. Fill in the parameters from above');
    console.log('5. Sign with your wallet');
    console.log('');

    console.log('Option 3: Fix the Mnemonic');
    console.log('--------------------------');
    console.log('Update STACKS_DEPLOYER_PRIVATE_KEY in .env to match the mnemonic');
    console.log(`that generates address: ${DEPLOYER_ADDRESS}`);
    console.log('Then run: pnpm run v3:init');
    console.log('');

    console.log('=========================================');
    console.log('After setting rates, verify with:');
    console.log('npx tsx scripts/check-rates.ts');
    console.log('=========================================');
}

main().catch(console.error);
