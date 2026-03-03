import * as childProcess from 'child_process';
import * as path from 'path';
import * as dotenv from 'dotenv';
import * as fs from 'fs';

// Load environment variables
dotenv.config();

// Configuration from environment variables
const RPC_URL = process.env.STARKNET_RPC_URL || "https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_10/5QQMV6kqa3iDaH_EbNhTw";
const DEPLOYER_ACCOUNT = process.env.DEPLOYER_ACCOUNT || "adam-deployer";
const NETWORK = process.env.STARKNET_NETWORK || "sepolia";
const VERIFIER = process.env.VERIFIER || "walnut";
const DEPLOYMENT_LOG_DIR = process.env.DEPLOYMENT_LOG_DIR || "deployment_logs";
const DEFAULT_FEE_BPS = parseInt(process.env.DEFAULT_FEE_BPS || "30");
const MAX_FEE_BPS = parseInt(process.env.MAX_FEE_BPS || "1000");
const ADUSD_NAME = process.env.ADUSD_NAME || "Adam USD";
const ADUSD_SYMBOL = process.env.ADUSD_SYMBOL || "ADUSD";
const ADNGN_NAME = process.env.ADNGN_NAME || "Adam NGN";
const ADNGN_SYMBOL = process.env.ADNGN_SYMBOL || "ADNGN";
const ADAM_TOKEN_NAME = process.env.ADAM_TOKEN_NAME || "adam_token";
const ADAM_POOL_NAME = process.env.ADAM_POOL_NAME || "adam_pool";
const ADAM_SWAP_NAME = process.env.ADAM_SWAP_NAME || "adam_swap";

const DEPLOYMENT_LOG = path.join(
    DEPLOYMENT_LOG_DIR,
    `deploy_${new Date().toISOString().replace(/[:.]/g, "-")}.log`
);

// Contract configurations
const CONTRACTS = {
    adam_token: {
        name: ADAM_TOKEN_NAME,
        path: "packages/adam-token",
    },
    adam_pool: {
        name: ADAM_POOL_NAME,
        path: "packages/adam-pool",
    },
    adam_swap: {
        name: ADAM_SWAP_NAME,
        path: "packages/adam-swap",
    }
};

// Colors for console output
const colors = {
    green: "\x1b[32m",
    yellow: "\x1b[33m",
    red: "\x1b[31m",
    blue: "\x1b[34m",
    reset: "\x1b[0m",
};

// Types
interface DeploymentLog {
    contract: string;
    classHash?: string;
    address?: string;
    txHash?: string;
    timestamp: string;
    network: string;
    status: 'success' | 'failed';
    error?: string;
}

interface DeployedContracts {
    adusd?: string;
    adngn?: string;
    usdc?: string;
    pool?: string;
    swap?: string;
}

class AdamDeployer {
    private deploymentLog: DeploymentLog[] = [];
    private account: string;
    public network: string;
    private verifier: string;
    private rpcUrl: string;
    private contractStates: Record<string, {
        classHash?: string;
        address?: string;
    }> = {};
    private deployedContracts: DeployedContracts = {};

    constructor(options: {
        account?: string;
        network?: string;
        verifier?: string;
        rpcUrl?: string;
    } = {}) {
        this.account = options.account || DEPLOYER_ACCOUNT;
        this.network = options.network || NETWORK;
        this.verifier = options.verifier || VERIFIER;
        this.rpcUrl = options.rpcUrl || RPC_URL;

        // Create deployment logs directory if it doesn't exist
        if (!fs.existsSync(DEPLOYMENT_LOG_DIR)) {
            fs.mkdirSync(DEPLOYMENT_LOG_DIR, { recursive: true });
        }
    }

