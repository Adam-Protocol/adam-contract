#!/usr/bin/env tsx

/**
 * Check if rates are set in adam-swap-v3 contract
 */

import {
    Cl,
    cvToValue,
    fetchCallReadOnlyFunction,
} from '@stacks/transactions';
import { STACKS_TESTNET, STACKS_MAINNET } from '@stacks/network';
import { generateWallet, getStxAddress } from '@stacks/wallet-sdk';
import dotenv from 'dotenv';

dotenv.config();

const MNEMONIC = process.env.STACKS_DEPLOYER_PRIVATE_KEY?.replace(/"/g, '') || '';
const NETWORK_TYPE = process.env.STACKS_NETWORK || 'testnet';
const network = NETWORK_TYPE === 'mainnet' ? STACKS_MAINNET : STACKS_TESTNET;

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

async function checkRate(
    contractAddress: string,
    contractName: string,
    fromContract: string,
    toContract: string,
    label: string
) {
    try {
        const [fromAddr, fromName] = fromContract.split('.');
        const [toAddr, toName] = toContract.split('.');

        const response = await fetchCallReadOnlyFunction({
            contractAddress,
            contractName,
            functionName: 'get-rate',
            functionArgs: [
                Cl.contractPrincipal(fromAddr, fromName),
                Cl.contractPrincipal(toAddr, toName),
            ],
            network,
            senderAddress: contractAddress,
        });

        const value = cvToValue(response);

        if (value && 'value' in value) {
            const rate = BigInt(value.value);
            const rateFormatted = (Number(rate) / 1_000_000).toFixed(6);
            console.log(`✅ ${label}: ${rateFormatted}`);
            return true;
        } else {
            console.log(`❌ ${label}: No rate set (returned ${JSON.stringify(value)})`);
            return false;
        }
    } catch (error: any) {
        console.log(`❌ ${label}: Error - ${error.message}`);
        return false;
    }
}

async function main() {
    const { address } = await getWalletInfo();

    console.log('=========================================');
    console.log('🔍 Checking Adam Swap V3 Rates');
    console.log('=========================================');
    console.log(`Network: ${NETWORK_TYPE}`);
    console.log(`Contract: ${address}.adam-swap-v3`);
    console.log('');

    const ratesToCheck = [
        {
            from: `${address}.usdcx-v3`,
            to: `${address}.adam-token-adusd-v3`,
            label: 'USDC → ADUSD',
        },
        {
            from: `${address}.usdcx-v3`,
            to: `${address}.adam-token-adngn-v3`,
            label: 'USDC → ADNGN',
        },
        {
            from: `${address}.adam-token-adngn-v3`,
            to: `${address}.usdcx-v3`,
            label: 'ADNGN → USDC',
        },
        {
            from: `${address}.usdcx-v3`,
            to: `${address}.adam-token-adkes-v3`,
            label: 'USDC → ADKES',
        },
        {
            from: `${address}.usdcx-v3`,
            to: `${address}.adam-token-adghs-v3`,
            label: 'USDC → ADGHS',
        },
        {
            from: `${address}.usdcx-v3`,
            to: `${address}.adam-token-adzar-v3`,
            label: 'USDC → ADZAR',
        },
    ];

    let allSet = true;
    for (const config of ratesToCheck) {
        const isSet = await checkRate(
            address,
            'adam-swap-v3',
            config.from,
            config.to,
            config.label
        );
        if (!isSet) allSet = false;
    }

    console.log('');
    if (allSet) {
        console.log('✅ All rates are set correctly!');
    } else {
        console.log('❌ Some rates are missing. Run: pnpm run v3:init');
    }
    console.log('=========================================');
}

main().catch(console.error);
