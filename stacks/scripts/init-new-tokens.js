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


// Mnemonic and Network
const mnemonic = process.env.STACKS_DEPLOYER_PRIVATE_KEY || '';
const network = {
  url: "https://api.testnet.hiro.so",
};

// Contract info
const deployer = "STY1XRRA93GJP9YMS2CTHB6M08M11BKPDVRM0191";
const swapContract = `${deployer}.adam-swap`;

const tokens = [
  { symbol: "ADKES", name: "Adam KES", contract: `${deployer}.adam-token-adkes` },
  { symbol: "ADGHS", name: "Adam GHS", contract: `${deployer}.adam-token-adghs` },
  { symbol: "ADZAR", name: "Adam ZAR", contract: `${deployer}.adam-token-adzar` }
];

async function initializeToken(token) {
  console.log(`Initializing ${token.symbol}...`);
  
  const [address, contractName] = token.contract.split('.');
  
  // 1. Initialize
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
    senderKey: mnemonic, // makeContractCall accepts mnemonic
    network,
    anchorMode: AnchorMode.Any,
    postConditionMode: PostConditionMode.Allow
  });
  
  const initRes = await broadcastTransaction(initTx, network);
  console.log(`  Initialize tx: ${initRes.txid}`);
  
  // 2. Set Minter
  const minterTx = await makeContractCall({
    contractAddress: address,
    contractName: contractName,
    functionName: 'set-minter',
    functionArgs: [
      principalCV(swapContract),
      boolCV(true)
    ],
    senderKey: mnemonic,
    network,
    anchorMode: AnchorMode.Any,
    postConditionMode: PostConditionMode.Allow
  });
  
  const minterRes = await broadcastTransaction(minterTx, network);
  console.log(`  Set Minter tx: ${minterRes.txid}`);
  
  // 3. Set Burner
  const burnerTx = await makeContractCall({
    contractAddress: address,
    contractName: contractName,
    functionName: 'set-burner',
    functionArgs: [
      principalCV(swapContract),
      boolCV(true)
    ],
    senderKey: mnemonic,
    network,
    anchorMode: AnchorMode.Any,
    postConditionMode: PostConditionMode.Allow
  });
  
  const burnerRes = await broadcastTransaction(burnerTx, network);
  console.log(`  Set Burner tx: ${burnerRes.txid}`);
}

async function run() {
  for (const token of tokens) {
    try {
      await initializeToken(token);
    } catch (e) {
      console.error(`Failed to initialize ${token.symbol}:`, e);
    }
  }
}

run();
