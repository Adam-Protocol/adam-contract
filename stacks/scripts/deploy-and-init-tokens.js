import { 
  broadcastTransaction, 
  AnchorMode, 
  makeContractCall,
  makeContractDeploy,
  stringAsciiCV,
  uintCV,
  principalCV,
  boolCV,
  PostConditionMode
} from '@stacks/transactions';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Configuration
const PRIVATE_KEY = process.env.STACKS_DEPLOYER_PRIVATE_KEY || '';
const DEPLOYER_ADDRESS = "STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191";

const network = {
  url: "https://api.testnet.hiro.so",
};

const tokens = [
  { symbol: "ADUSD", name: "Adam USD", contractName: "adam-token-adusd" },
  { symbol: "ADNGN", name: "Adam NGN", contractName: "adam-token-adngn" },
  { symbol: "ADKES", name: "Adam KES", contractName: "adam-token-adkes" },
  { symbol: "ADGHS", name: "Adam GHS", contractName: "adam-token-adghs" },
  { symbol: "ADZAR", name: "Adam ZAR", contractName: "adam-token-adzar" }
];

// Read contract source
const contractPath = path.join(__dirname, '../contracts/adam-token.clar');
const contractSource = fs.readFileSync(contractPath, 'utf8');

// Helper to wait for transaction confirmation
async function waitForTransaction(txid, maxAttempts = 30) {
  console.log(`  Waiting for tx ${txid} to confirm...`);
  
  for (let i = 0; i < maxAttempts; i++) {
    try {
      const response = await fetch(`${network.url}/extended/v1/tx/${txid}`);
      const data = await response.json();
      
      if (data.tx_status === 'success') {
        console.log(`  ✓ Transaction confirmed`);
        return true;
      } else if (data.tx_status === 'abort_by_response' || data.tx_status === 'abort_by_post_condition') {
        console.log(`  ✗ Transaction failed: ${data.tx_status}`);
        return false;
      }
    } catch (e) {
      // Transaction not found yet, continue waiting
    }
    
    await new Promise(resolve => setTimeout(resolve, 10000)); // Wait 10 seconds
  }
  
  console.log(`  ⚠ Transaction not confirmed after ${maxAttempts} attempts`);
  return false;
}

