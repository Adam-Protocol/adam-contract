import { STACKS_TESTNET } from '@stacks/network';
import { callReadOnlyFunction, standardPrincipalCV } from '@stacks/transactions';
import { generateWallet, getStxAddress } from '@stacks/wallet-sdk';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

const MNEMONIC = process.env.STACKS_DEPLOYER_PRIVATE_KEY?.replace(/"/g, '') || '';

async function checkBalance() {
  // Generate wallet from mnemonic
  const wallet = await generateWallet({
    secretKey: MNEMONIC,
    password: '',
  });
  
  const account = wallet.accounts[0];
  const DEPLOYER_ADDRESS = getStxAddress({ account, network: 'testnet' });
  const CHECK_ADDRESS = process.argv[2] || DEPLOYER_ADDRESS;

  console.log('💰 Checking USDCX Balance...\n');
  console.log(`Contract: ${DEPLOYER_ADDRESS}.usdcx`);
  console.log(`Address: ${CHECK_ADDRESS}\n`);

  try {
    const result = await callReadOnlyFunction({
      contractAddress: DEPLOYER_ADDRESS,
      contractName: 'usdcx',
      functionName: 'get-balance',
      functionArgs: [standardPrincipalCV(CHECK_ADDRESS)],
      network: STACKS_TESTNET,
      senderAddress: CHECK_ADDRESS,
    });

    if (result.type === 'ok') {
      const balance = result.value.value;
      const formattedBalance = Number(balance) / 1_000000;
      
      console.log('✅ Balance retrieved successfully!');
      console.log(`\nRaw Balance: ${balance} micro-USDCX`);
      console.log(`Formatted Balance: ${formattedBalance} USDCX`);
    } else {
      console.error('❌ Failed to get balance:', result);
    }
  } catch (error) {
    console.error('❌ Error checking balance:', error);
    console.log('\n💡 Make sure the contract is deployed and confirmed on-chain.');
  }
}

checkBalance();