    private log(
        message: string,
        type: "info" | "success" | "error" | "warning" = "info"
    ): void {
        const timestamp = new Date().toISOString();
        let prefix = "";

        switch (type) {
            case "success":
                prefix = `${colors.green}✓${colors.reset} `;
                break;
            case "error":
                prefix = `${colors.red}✗${colors.reset} `;
                break;
            case "warning":
                prefix = `${colors.yellow}!${colors.reset} `;
                break;
            default:
                prefix = `${colors.blue}→${colors.reset} `;
        }

        const logMessage = `[${timestamp}] ${prefix}${message}`;
        console.log(logMessage);

        // Append to log file
        fs.appendFileSync(DEPLOYMENT_LOG, logMessage + "\n");
    }

    private async executeCommand(command: string, cwd?: string): Promise<{ stdout: string, stderr: string }> {
        return new Promise((resolve, reject) => {
            this.log(`Executing: ${command}`, 'info');

            const child = childProcess.exec(command, { cwd }, (error, stdout, stderr) => {
                if (error) {
                    this.log(`Command failed: ${error.message}`, 'error');
                    this.log(`Stderr: ${stderr}`, 'error');
                    reject({ error, stdout, stderr });
                } else {
                    resolve({ stdout, stderr });
                }
            });

            // Stream output in real-time
            child.stdout?.on('data', (data) => {
                process.stdout.write(data);
            });

            child.stderr?.on('data', (data) => {
                process.stderr.write(data);
            });
        });
    }

    private extractClassHash(output: string): string | null {
        const match = output.match(/class_hash:\s*(0x[0-9a-fA-F]+)/i) || 
                     output.match(/Class Hash:\s*(0x[0-9a-fA-F]+)/i);
        return match ? match[1] : null;
    }

    private extractContractAddress(output: string): string | null {
        const match = output.match(/contract_address:\s*(0x[0-9a-fA-F]+)/i) ||
                     output.match(/Contract Address:\s*(0x[0-9a-fA-F]+)/i);
        return match ? match[1] : null;
    }

    private extractTxHash(output: string): string | null {
        const match = output.match(/transaction_hash:\s*(0x[0-9a-fA-F]+)/i) ||
                     output.match(/Transaction Hash:\s*(0x[0-9a-fA-F]+)/i);
        return match ? match[1] : null;
    }

    public async buildContracts(): Promise<void> {
        this.log("Building all contracts...");
        try {
            await this.executeCommand("scarb build");
            this.log("✓ All contracts built successfully", 'success');
        } catch (error: any) {
            this.log("✗ Failed to build contracts", 'error');
            throw error;
        }
    }

    public async declareContract(contractName: string): Promise<string> {
        const contractConfig = CONTRACTS[contractName as keyof typeof CONTRACTS];
        if (!contractConfig) {
            throw new Error(`No configuration found for contract: ${contractName}`);
        }

        const logEntry: DeploymentLog = {
            contract: contractName,
            timestamp: new Date().toISOString(),
            network: this.network,
            status: 'failed'
        };

        try {
            this.log(`Declaring ${contractName} contract...`);

            const { stdout } = await this.executeCommand(
                `sncast --account ${this.account} --url ${this.rpcUrl} ` +
                `declare --contract-name ${contractConfig.name}`,
                contractConfig.path
            );

            const classHash = this.extractClassHash(stdout);
            const txHash = this.extractTxHash(stdout);

            if (!classHash) {
                throw new Error('Failed to extract class hash from output');
            }

            this.log(`✓ Successfully declared ${contractName} with class hash: ${classHash}`, 'success');
            if (txHash) {
                this.log(`   Transaction hash: ${txHash}`);
            }

            // Update state
            this.contractStates[contractName] = {
                ...this.contractStates[contractName],
                classHash
            };

            // Update log entry
            logEntry.status = 'success';
            logEntry.classHash = classHash;
            if (txHash) logEntry.txHash = txHash;

            return classHash;
        } catch (error: any) {
            const errorMsg = error.stderr || error.message || 'Unknown error';
            this.log(`✗ Failed to declare ${contractName}: ${errorMsg}`, 'error');
            logEntry.error = errorMsg;
            throw error;
        } finally {
            this.deploymentLog.push(logEntry);
        }
    }