async function deployToken(token) {
  console.log(`\n${'='.repeat(50)}`);
  console.log(`Deploying ${token.symbol} (${token.name})`);
  console.log(`${'='.repeat(50)}`);
  
  try {
    // 1. Deploy contract
    console.log(`\n1. Deploying contract ${token.contractName}...`);
    const deployTx = await makeContractDeploy({
      contractName: token.contractName,
      codeBody: contractSource,
      senderKey: PRIVATE_KEY,
      network,
      anchorMode: AnchorMode.Any,
      postConditionMode: PostConditionMode.Allow,
      fee: 500000 // 0.5 STX
    });
    
    const deployRes = await broadcastTransaction(deployTx, network);
    
    if (deployRes.error) {
      console.error(`  ✗ Deploy failed:`, deployRes);
      return false;
    }
    
    console.log(`  ✓ Deploy tx: ${deployRes.txid}`);
    
    // Wait for deployment to confirm
    const deployConfirmed = await waitForTransaction(deployRes.txid);
    if (!deployConfirmed) {
      console.error(`  ✗ Deploy transaction failed to confirm`);
      return false;
    }
    
    // 2. Initialize token
    console.log(`\n2. Initializing token with name="${token.name}" symbol="${token.symbol}"...`);
    const initTx = await makeContractCall({
      contractAddress: DEPLOYER_ADDRESS,
      contractName: token.contractName,
      functionName: 'initialize',
      functionArgs: [
        stringAsciiCV(token.name),
        stringAsciiCV(token.symbol),
        uintCV(18),
        principalCV(DEPLOYER_ADDRESS)
      ],
      senderKey: PRIVATE_KEY,
      network,
      anchorMode: AnchorMode.Any,
      postConditionMode: PostConditionMode.Allow,
      fee: 100000
    });
    
    const initRes = await broadcastTransaction(initTx, network);
    
    if (initRes.error) {
      console.error(`  ✗ Initialize failed:`, initRes);
      return false;
    }
    
    console.log(`  ✓ Initialize tx: ${initRes.txid}`);
    
    const initConfirmed = await waitForTransaction(initRes.txid);
    if (!initConfirmed) {
      console.error(`  ✗ Initialize transaction failed to confirm`);
      return false;
    }
    
    // 3. Set swap contract as minter
    const swapContract = `${DEPLOYER_ADDRESS}.adam-swap`;
    console.log(`\n3. Setting ${swapContract} as minter...`);
    
    const minterTx = await makeContractCall({
      contractAddress: DEPLOYER_ADDRESS,
      contractName: token.contractName,
      functionName: 'set-minter',
      functionArgs: [
        principalCV(swapContract),
        boolCV(true)
      ],
      senderKey: PRIVATE_KEY,
      network,
      anchorMode: AnchorMode.Any,
      postConditionMode: PostConditionMode.Allow,
      fee: 100000
    });
    
    const minterRes = await broadcastTransaction(minterTx, network);
    
    if (minterRes.error) {
      console.error(`  ✗ Set minter failed:`, minterRes);
      return false;
    }
    
    console.log(`  ✓ Set minter tx: ${minterRes.txid}`);
    await waitForTransaction(minterRes.txid);
    
    // 4. Set swap contract as burner
    console.log(`\n4. Setting ${swapContract} as burner...`);
    
    const burnerTx = await makeContractCall({
      contractAddress: DEPLOYER_ADDRESS,
      contractName: token.contractName,
      functionName: 'set-burner',
      functionArgs: [
        principalCV(swapContract),
        boolCV(true)
      ],
      senderKey: PRIVATE_KEY,
      network,
      anchorMode: AnchorMode.Any,
      postConditionMode: PostConditionMode.Allow,
      fee: 100000
    });
    
    const burnerRes = await broadcastTransaction(burnerTx, network);
    
    if (burnerRes.error) {
      console.error(`  ✗ Set burner failed:`, burnerRes);
      return false;
    }
    
    console.log(`  ✓ Set burner tx: ${burnerRes.txid}`);
    await waitForTransaction(burnerRes.txid);
    
    console.log(`\n✓ ${token.symbol} deployment complete!`);
    return true;
    
  } catch (error) {
    console.error(`\n✗ Error deploying ${token.symbol}:`, error);
    return false;
  }
}

async function main() {
  console.log(`\n${'='.repeat(50)}`);
  console.log(`Adam Protocol Token Deployment`);
  console.log(`${'='.repeat(50)}`);
  console.log(`Network: Testnet`);
  console.log(`Deployer: ${DEPLOYER_ADDRESS}`);
  console.log(`Tokens to deploy: ${tokens.length}`);
  
  if (!PRIVATE_KEY) {
    console.error('\n✗ Error: STACKS_DEPLOYER_PRIVATE_KEY not set in environment');
    process.exit(1);
  }
  
  const results = [];
  
  for (const token of tokens) {
    const success = await deployToken(token);
    results.push({ token: token.symbol, success });
    
    // Wait a bit between deployments
    if (tokens.indexOf(token) < tokens.length - 1) {
      console.log(`\nWaiting 5 seconds before next deployment...`);
      await new Promise(resolve => setTimeout(resolve, 5000));
    }
  }
  
  // Summary
  console.log(`\n${'='.repeat(50)}`);
  console.log(`Deployment Summary`);
  console.log(`${'='.repeat(50)}`);
  
  results.forEach(r => {
    console.log(`${r.token}: ${r.success ? '✓ Success' : '✗ Failed'}`);
  });
  
  const successCount = results.filter(r => r.success).length;
  console.log(`\nTotal: ${successCount}/${results.length} successful`);
}

main().catch(console.error);
