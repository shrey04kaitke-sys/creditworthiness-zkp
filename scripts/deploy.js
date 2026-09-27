// SPDX-License-Identifier: MIT
/**
 * HARDHAT DEPLOYMENT SCRIPT
 * Deploy CreditworthinessRegistry to local or testnet
 *
 * Usage:
 * - Local: npx hardhat run scripts/deploy.js --network hardhat
 * - Sepolia: npx hardhat run scripts/deploy.js --network sepolia
 * - Mumbai: npx hardhat run scripts/deploy.js --network mumbai
 */

const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

// ============================================================================
// CONFIGURATION
// ============================================================================

const SAMPLE_ISSUER_1 = "0x8ba1B1E8a6e8e7e6e5e4e3e2e1e0e9e8e7e6e5e4"; // Bank A
const SAMPLE_ISSUER_2 = "0x7a9a7a9a7a9a7a9a7a9a7a9a7a9a7a9a7a9a7a9a"; // Bank B
const SAMPLE_ISSUER_3 = "0x6b8b6b8b6b8b6b8b6b8b6b8b6b8b6b8b6b8b6b8b"; // Bank C

// Sample Groth16 verification key (from snarkjs output)
// In production, use actual verification keys from proof generation
const SAMPLE_VERIFICATION_KEY = {
    alpha: [
        "21888242871839275222246405745257275088548364400416034343698204186575808495616",
        "3673344465139335772865959912180535563671022904866408974027454384266117022979"
    ],
    beta: [
        [
            "10857046999023057135944570762232829481370756359578518086990519993285655852570",
            "11559732032986387107991004021392285783925812861821192530917403151452391805634"
        ],
        [
            "8495653923123431417604973247212409418986837870713852891406060203384169809256",
            "18121144861737263970493992824147073845938910054059641537130902141410775457397"
        ]
    ],
    gamma: [
        "11559732032986387107991004021392285783925812861821192530917403151452391805634",
        "10857046999023057135944570762232829481370756359578518086990519993285655852570"
    ],
    delta: [
        "4407920591278117050309066537889733038336625013538282733616585643477996763403",
        "14968301385447323228564159314447176836705949934097826656640426163803259156022"
    ],
    gammaABC: [
        [
            "14571786986817903654099353882826103149891131175635277825988267900141821844038",
            "1245697862341191267405313352051215879169525131521374066730988649768631850028"
        ],
        [
            "3673344465139335772865959912180535563671022904866408974027454384266117022979",
            "21888242871839275222246405745257275088548364400416034343698204186575808495616"
        ]
    ]
};

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * Sleep for milliseconds
 */
async function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Write deployment info to JSON file
 */
function saveDeploymentInfo(network, contractAddress, sbtAddress, deployer) {
    const deploymentsDir = path.join(__dirname, "..", "deployments");
    if (!fs.existsSync(deploymentsDir)) {
        fs.mkdirSync(deploymentsDir);
    }

    const deployment = {
        network,
        timestamp: new Date().toISOString(),
        deployer,
        contracts: {
            CreditworthinessRegistry: contractAddress,
            CredentialSBT: sbtAddress
        },
        initialConfiguration: {
            authorizedIssuers: [SAMPLE_ISSUER_1, SAMPLE_ISSUER_2, SAMPLE_ISSUER_3],
            verificationKeyIssuers: [SAMPLE_ISSUER_1]
        }
    };

    const filename = path.join(deploymentsDir, `${network}-${Date.now()}.json`);
    fs.writeFileSync(filename, JSON.stringify(deployment, null, 2));
    console.log(`✓ Deployment info saved to ${filename}`);
    return filename;
}

/**
 * Format address for display
 */
function formatAddress(address) {
    return address.substring(0, 6) + "..." + address.substring(address.length - 4);
}

// ============================================================================
// MAIN DEPLOYMENT FUNCTION
// ============================================================================