    public async deployContract(
        contractName: string,
        constructorArgs: string[] = []
    ): Promise<string> {
        const contractConfig = CONTRACTS[contractName as keyof typeof CONTRACTS];
        if (!contractConfig) {
            throw new Error(`No configuration found for contract: ${contractName}`);
        }

        const logEntry: DeploymentLog = {
            contract: contractName,
            timestamp: new Date().toISOString(),
            network: this.network,
            status: 'failed'
        };

        try {
            // Ensure the contract is declared first
            const classHash = this.contractStates[contractName]?.classHash ||
                await this.declareContract(contractName);

            this.log(`Deploying ${contractName} contract...`);

            // Format constructor arguments for the command line
            const argsString = constructorArgs.length > 0 
                ? `--constructor-calldata ${constructorArgs.join(' ')}`
                : '';

            const { stdout } = await this.executeCommand(
                `sncast --account ${this.account} --url ${this.rpcUrl} ` +
                `deploy --class-hash ${classHash} ${argsString}`,
                contractConfig.path
            );

            const contractAddress = this.extractContractAddress(stdout);
            const txHash = this.extractTxHash(stdout);

            if (!contractAddress) {
                throw new Error('Failed to extract contract address from output');
            }

            this.log(`✓ Successfully deployed ${contractName} at address: ${contractAddress}`, 'success');
            if (txHash) {
                this.log(`   Transaction hash: ${txHash}`);
            }

            // Update state
            this.contractStates[contractName] = {
                ...this.contractStates[contractName],
                address: contractAddress
            };

            // Update log entry
            logEntry.status = 'success';
            logEntry.address = contractAddress;
            if (txHash) logEntry.txHash = txHash;
            if (classHash) logEntry.classHash = classHash;

            return contractAddress;
        } catch (error: any) {
            const errorMsg = error.stderr || error.message || 'Unknown error';
            this.log(`✗ Failed to deploy ${contractName}: ${errorMsg}`, 'error');
            logEntry.error = errorMsg;
            throw error;
        } finally {
            this.deploymentLog.push(logEntry);
        }
    }

    public async deployAdamToken(
        name: string,
        symbol: string,
        owner: string
    ): Promise<string> {
        this.log(`Deploying Adam Token: ${name} (${symbol})...`);
        this.log(`  Owner: ${owner}`);

        const constructorArgs = [
            owner
        ];

        const address = await this.deployContract('adam_token', constructorArgs);
        return address;
    }

    public async deployAdamPool(owner: string): Promise<string> {
        this.log(`Deploying Adam Pool...`);
        this.log(`  Owner: ${owner}`);

        const constructorArgs = [owner];
        const address = await this.deployContract('adam_pool', constructorArgs);
        return address;
    }

    public async deployAdamSwap(params: {
        owner: string;
        treasury: string;
        usdc: string;
        adusd: string;
        adngn: string;
        pool: string;
        feeBps: number;
    }): Promise<string> {
        this.log(`Deploying Adam Swap...`);
        this.log(`  Owner: ${params.owner}`);
        this.log(`  Treasury: ${params.treasury}`);
        this.log(`  USDC: ${params.usdc}`);
        this.log(`  ADUSD: ${params.adusd}`);
        this.log(`  ADNGN: ${params.adngn}`);
        this.log(`  Pool: ${params.pool}`);
        this.log(`  Fee (bps): ${params.feeBps}`);

        const constructorArgs = [
            params.owner,
            params.treasury,
            params.usdc,
            params.adusd,
            params.adngn,
            params.pool,
            params.feeBps.toString()
        ];

        const address = await this.deployContract('adam_swap', constructorArgs);
        return address;
    }

