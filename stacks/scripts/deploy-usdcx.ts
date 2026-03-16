import {
  makeContractDeploy,
  broadcastTransaction,
  AnchorMode,
  PostConditionMode,
} from '@stacks/transactions';
import { STACKS_TESTNET } from '@stacks/network';
import { generateWallet, getStxAddress } from '@stacks/wallet-sdk';
import * as fs from 'fs';
import * as path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const MNEMONIC = process.env.STACKS_DEPLOYER_PRIVATE_KEY?.replace(/"/g, '') || '';

async function deployUSDCX() {
  // Generate wallet from mnemonic
  const wallet = await generateWallet({
    secretKey: MNEMONIC,
    password: '',
  });
  
  const account = wallet.accounts[0];
  const DEPLOYER_ADDRESS = getStxAddress({ account, network: 'testnet' });
  const DEPLOYER_KEY = account.stxPrivateKey;

  console.log('🚀 Deploying USDCX Token Contract...\n');
  console.log(`Deployer: ${DEPLOYER_ADDRESS}`);
  console.log(`Network: Stacks Testnet\n`);
  
  // Read contract source
  const contractPath = path.join(__dirname, '../contracts/usdcx.clar');
  const contractSource = fs.readFileSync(contractPath, 'utf8');

  try {
    // Deploy contract
    const txOptions = {
      contractName: 'usdcx',
      codeBody: contractSource,
      senderKey: DEPLOYER_KEY,
      network: STACKS_TESTNET,
      anchorMode: AnchorMode.Any,
      postConditionMode: PostConditionMode.Allow,
    };

    const transaction = await makeContractDeploy(txOptions);
    const broadcastResponse = await broadcastTransaction({ transaction, network: STACKS_TESTNET });

    if ('error' in broadcastResponse) {
      console.error('❌ Deployment failed:', broadcastResponse.error);
      if ('reason' in broadcastResponse) {
        console.error('Reason:', broadcastResponse.reason);
      }
      process.exit(1);
    }

    console.log('✅ Contract deployed successfully!');
    console.log(`Transaction ID: ${broadcastResponse.txid}`);
    console.log(`\nContract Address: ${DEPLOYER_ADDRESS}.usdcx`);
    console.log(`\nView transaction: https://explorer.hiro.so/txid/${broadcastResponse.txid}?chain=testnet`);
    
    console.log('\n📝 Update your backend .env file with:');
    console.log(`STACKS_USDCx_ADDRESS=${DEPLOYER_ADDRESS}.usdcx`);

    console.log('\n⏳ Waiting for contract deployment to confirm...');
    console.log('This may take a few minutes. Once confirmed, run: pnpm run mint:usdcx');
    
  } catch (error) {
    console.error('❌ Error deploying contract:', error);
    process.exit(1);
  }
}

deployUSDCX();