async function main() {
    console.log("\n" + "=".repeat(80));
    console.log("🚀 CREDITWORTHINESS REGISTRY DEPLOYMENT");
    console.log("=".repeat(80));

    // Get deployer account
    const [deployer] = await hre.ethers.getSigners();
    console.log(`\n📝 Deployer Address: ${deployer.address}`);

    // Get network info
    const network = hre.network.name;
    console.log(`🌐 Network: ${network}`);

    // Get balance
    const balance = await deployer.provider.getBalance(deployer.address);
    console.log(`💰 Balance: ${hre.ethers.formatEther(balance)} ETH\n`);

    // ========================================================================
    // STEP 1: Deploy CredentialSBT Contract
    // ========================================================================
    console.log("📋 STEP 1: Deploying CredentialSBT Contract...");
    console.log("-".repeat(80));

    const CredentialSBT = await hre.ethers.getContractFactory("CredentialSBT");
    const sbt = await CredentialSBT.deploy();
    await sbt.waitForDeployment();

    const sbtAddress = await sbt.getAddress();
    console.log(`✓ CredentialSBT deployed at: ${sbtAddress}`);
    console.log(`  Short address: ${formatAddress(sbtAddress)}`);

    // ========================================================================
    // STEP 2: Deploy CreditworthinessRegistry Contract
    // ========================================================================
    console.log("\n📋 STEP 2: Deploying CreditworthinessRegistry Contract...");
    console.log("-".repeat(80));

    const CreditworthinessRegistry = await hre.ethers.getContractFactory(
        "CreditworthinessRegistry"
    );
    const registry = await CreditworthinessRegistry.deploy(sbtAddress);
    await registry.waitForDeployment();

    const registryAddress = await registry.getAddress();
    console.log(`✓ CreditworthinessRegistry deployed at: ${registryAddress}`);
    console.log(`  Short address: ${formatAddress(registryAddress)}`);

    // ========================================================================
    // STEP 3: Initialize SBT Registry
    // ========================================================================
    console.log("\n📋 STEP 3: Initializing SBT with Registry Address...");
    console.log("-".repeat(80));

    const initTx = await sbt.setRegistry(registryAddress);
    await initTx.wait();
    console.log(`✓ SBT registry initialized`);
    console.log(`  Transaction: ${initTx.hash}`);

    // ========================================================================
    // STEP 4: Authorize Issuers
    // ========================================================================
    console.log("\n📋 STEP 4: Authorizing Sample Issuers...");
    console.log("-".repeat(80));

    const issuers = [
        { address: SAMPLE_ISSUER_1, name: "Bank A" },
        { address: SAMPLE_ISSUER_2, name: "Bank B" },
        { address: SAMPLE_ISSUER_3, name: "Bank C" }
    ];

    for (const issuer of issuers) {
        try {
            const authTx = await registry.authorizeIssuer(issuer.address);
            await authTx.wait();
            console.log(`✓ ${issuer.name}: ${formatAddress(issuer.address)}`);
        } catch (error) {
            console.log(`✗ Failed to authorize ${issuer.name}: ${error.message}`);
        }
    }

    // ========================================================================
    // STEP 5: Register Verification Keys
    // ========================================================================
    console.log("\n📋 STEP 5: Registering Groth16 Verification Keys...");
    console.log("-".repeat(80));

    const keyTx = await registry.registerVerificationKey(
        SAMPLE_ISSUER_1,
        SAMPLE_VERIFICATION_KEY.alpha,
        SAMPLE_VERIFICATION_KEY.beta,
        SAMPLE_VERIFICATION_KEY.gamma,
        SAMPLE_VERIFICATION_KEY.delta,
        SAMPLE_VERIFICATION_KEY.gammaABC
    );
    await keyTx.wait();
    console.log(`✓ Verification key registered for ${formatAddress(SAMPLE_ISSUER_1)}`);
    console.log(`  Transaction: ${keyTx.hash}`);

    // ========================================================================
    // STEP 6: Deploy Summary
    // ========================================================================
    console.log("\n" + "=".repeat(80));
    console.log("✅ DEPLOYMENT COMPLETE");
    console.log("=".repeat(80));

    console.log("\n📍 CONTRACT ADDRESSES:");
    console.log(`  CreditworthinessRegistry: ${registryAddress}`);
    console.log(`  CredentialSBT: ${sbtAddress}`);

    console.log("\n🔧 DEPLOYED ON:");
    console.log(`  Network: ${network}`);
    console.log(`  Deployer: ${deployer.address}`);

    console.log("\n📊 INITIALIZATION:");
    console.log(`  ✓ ${issuers.length} issuers authorized`);
    console.log(`  ✓ 1 verification key registered`);
    console.log(`  ✓ SBT linked to registry`);

    console.log("\n🧪 NEXT STEPS:");
    console.log("  1. Run tests: npx hardhat test");
    console.log("  2. Test locally: npx hardhat node");
    console.log("  3. Set env vars for verification contract");
    console.log("  4. Deploy frontend with contract addresses");

    // Save deployment info
    console.log("\n💾 Saving deployment info...");
    const deploymentFile = saveDeploymentInfo(network, registryAddress, sbtAddress, deployer.address);

    console.log("\n" + "=".repeat(80) + "\n");

    return {
        registry: registryAddress,
        sbt: sbtAddress,
        deployer: deployer.address,
        network,
        deploymentFile
    };
}

// ============================================================================
// ERROR HANDLING
// ============================================================================

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\n❌ DEPLOYMENT FAILED:");
        console.error(error);
        process.exit(1);
    });
