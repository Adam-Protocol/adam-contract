import { makeContractCall, broadcastTransaction, AnchorMode } from '@stacks/transactions';
import { StacksTestnet } from '@stacks/network';

const NETWORK = new StacksTestnet();
const DEPLOYER_ADDRESS = 'STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191';
const TREASURY_ADDRESS = process.env.TREASURY_ADDRESS || DEPLOYER_ADDRESS;
const PRIVATE_KEY = process.env.STACKS_DEPLOYER_PRIVATE_KEY || '';

// V2 Contract names
const contracts = {
  adusd: 'adam-token-adusd-v2',
  adngn: 'adam-token-adngn-v2',
  adkes: 'adam-token-adkes-v2',
  adghs: 'adam-token-adghs-v2',
  adzar: 'adam-token-adzar-v2',
  swap: 'adam-swap-v2',
  usdcx: 'usdcx',
};

async function initializeToken(contractName: string, name: string, symbol: string) {
  console.log(`Initializing ${contractName}...`);
  
  const txOptions = {
    contractAddress: DEPLOYER_ADDRESS,
    contractName,
    functionName: 'initialize',
    functionArgs: [
      stringAsciiCV(name),
      stringAsciiCV(symbol),
      uintCV(6),
      principalCV(DEPLOYER_ADDRESS),
    ],
    senderKey: PRIVATE_KEY,
    network: NETWORK,
    anchorMode: AnchorMode.Any,
  };

  const transaction = await makeContractCall(txOptions);
  const result = await broadcastTransaction(transaction, NETWORK);
  console.log(`✓ ${contractName} initialized: ${result.txid}`);
  return result.txid;
}

async function initializeSwap() {
  console.log('Initializing adam-swap-v2...');
  
  const txOptions = {
    contractAddress: DEPLOYER_ADDRESS,
    contractName: contracts.swap,
    functionName: 'initialize',
    functionArgs: [
      principalCV(DEPLOYER_ADDRESS),
      principalCV(TREASURY_ADDRESS),
      contractPrincipalCV(DEPLOYER_ADDRESS, contracts.usdcx),
      contractPrincipalCV(DEPLOYER_ADDRESS, contracts.adusd),
      contractPrincipalCV(DEPLOYER_ADDRESS, contracts.adngn),
      contractPrincipalCV(DEPLOYER_ADDRESS, contracts.adkes),
      contractPrincipalCV(DEPLOYER_ADDRESS, contracts.adghs),
      contractPrincipalCV(DEPLOYER_ADDRESS, contracts.adzar),
      uintCV(50),
    ],
    senderKey: PRIVATE_KEY,
    network: NETWORK,
    anchorMode: AnchorMode.Any,
  };

  const transaction = await makeContractCall(txOptions);
  const result = await broadcastTransaction(transaction, NETWORK);
  console.log(`✓ adam-swap-v2 initialized: ${result.txid}`);
  return result.txid;
}

async function grantRole(tokenContract: string, role: string, grantee: string) {
  const txOptions = {
    contractAddress: DEPLOYER_ADDRESS,
    contractName: tokenContract,
    functionName: `set-${role}`,
    functionArgs: [
      contractPrincipalCV(DEPLOYER_ADDRESS, grantee),
      trueCV(),
    ],
    senderKey: PRIVATE_KEY,
    network: NETWORK,
    anchorMode: AnchorMode.Any,
  };

  const transaction = await makeContractCall(txOptions);
  const result = await broadcastTransaction(transaction, NETWORK);
  return result.txid;
}

async function main() {
  console.log('=========================================');
  console.log('V2 Contract Initialization');
  console.log('=========================================');
  console.log(`Network: Testnet`);
  console.log(`Deployer: ${DEPLOYER_ADDRESS}`);
  console.log(`Treasury: ${TREASURY_ADDRESS}`);
  console.log('');

  try {
    // Step 1: Initialize tokens
    console.log('Step 1: Initializing tokens...');
    await initializeToken(contracts.adusd, 'Adam USD', 'ADUSD');
    await initializeToken(contracts.adngn, 'Adam NGN', 'ADNGN');
    await initializeToken(contracts.adkes, 'Adam KES', 'ADKES');
    await initializeToken(contracts.adghs, 'Adam GHS', 'ADGHS');
    await initializeToken(contracts.adzar, 'Adam ZAR', 'ADZAR');
    console.log('✓ All tokens initialized\n');

    // Step 2: Initialize swap
    console.log('Step 2: Initializing swap contract...');
    await initializeSwap();
    console.log('✓ Swap initialized\n');

    // Step 3: Grant minter roles
    console.log('Step 3: Granting minter roles...');
    for (const token of Object.values(contracts).filter(c => c.startsWith('adam-token'))) {
      await grantRole(token, 'minter', contracts.swap);
    }
    console.log('✓ Minter roles granted\n');

    // Step 4: Grant burner roles
    console.log('Step 4: Granting burner roles...');
    for (const token of Object.values(contracts).filter(c => c.startsWith('adam-token'))) {
      await grantRole(token, 'burner', contracts.swap);
    }
    console.log('✓ Burner roles granted\n');

    console.log('=========================================');
    console.log('Initialization Complete!');
    console.log('=========================================');
    console.log('\nNext: Set exchange rates using set-rate function');
    
  } catch (error) {
    console.error('Error during initialization:', error);
    process.exit(1);
  }
}

main();
