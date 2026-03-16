import { 
  broadcastTransaction, 
  AnchorMode, 
  makeContractCall,
  stringAsciiCV,
  uintCV,
  principalCV,
  boolCV,
  PostConditionMode
} from '@stacks/transactions';
import { STACKS_TESTNET } from '@stacks/network';
import { generateWallet, getStxAddress } from '@stacks/wallet-sdk';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

const MNEMONIC = process.env.STACKS_DEPLOYER_PRIVATE_KEY?.replace(/"/g, '') || '';

// Generate wallet from mnemonic
const wallet = await generateWallet({
  secretKey: MNEMONIC,
  password: '',
});

const account = wallet.accounts[0];
const deployer = getStxAddress({ account, network: 'testnet' });
const privateKey = account.stxPrivateKey;

const network = STACKS_TESTNET;
const swapContract = `${deployer}.adam-swap`;

const tokens = [
  { symbol: "ADUSD", name: "Adam USD", contract: `${deployer}.adam-token-adusd` },
  { symbol: "ADNGN", name: "Adam NGN", contract: `${deployer}.adam-token-adngn` },
  { symbol: "ADKES", name: "Adam KES", contract: `${deployer}.adam-token-adkes` },
  { symbol: "ADGHS", name: "Adam GHS", contract: `${deployer}.adam-token-adghs` },
  { symbol: "ADZAR", name: "Adam ZAR", contract: `${deployer}.adam-token-adzar` }
];

async function initializeToken(token) {
  console.log(`\nInitializing ${token.symbol} (${token.name})...`);
  
  const [address, contractName] = token.contract.split('.');
  
  try {
    // 1. Initialize
    console.log(`  1. Setting token name and symbol...`);
    const initTx = await makeContractCall({
      contractAddress: address,
      contractName: contractName,
      functionName: 'initialize',
      functionArgs: [
        stringAsciiCV(token.name),
        stringAsciiCV(token.symbol),
        uintCV(18),
        principalCV(deployer)
      ],
      senderKey: privateKey,
      network,
      anchorMode: AnchorMode.Any,
      postConditionMode: PostConditionMode.Allow
    });
    
    const initRes = await broadcastTransaction({ transaction: initTx, network });
    
    if ('error' in initRes) {
      console.error(`  ✗ Initialize failed:`, initRes.error);
      if ('reason' in initRes) {
        console.error(`  Reason:`, initRes.reason);
      }
      return false;
    }
    
    console.log(`  ✓ Initialize tx: ${initRes.txid}`);
    console.log(`    View: https://explorer.hiro.so/txid/${initRes.txid}?chain=testnet`);
    
    // Wait a bit before next transaction
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // 2. Set Minter
    console.log(`  2. Setting swap contract as minter...`);
    const minterTx = await makeContractCall({
      contractAddress: address,
      contractName: contractName,
      functionName: 'set-minter',
      functionArgs: [
        principalCV(swapContract),
        boolCV(true)
      ],
      senderKey: privateKey,
      network,
      anchorMode: AnchorMode.Any,
      postConditionMode: PostConditionMode.Allow
    });
    
    const minterRes = await broadcastTransaction({ transaction: minterTx, network });
    
    if ('error' in minterRes) {
      console.error(`  ✗ Set minter failed:`, minterRes.error);
      return false;
    }
    
    console.log(`  ✓ Set Minter tx: ${minterRes.txid}`);
    
    // Wait a bit before next transaction
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // 3. Set Burner
    console.log(`  3. Setting swap contract as burner...`);
    const burnerTx = await makeContractCall({
      contractAddress: address,
      contractName: contractName,
      functionName: 'set-burner',
      functionArgs: [
        principalCV(swapContract),
        boolCV(true)
      ],
      senderKey: privateKey,
      network,
      anchorMode: AnchorMode.Any,
      postConditionMode: PostConditionMode.Allow
    });
    
    const burnerRes = await broadcastTransaction({ transaction: burnerTx, network });
    
    if ('error' in burnerRes) {
      console.error(`  ✗ Set burner failed:`, burnerRes.error);
      return false;
    }
    
    console.log(`  ✓ Set Burner tx: ${burnerRes.txid}`);
    console.log(`✅ ${token.symbol} initialization complete!\n`);
    return true;
    
  } catch (error) {
    console.error(`✗ Error initializing ${token.symbol}:`, error.message);
    return false;
  }
}

async function run() {
  console.log('========================================');
  console.log('Adam Protocol Token Initialization');
  console.log('========================================');
  console.log(`Deployer: ${deployer}`);
  console.log(`Network: Stacks Testnet`);
  console.log(`Swap Contract: ${swapContract}\n`);
  
  if (!MNEMONIC) {
    console.error('✗ Error: STACKS_DEPLOYER_PRIVATE_KEY not set in .env file');
    process.exit(1);
  }
  
  const results = [];
  
  for (const token of tokens) {
    const success = await initializeToken(token);
    results.push({ token: token.symbol, success });
    
    // Wait between tokens
    if (tokens.indexOf(token) < tokens.length - 1) {
      console.log('Waiting 5 seconds before next token...\n');
      await new Promise(resolve => setTimeout(resolve, 5000));
    }
  }
  
  // Summary
  console.log('\n========================================');
  console.log('Initialization Summary');
  console.log('========================================');
  results.forEach(r => {
    console.log(`${r.token}: ${r.success ? '✅ Success' : '❌ Failed'}`);
  });
  
  const successCount = results.filter(r => r.success).length;
  console.log(`\nTotal: ${successCount}/${results.length} successful`);
}

run();
