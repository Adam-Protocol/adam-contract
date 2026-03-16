import {
  makeContractCall,
  broadcastTransaction,
  AnchorMode,
  PostConditionMode,
  uintCV,
  standardPrincipalCV,
} from '@stacks/transactions';
import { STACKS_TESTNET } from '@stacks/network';
import { generateWallet, getStxAddress } from '@stacks/wallet-sdk';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

const MNEMONIC = process.env.STACKS_DEPLOYER_PRIVATE_KEY?.replace(/"/g, '') || '';
const AMOUNT = 100_000000; // 100 USDCX (6 decimals)

async function mintUSDCX() {
  // Generate wallet from mnemonic
  const wallet = await generateWallet({
    secretKey: MNEMONIC,
    password: '',
  });
  
  const account = wallet.accounts[0];
  const DEPLOYER_ADDRESS = getStxAddress({ account, network: 'testnet' });
  const DEPLOYER_KEY = account.stxPrivateKey;
  const RECIPIENT_ADDRESS = DEPLOYER_ADDRESS;

  console.log('💰 Minting USDCX Tokens...\n');
  console.log(`Contract: ${DEPLOYER_ADDRESS}.usdcx`);
  console.log(`Recipient: ${RECIPIENT_ADDRESS}`);
  console.log(`Amount: ${AMOUNT / 1_000000} USDCX\n`);

  try {
    const txOptions = {
      contractAddress: DEPLOYER_ADDRESS,
      contractName: 'usdcx',
      functionName: 'mint',
      functionArgs: [
        uintCV(AMOUNT),
        standardPrincipalCV(RECIPIENT_ADDRESS),
      ],
      senderKey: DEPLOYER_KEY,
      network: STACKS_TESTNET,
      anchorMode: AnchorMode.Any,
      postConditionMode: PostConditionMode.Allow,
    };

    const transaction = await makeContractCall(txOptions);
    const broadcastResponse = await broadcastTransaction({ transaction, network: STACKS_TESTNET });

    if ('error' in broadcastResponse) {
      console.error('❌ Minting failed:', broadcastResponse.error);
      if ('reason' in broadcastResponse) {
        console.error('Reason:', broadcastResponse.reason);
      }
      process.exit(1);
    }

    console.log('✅ Tokens minted successfully!');
    console.log(`Transaction ID: ${broadcastResponse.txid}`);
    console.log(`\nView transaction: https://explorer.hiro.so/txid/${broadcastResponse.txid}?chain=testnet`);
    console.log(`\n🎉 ${AMOUNT / 1_000000} USDCX tokens will be available at ${RECIPIENT_ADDRESS} once confirmed.`);
    
  } catch (error) {
    console.error('❌ Error minting tokens:', error);
    process.exit(1);
  }
}

mintUSDCX();
