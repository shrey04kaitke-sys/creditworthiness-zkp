/**
 * SETUP SCRIPT FOR CREDITWORTHINESS REGISTRY
 *
 * This script helps set up your local development environment
 * Performs: environment check, dependency verification, local deployment
 *
 * Usage: npm run setup
 */

const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

// ============================================================================
// CONFIGURATION
// ============================================================================

const REQUIRED_FILES = [
    "contracts/CreditworthinessRegistry.sol",
    "test/CreditworthinessRegistry.test.js",
];

const REQUIRED_DEPENDENCIES = [
    "hardhat",
    "@nomicfoundation/hardhat-toolbox",
    "@nomicfoundation/hardhat-ethers",
    "ethers",
    "@openzeppelin/contracts",
    "chai",
    "dotenv",
];

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

function log(message, type = "info") {
    const colors = {
        info: "\x1b[36m",      // Cyan
        success: "\x1b[32m",   // Green
        warning: "\x1b[33m",   // Yellow
        error: "\x1b[31m",     // Red
        reset: "\x1b[0m"       // Reset
    };

    const prefix = {
        info: "ℹ️ ",
        success: "✅",
        warning: "⚠️ ",
        error: "❌"
    };

    const color = colors[type] || colors.info;
    console.log(`${color}${prefix[type]} ${message}${colors.reset}`);
}

function fileExists(filepath) {
    return fs.existsSync(filepath);
}

function directoryExists(dirpath) {
    return fs.existsSync(dirpath) && fs.statSync(dirpath).isDirectory();
}

function createDirectory(dirpath) {
    if (!directoryExists(dirpath)) {
        fs.mkdirSync(dirpath, { recursive: true });
        log(`Created directory: ${dirpath}`, "success");
    }
}

function copyFile(source, destination) {
    if (fileExists(source)) {
        fs.copyFileSync(source, destination);
        log(`Copied: ${source} → ${destination}`, "success");
        return true;
    }
    return false;
}

function installDependencies() {
    log("Installing npm dependencies...", "info");
    try {
        execSync("npm install", { stdio: "inherit" });
        log("Dependencies installed successfully", "success");
        return true;
    } catch (error) {
        log("Failed to install dependencies", "error");
        return false;
    }
}

function createEnvFile() {
    const envPath = path.join(process.cwd(), ".env");

    if (fileExists(envPath)) {
        log(".env file already exists", "info");
        return;
    }

    const envContent = `# RPC URLs (get from Alchemy, Infura, or Quicknode)
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
MUMBAI_RPC_URL=https://polygon-mumbai.g.alchemy.com/v2/YOUR_API_KEY

# Private key for deployment (without 0x prefix)
# WARNING: Never commit this to version control
PRIVATE_KEY=your_private_key_here

# API Keys for contract verification
ETHERSCAN_API_KEY=your_etherscan_key_here
POLYGONSCAN_API_KEY=your_polygonscan_key_here

# Gas reporter settings
REPORT_GAS=false
COINMARKETCAP_API_KEY=your_coinmarketcap_key_here
`;

    fs.writeFileSync(envPath, envContent);
    log("Created .env file (configure with your keys)", "success");
}

function createPackageJsonScripts() {
    const packageJsonPath = path.join(process.cwd(), "package.json");

    if (!fileExists(packageJsonPath)) {
        log("package.json not found", "warning");
        return;
    }

    const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, "utf8"));

    const scripts = {
        "test": "hardhat test",
        "test:gas": "REPORT_GAS=true hardhat test",
        "coverage": "hardhat coverage",
        "compile": "hardhat compile",
        "deploy:local": "hardhat run scripts/deploy.js --network hardhat",
        "deploy:sepolia": "hardhat run scripts/deploy.js --network sepolia",
        "deploy:mumbai": "hardhat run scripts/deploy.js --network mumbai",
        "node": "hardhat node",
        "clean": "hardhat clean",
        "flatten": "hardhat flatten contracts/CreditworthinessRegistry.sol > flattened.sol"
    };

    packageJson.scripts = { ...packageJson.scripts, ...scripts };
    fs.writeFileSync(packageJsonPath, JSON.stringify(packageJson, null, 2));
    log("Updated package.json with npm scripts", "success");
}

