#!/usr/bin/env tsx

/**
 * Adam Protocol V3 Deployment Script
 * Deploys all V3 contracts to testnet/mainnet
 * 
 * Usage: pnpm run v3:deploy
 */

import {
    makeContractDeploy,
    broadcastTransaction,
    AnchorMode,
    PostConditionMode,
} from '@stacks/transactions';
import { STACKS_TESTNET, STACKS_MAINNET } from '@stacks/network';
import { generateWallet, getStxAddress } from '@stacks/wallet-sdk';
import { readFileSync } from 'fs';
import { join } from 'path';
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

async function contractExists(address: string, contractName: string): Promise<boolean> {
    try {
        const response = await fetch(`${API_URL}/v2/contracts/interface/${address}/${contractName}`);
        return response.status === 200;
    } catch (e) {
        return false;
    }
}

async function deployContract(
    contractName: string,
    contractPath: string,
    privateKey: string,
    nonce: number
) {
    const codeBody = readFileSync(join(process.cwd(), contractPath), 'utf8');

    const txOptions = {
        contractName,
        codeBody,
        senderKey: privateKey,
        network,
        anchorMode: AnchorMode.Any,
        postConditionMode: PostConditionMode.Allow,
        nonce,
        clarityVersion: 2,
    };

    const transaction = await makeContractDeploy(txOptions);
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
    console.log('🚀 Adam Protocol V3 Deployment');
    console.log('=========================================');
    console.log(`Network: ${NETWORK_TYPE}`);
    console.log(`Deployer: ${address}`);
    console.log('');

    const contracts = [
        { name: 'usdcx-v3', path: 'contracts/usdcx-v3.clar' },
        { name: 'adam-token-adusd-v3', path: 'contracts/adam-token-v3.clar' },
        { name: 'adam-token-adngn-v3', path: 'contracts/adam-token-v3.clar' },
        { name: 'adam-token-adkes-v3', path: 'contracts/adam-token-v3.clar' },
        { name: 'adam-token-adghs-v3', path: 'contracts/adam-token-v3.clar' },
        { name: 'adam-token-adzar-v3', path: 'contracts/adam-token-v3.clar' },
        { name: 'adam-swap-v3', path: 'contracts/adam-swap-v3.clar' },
    ];

    console.log('Fetching current nonce...');
    let nonce = await getNonce(address);
    console.log(`Starting nonce: ${nonce}`);
    console.log('');

    console.log('Deploying contracts...');
    for (const contract of contracts) {
        console.log(`  📦 ${contract.name}...`);

        // Check if already exists
        const exists = await contractExists(address, contract.name);
        if (exists) {
            console.log(`   ✅ Already exists, skipping deployment`);
            continue;
        }

        const txid = await deployContract(
            contract.name,
            contract.path,
            privateKey,
            nonce
        );

        if (txid) {
            nonce++;
            await waitForTx(txid);
        } else {
            console.log(`   ⚠️  Broadcast failed, skipping...`);
            // DO NOT increment nonce if it fails to broadcast
        }
    }

    console.log('');
    console.log('=========================================');
    console.log('✅ Deployment Complete!');
    console.log('=========================================');
    console.log('');
    console.log('Next steps:');
    console.log('1. Run: pnpm run v3:init');
    console.log('   This will initialize all contracts and set up rates');
    console.log('');
    console.log(`View contracts: https://explorer.hiro.so/address/${address}?chain=${NETWORK_TYPE}`);
}

main().catch(console.error);
