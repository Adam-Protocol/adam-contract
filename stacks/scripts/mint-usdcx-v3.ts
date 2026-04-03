#!/usr/bin/env tsx

/**
 * USDCX V3 Token Minter
 * Mints USDCX V3 tokens to a specified recipient
 * 
 * Usage:
 *   pnpm run mint-usdcx-v3 <recipient> <amount>
 *   Example: pnpm run mint-usdcx-v3 ST2TG1NCSKMKGTJJHZETNZ83H0ARSQVNJPTR3MGG5 10000000
 */

import {
    makeContractCall,
    broadcastTransaction,
    AnchorMode,
    PostConditionMode,
    uintCV,
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
        console.error('❌ Error: STACKS_DEPLOYER_PRIVATE_KEY not set in .env file');
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

async function waitForTransaction(txid: string, maxAttempts = 30): Promise<boolean> {
    console.log(`⏳ Waiting for transaction ${txid} to confirm...`);

    for (let i = 0; i < maxAttempts; i++) {
        try {
            const response = await fetch(`${API_URL}/extended/v1/tx/${txid}`);
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

async function mintUSDCXV3(recipient: string, amount: string) {
    const { address, privateKey } = await getWalletInfo();

    const mintAmount = parseInt(amount);
    if (isNaN(mintAmount) || mintAmount <= 0) {
        console.error('❌ Error: Amount must be a positive number');
        process.exit(1);
    }

    console.log('========================================');
    console.log('💰 Minting USDCX V3 Tokens');
    console.log('========================================');
    console.log(`Contract: ${address}.usdcx-v3`);
    console.log(`Recipient: ${recipient}`);
    console.log(`Amount: ${mintAmount / 1_000000} USDCX\n`);

    try {
        const txOptions = {
            contractAddress: address,
            contractName: 'usdcx-v3',
            functionName: 'mint',
            functionArgs: [
                uintCV(mintAmount),
                standardPrincipalCV(recipient),
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
        console.log(`\nView: https://explorer.hiro.so/txid/${result.txid}?chain=${NETWORK_TYPE}`);

        await waitForTransaction(result.txid);

    } catch (error) {
        console.error('❌ Error:', error);
        process.exit(1);
    }
}

async function main() {
    const recipient = process.argv[2];
    const amount = process.argv[3];

    if (!recipient || !amount) {
        console.log('USDCX V3 Token Minter');
        console.log('====================\n');
        console.log('Usage:');
        console.log('  pnpm run mint-usdcx-v3 <recipient> <amount>\n');
        console.log('Examples:');
        console.log('  pnpm run mint-usdcx-v3 ST2TG1NCSKMKGTJJHZETNZ83H0ARSQVNJPTR3MGG5 10000000');
        console.log('  (This mints 10 USDCX to the specified address)\n');
        process.exit(1);
    }

    await mintUSDCXV3(recipient, amount);
}

main().catch(console.error);