    public async deployFullSystem(params: {
        owner: string;
        treasury: string;
        usdc: string;
        feeBps?: number;
    }): Promise<DeployedContracts> {
        this.log("\n========================================");
        this.log("Starting Adam Protocol Deployment");
        this.log("========================================\n");

        const feeBps = params.feeBps || DEFAULT_FEE_BPS; // Default from env

        try {
            // Step 1: Build contracts
            await this.buildContracts();

            // Step 2: Deploy ADUSD token
            this.log("\n--- Step 1: Deploying ADUSD Token ---");
            const adusd = await this.deployAdamToken(ADUSD_NAME, ADUSD_SYMBOL, params.owner);
            this.deployedContracts.adusd = adusd;

            // Step 3: Deploy ADNGN token
            this.log("\n--- Step 2: Deploying ADNGN Token ---");
            const adngn = await this.deployAdamToken(ADNGN_NAME, ADNGN_SYMBOL, params.owner);
            this.deployedContracts.adngn = adngn;

            // Step 4: Deploy Pool
            this.log("\n--- Step 3: Deploying Adam Pool ---");
            const pool = await this.deployAdamPool(params.owner);
            this.deployedContracts.pool = pool;

            // Step 5: Deploy Swap
            this.log("\n--- Step 4: Deploying Adam Swap ---");
            const swap = await this.deployAdamSwap({
                owner: params.owner,
                treasury: params.treasury,
                usdc: params.usdc,
                adusd,
                adngn,
                pool,
                feeBps
            });
            this.deployedContracts.swap = swap;
            this.deployedContracts.usdc = params.usdc;

            this.log("\n========================================");
            this.log("Deployment Complete!");
            this.log("========================================\n");

            return this.deployedContracts;
        } catch (error) {
            this.log("\n✗ Deployment failed", 'error');
            throw error;
        }
    }

    public async setupRoles(): Promise<void> {
        this.log("\n--- Setting up roles and permissions ---");

        if (!this.deployedContracts.swap || !this.deployedContracts.pool) {
            throw new Error("Contracts must be deployed before setting up roles");
        }

        try {
            // Grant MINTER_ROLE and BURNER_ROLE to swap contract on both tokens
            this.log("Granting MINTER_ROLE to swap contract on ADUSD...");
            await this.executeCommand(
                `sncast --account ${this.account} --url ${this.rpcUrl} ` +
                `invoke --contract-address ${this.deployedContracts.adusd} ` +
                `--function grant_role --calldata ${this.deployedContracts.swap}`,
                CONTRACTS.adam_token.path
            );

            this.log("Granting BURNER_ROLE to swap contract on ADUSD...");
            await this.executeCommand(
                `sncast --account ${this.account} --url ${this.rpcUrl} ` +
                `invoke --contract-address ${this.deployedContracts.adusd} ` +
                `--function grant_role --calldata ${this.deployedContracts.swap}`,
                CONTRACTS.adam_token.path
            );

            this.log("Granting MINTER_ROLE to swap contract on ADNGN...");
            await this.executeCommand(
                `sncast --account ${this.account} --url ${this.rpcUrl} ` +
                `invoke --contract-address ${this.deployedContracts.adngn} ` +
                `--function grant_role --calldata ${this.deployedContracts.swap}`,
                CONTRACTS.adam_token.path
            );

            this.log("Granting BURNER_ROLE to swap contract on ADNGN...");
            await this.executeCommand(
                `sncast --account ${this.account} --url ${this.rpcUrl} ` +
                `invoke --contract-address ${this.deployedContracts.adngn} ` +
                `--function grant_role --calldata ${this.deployedContracts.swap}`,
                CONTRACTS.adam_token.path
            );

            // Set swap contract address in pool
            this.log("Setting swap contract address in pool...");
            await this.executeCommand(
                `sncast --account ${this.account} --url ${this.rpcUrl} ` +
                `invoke --contract-address ${this.deployedContracts.pool} ` +
                `--function set_swap_contract --calldata ${this.deployedContracts.swap}`,
                CONTRACTS.adam_pool.path
            );

            this.log("✓ Roles and permissions configured successfully", 'success');
        } catch (error: any) {
            this.log("✗ Failed to setup roles", 'error');
            this.log("You may need to configure roles manually", 'warning');
            throw error;
        }
    }