// ============================================================================
// MAIN SETUP FLOW
// ============================================================================

async function runSetup() {
    console.log("\n" + "=".repeat(80));
    console.log("🚀 CREDITWORTHINESS REGISTRY - SETUP WIZARD");
    console.log("=".repeat(80) + "\n");

    let setupSuccessful = true;

    // ========================================================================
    // STEP 1: Check project structure
    // ========================================================================
    log("STEP 1: Checking project structure...", "info");
    console.log("-".repeat(80));

    const requiredDirs = ["contracts", "test", "scripts"];
    for (const dir of requiredDirs) {
        if (directoryExists(dir)) {
            log(`${dir}/ exists`, "success");
        } else {
            createDirectory(dir);
        }
    }

    // ========================================================================
    // STEP 2: Check contract files
    // ========================================================================
    log("\nSTEP 2: Checking contract files...", "info");
    console.log("-".repeat(80));

    for (const file of REQUIRED_FILES) {
        if (fileExists(file)) {
            log(`${file} found`, "success");
        } else {
            log(`${file} NOT found - may need to be created`, "warning");
            setupSuccessful = false;
        }
    }

    // ========================================================================
    // STEP 3: Check and install dependencies
    // ========================================================================
    log("\nSTEP 3: Checking dependencies...", "info");
    console.log("-".repeat(80));

    const packageJsonPath = path.join(process.cwd(), "package.json");
    if (!fileExists(packageJsonPath)) {
        log("package.json not found - initializing...", "warning");
        execSync("npm init -y", { stdio: "inherit" });
    }

    const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, "utf8"));
    const allDeps = { ...(packageJson.dependencies || {}), ...(packageJson.devDependencies || {}) };

    const missingDeps = REQUIRED_DEPENDENCIES.filter(dep => !allDeps[dep]);

    if (missingDeps.length === 0) {
        log("All dependencies are installed", "success");
    } else {
        log(`${missingDeps.length} dependencies missing - installing...`, "warning");
        if (!installDependencies()) {
            setupSuccessful = false;
        }
    }

    // ========================================================================
    // STEP 4: Create environment configuration
    // ========================================================================
    log("\nSTEP 4: Setting up environment...", "info");
    console.log("-".repeat(80));

    createEnvFile();
    createDirectory("deployments");

    // ========================================================================
    // STEP 5: Create npm scripts
    // ========================================================================
    log("\nSTEP 5: Creating npm scripts...", "info");
    console.log("-".repeat(80));

    createPackageJsonScripts();

    // ========================================================================
    // SUMMARY
    // ========================================================================
    console.log("\n" + "=".repeat(80));
    if (setupSuccessful) {
        log("SETUP COMPLETE", "success");
    } else {
        log("SETUP COMPLETED WITH WARNINGS", "warning");
    }
    console.log("=".repeat(80) + "\n");

    log("Next steps:", "info");
    console.log("  1. Install dependencies: npm install");
    console.log("  2. Configure .env with your RPC URLs");
    console.log("  3. Compile contracts: npm run compile");
    console.log("  4. Run tests: npm test");
    console.log("  5. Deploy locally: npm run deploy:local");
    console.log("\nAvailable commands:");
    console.log("  npm test              - Run all tests");
    console.log("  npm run test:gas      - Run tests with gas reporting");
    console.log("  npm run coverage      - Generate coverage report");
    console.log("  npm run compile       - Compile contracts");
    console.log("  npm run deploy:local  - Deploy to local Hardhat");
    console.log("  npm run deploy:sepolia- Deploy to Sepolia testnet");
    console.log("  npm run deploy:mumbai - Deploy to Mumbai testnet");
    console.log("  npm run node          - Start local Hardhat node");
    console.log("\n" + "=".repeat(80) + "\n");
}

// Run setup
runSetup().catch((error) => {
    log("Setup failed with error:", "error");
    console.error(error);
    process.exit(1);
});
