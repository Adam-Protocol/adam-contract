#!/usr/bin/env tsx

/**
 * Adam Swap V3 Rate Update Script
 * Updates exchange rates in the adam-swap-v3 contract
 * 
 * Usage: pnpm run update-rates
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
import { generateWallet, getStxAddress } from '@stacks/wallet-sdk';
import dotenv from 'dotenv';

dotenv.config();

const MNEMONIC = process.env.STACKS_DEPLOYER_PRIVATE_KEY?.replace(/"/g, '') || '';
const NETWORK_TYPE = process.env.STACKS_NETWORK || 'testnet';
const network = NETWORK_TYPE === 'mainnet' ? STACKS_MAINNET : STACKS_TESTNET;
const API_URL = NETWORK_TYPE === 'mainnet' ? 'https://api.hiro.so' : 'https://api.testnet.hiro.so';

// Exchange rates from .env (in 1e6 precision - matches contract)
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
    // Direct ADUSD to other tokens
    ADUSD_ADNGN: process.env.RATE_ADUSD_ADNGN || '1383050000',
    ADNGN_ADUSD: process.env.RATE_ADNGN_ADUSD || '723',
    ADUSD_ADKES: process.env.RATE_ADUSD_ADKES || '129320000',
    ADKES_ADUSD: process.env.RATE_ADKES_ADUSD || '7733',
    ADUSD_ADGHS: process.env.RATE_ADUSD_ADGHS || '10910000',
    ADGHS_ADUSD: process.env.RATE_ADGHS_ADUSD || '91660',
    ADUSD_ADZAR: process.env.RATE_ADUSD_ADZAR || '17080000',
    ADZAR_ADUSD: process.env.RATE_ADZAR_ADUSD || '58548',
};

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

async function waitForTx(txid: string): Promise<boolean> {
    console.log(`   ⏳ Waiting for ${txid.slice(0, 8)}...`);

    for (let i = 0; i < 60; i++) {
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

async function setRate(
    contractName: string,
    fromContract: string,
    toContract: string,
    rate: string,
    privateKey: string,
    address: string,
    nonce: number
) {
    const txOptions = {
        contractAddress: address,
        contractName,
        functionName: 'set-rate',
        functionArgs: [
            contractPrincipalCV(address, fromContract),
            contractPrincipalCV(address, toContract),
            uintCV(parseInt(rate)),
        ],
        senderKey: privateKey,
        network,
        anchorMode: AnchorMode.Any,
        postConditionMode: PostConditionMode.Allow,
        nonce,
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

    console.log('=========================================');
    console.log('🔄 Adam Protocol Rate Update');
    console.log('=========================================');
    console.log(`Network: ${NETWORK_TYPE}`);
    console.log(`Caller: ${address}`);
    console.log('');

    const rateConfigs = [
        // USDC to Adam tokens
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

        // Direct ADUSD to other Adam tokens
        { from: 'adam-token-adusd-v3', to: 'adam-token-adngn-v3', rate: RATES.ADUSD_ADNGN, label: 'ADUSD → ADNGN' },
        { from: 'adam-token-adngn-v3', to: 'adam-token-adusd-v3', rate: RATES.ADNGN_ADUSD, label: 'ADNGN → ADUSD' },
        { from: 'adam-token-adusd-v3', to: 'adam-token-adkes-v3', rate: RATES.ADUSD_ADKES, label: 'ADUSD → ADKES' },
        { from: 'adam-token-adkes-v3', to: 'adam-token-adusd-v3', rate: RATES.ADKES_ADUSD, label: 'ADKES → ADUSD' },
        { from: 'adam-token-adusd-v3', to: 'adam-token-adghs-v3', rate: RATES.ADUSD_ADGHS, label: 'ADUSD → ADGHS' },
        { from: 'adam-token-adghs-v3', to: 'adam-token-adusd-v3', rate: RATES.ADGHS_ADUSD, label: 'ADGHS → ADUSD' },
        { from: 'adam-token-adusd-v3', to: 'adam-token-adzar-v3', rate: RATES.ADUSD_ADZAR, label: 'ADUSD → ADZAR' },
        { from: 'adam-token-adzar-v3', to: 'adam-token-adusd-v3', rate: RATES.ADZAR_ADUSD, label: 'ADZAR → ADUSD' },
    ];

    console.log('Fetching current nonce...');
    let nonce = await getNonce(address);
    console.log(`Starting nonce: ${nonce}`);
    console.log('');

    console.log('Updating exchange rates...');
    for (const config of rateConfigs) {
        console.log(`  ${config.label}: ${config.rate}`);
        const txid = await setRate(
            'adam-swap-v3',
            config.from,
            config.to,
            config.rate,
            privateKey,
            address,
            nonce
        );
        if (txid) {
            nonce++; // Increment nonce for next transaction
            await waitForTx(txid);
        } else {
            console.log(`   ⚠️  Skipping due to failure`);
            break; // Stop on first failure to avoid cascading errors
        }
    }

    console.log('');
    console.log('=========================================');
    console.log('✅ Rate Update Complete!');
    console.log('=========================================');
}

main().catch(console.error);