    public getDeploymentLogs(): DeploymentLog[] {
        return [...this.deploymentLog];
    }

    public saveDeploymentSummary(): void {
        const summaryPath = path.join(DEPLOYMENT_LOG_DIR, `deployment_summary_${this.network}.json`);
        const summary = {
            network: this.network,
            timestamp: new Date().toISOString(),
            contracts: this.deployedContracts,
            classHashes: Object.entries(this.contractStates).reduce((acc, [name, state]) => {
                acc[name] = state.classHash;
                return acc;
            }, {} as Record<string, string | undefined>),
            logs: this.deploymentLog
        };

        fs.writeFileSync(summaryPath, JSON.stringify(summary, null, 2));
        this.log(`\n✓ Deployment summary saved to: ${summaryPath}`, 'success');

        // Print summary
        console.log("\n========================================");
        console.log("Deployment Summary");
        console.log("========================================");
        console.log(`Network: ${this.network}`);
        console.log(`\nDeployed Contracts:`);
        console.log(`  ADUSD Token: ${this.deployedContracts.adusd || 'N/A'}`);
        console.log(`  ADNGN Token: ${this.deployedContracts.adngn || 'N/A'}`);
        console.log(`  Adam Pool:   ${this.deployedContracts.pool || 'N/A'}`);
        console.log(`  Adam Swap:   ${this.deployedContracts.swap || 'N/A'}`);
        console.log(`  USDC:        ${this.deployedContracts.usdc || 'N/A'}`);
        console.log("========================================\n");
    }
}

// Helper function to parse command line arguments
function parseArgs(args: string[]): Record<string, string> {
    const result: Record<string, string> = {};

    for (let i = 0; i < args.length; i++) {
        const arg = args[i];
        if (arg.startsWith('--')) {
            const key = arg.slice(2);
            const value = args[i + 1] && !args[i + 1].startsWith('--') ? args[++i] : 'true';
            result[key] = value;
        }
    }

    return result;
}

// Main function
async function main() {
    const args = parseArgs(process.argv.slice(2));

    const deployer = new AdamDeployer({
        account: args.account,
        network: args.network,
        verifier: args.verifier,
        rpcUrl: args.rpcUrl
    });

    try {
        const owner = args.owner || process.env.DEPLOYER_ADDRESS;
        const treasury = args.treasury || process.env.TREASURY_ADDRESS || owner;
        const usdc = args.usdc;

        if (!owner) {
            throw new Error("Owner address is required. Provide --owner or set DEPLOYER_ADDRESS in .env");
        }

        if (!usdc) {
            throw new Error("USDC address is required. Provide --usdc");
        }

        if (!treasury) throw new Error("treasure address is required")

        const feeBps = args.fee ? parseInt(args.fee) : DEFAULT_FEE_BPS;

        // Deploy full system
        await deployer.deployFullSystem({
            owner,
            treasury,
            usdc,
            feeBps
        });

        // Setup roles if requested
        if (args.setupRoles === 'true') {
            await deployer.setupRoles();
        }

        // Save deployment summary
        deployer.saveDeploymentSummary();

        console.log("\n✓ Deployment completed successfully!");
        
        if (args.setupRoles !== 'true') {
            console.log("\nNote: Run with --setupRoles true to automatically configure roles and permissions");
        }

    } catch (error) {
        console.error('\n✗ Deployment failed:', error);
        deployer.saveDeploymentSummary();
        process.exit(1);
    }
}

// Run the main function if this file is executed directly
if (require.main === module) {
    main().catch(console.error);
}

export { AdamDeployer };
