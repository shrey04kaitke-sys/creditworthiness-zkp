/**
 * INTERACTIVE TEST & DEMO SCRIPT
 *
 * Helps you understand how the system works by running scenarios
 * Shows: credential issuance, verification, revocation, SBT operations
 *
 * Usage: npx hardhat run scripts/interactive-test.js
 */

const hre = require("hardhat");
const readline = require("readline");

// ============================================================================
// SETUP
// ============================================================================

const SAMPLE_ISSUER = "0x8ba1B1E8a6e8e7e6e5e4e3e2e1e0e9e8e7e6e5e4";
const SAMPLE_BORROWER = "0x742d35Cc6634C0532925a3b844Bc9e7595f742d2";
const SAMPLE_LENDER = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";

// Sample data
const sampleProof = {
    a: [
        "8429461352197071514779211170631205894203405410876652063906275049100525968627",
        "17451651891851071107813169695318819865230183702631234832635606637787696832635"
    ],
    b: [
        [
            "16177387652872491019456203893301373696898976509524885159319389352024903826408",
            "8340175525370181223062637433098638823883221661893849088175262843949891898707"
        ],
        [
            "3837706090913882281705843873688937813297297262370589838891879996631253857383",
            "20203879925393020844097202289706024033286196832827068506129098303485485372436"
        ]
    ],
    c: [
        "15556343236003892945629155852286868935996436050970661821883549251019203481597",
        "12898854393881419207088532129933062931491181387046733816609820936152944876289"
    ]
};

const samplePublicSignals = [
    "50000",  // Income: $50,000
    "95",     // Payment ratio: 95%
    "700"     // Credit score: 700
];

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

function delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

function log(message, type = "info") {
    const colors = {
        info: "\x1b[36m",
        success: "\x1b[32m",
        warning: "\x1b[33m",
        error: "\x1b[31m",
        header: "\x1b[35m",
        reset: "\x1b[0m"
    };

    const prefix = {
        info: "ℹ️ ",
        success: "✅",
        warning: "⚠️ ",
        error: "❌",
        header: "📋"
    };

    const color = colors[type] || colors.info;
    console.log(`${color}${prefix[type]} ${message}${colors.reset}`);
}

function formatAddress(addr) {
    return addr.substring(0, 6) + "..." + addr.substring(addr.length - 4);
}

// ============================================================================
// DEMO SCENARIOS
// ============================================================================

async function demoIssueCredential(registry) {
    console.log("\n" + "=".repeat(80));
    log("SCENARIO 1: CREDENTIAL ISSUANCE", "header");
    console.log("=".repeat(80));

    log("Issuing credential to borrower...", "info");
    console.log(`  Borrower: ${formatAddress(SAMPLE_BORROWER)}`);
    console.log(`  Issuer: ${formatAddress(SAMPLE_ISSUER)}`);
    console.log(`  Public Signals (Income, Payment Ratio, Credit Score):`);
    console.log(`    • ${samplePublicSignals[0]} (Monthly income)`);
    console.log(`    • ${samplePublicSignals[1]}% (Payment history)`);
    console.log(`    • ${samplePublicSignals[2]} (Credit score)`);

    // Calculate expiration (1 year from now)
    const now = Math.floor(Date.now() / 1000);
    const expiresAt = now + (365 * 24 * 60 * 60);

    try {
        const tx = await registry.issueCredential(
            SAMPLE_BORROWER,
            sampleProof,
            samplePublicSignals,
            "income_verification",
            365 * 24 * 60 * 60  // 1 year validity
        );

        await tx.wait();
        log("Credential issued successfully!", "success");
        console.log(`  Transaction: ${tx.hash}`);

        // Get credential ID (from event)
        const receipt = await hre.ethers.provider.getTransactionReceipt(tx.hash);
        if (receipt && receipt.logs.length > 0) {
            log("Event emitted on blockchain", "success");
        }

        return true;
    } catch (error) {
        log(`Failed to issue credential: ${error.message}`, "error");
        return false;
    }
}

async function demoVerifyCredential(registry) {
    console.log("\n" + "=".repeat(80));
    log("SCENARIO 2: CREDENTIAL VERIFICATION", "header");
    console.log("=".repeat(80));

    log("Getting borrower's credentials...", "info");

    try {
        const credentials = await registry.getUserCredentials(SAMPLE_BORROWER);

        if (credentials.length === 0) {
            log("No credentials found for borrower", "warning");
            return false;
        }

        const credentialId = credentials[0];
        console.log(`  Credential ID: ${formatAddress(credentialId)}`);

        log("Lender verifying credential...", "info");
        const status = await registry.verifyCredential(credentialId);

        const statusNames = ["VALID ✅", "EXPIRED ⏰", "REVOKED 🚫", "NOT_FOUND ❌"];
        console.log(`  Status: ${statusNames[status]}`);

        // Show details
        const credential = await registry.credentials(credentialId);
        console.log(`  Issuer: ${formatAddress(credential.issuer)}`);
        console.log(`  Type: ${credential.credentialType}`);
        console.log(`  Public Signals: [${credential.publicSignals.join(", ")}]`);

        return status === 0; // VALID
    } catch (error) {
        log(`Failed to verify credential: ${error.message}`, "error");
        return false;
    }
}

async function demoRevokeCredential(registry) {
    console.log("\n" + "=".repeat(80));
    log("SCENARIO 3: CREDENTIAL REVOCATION", "header");
    console.log("=".repeat(80));

    log("Getting borrower's credentials...", "info");

    try {
        const credentials = await registry.getUserCredentials(SAMPLE_BORROWER);

        if (credentials.length === 0) {
            log("No credentials found for borrower", "warning");
            return false;
        }

        const credentialId = credentials[0];
        console.log(`  Credential ID: ${formatAddress(credentialId)}`);

        log("Borrower revoking credential...", "info");
        const [signer] = await hre.ethers.getSigners();

        const tx = await registry.connect(signer).revokeCredential(credentialId);
        await tx.wait();

        log("Credential revoked successfully!", "success");
        console.log(`  Transaction: ${tx.hash}`);

        // Verify it's revoked
        const status = await registry.verifyCredential(credentialId);
        const statusNames = ["VALID ✅", "EXPIRED ⏰", "REVOKED 🚫", "NOT_FOUND ❌"];
        console.log(`  New Status: ${statusNames[status]}`);

        return true;
    } catch (error) {
        log(`Failed to revoke credential: ${error.message}`, "error");
        return false;
    }
}

async function demoGetUserCredentials(registry) {
    console.log("\n" + "=".repeat(80));
    log("SCENARIO 4: QUERY USER CREDENTIALS", "header");
    console.log("=".repeat(80));

    log("Fetching all credentials for borrower...", "info");

    try {
        const credentials = await registry.getUserCredentials(SAMPLE_BORROWER);
        console.log(`  Total credentials: ${credentials.length}`);

        if (credentials.length > 0) {
            for (let i = 0; i < credentials.length; i++) {
                const cred = await registry.credentials(credentials[i]);
                console.log(`\n  Credential ${i + 1}:`);
                console.log(`    ID: ${formatAddress(credentials[i])}`);
                console.log(`    Type: ${cred.credentialType}`);
                console.log(`    Issued: ${new Date(cred.issuedAt * 1000).toISOString()}`);
                console.log(`    Expires: ${new Date(cred.expiresAt * 1000).toISOString()}`);
                console.log(`    Revoked: ${cred.revoked}`);
            }
            return true;
        } else {
            log("No credentials found", "warning");
            return false;
        }
    } catch (error) {
        log(`Failed to query credentials: ${error.message}`, "error");
        return false;
    }
}

async function demoGetCredentialCount(registry) {
    console.log("\n" + "=".repeat(80));
    log("SCENARIO 5: GET CREDENTIAL STATISTICS", "header");
    console.log("=".repeat(80));

    log("Calculating statistics...", "info");

    try {
        const totalCredentials = await registry.getCredentialCount(SAMPLE_BORROWER);
        const validCredentials = await registry.getValidCredentialCount(SAMPLE_BORROWER);

        console.log(`  Total credentials: ${totalCredentials}`);
        console.log(`  Valid credentials: ${validCredentials}`);
        console.log(`  Revoked/Expired: ${totalCredentials - validCredentials}`);

        return true;
    } catch (error) {
        log(`Failed to get statistics: ${error.message}`, "error");
        return false;
    }
}

// ============================================================================
// INTERACTIVE MENU
// ============================================================================

async function showMenu() {
    console.log("\n" + "=".repeat(80));
    console.log("📋 INTERACTIVE TEST MENU");
    console.log("=".repeat(80));
    console.log("1. Issue credential to borrower");
    console.log("2. Verify credential (Lender check)");
    console.log("3. Revoke credential (Borrower action)");
    console.log("4. Query borrower's credentials");
    console.log("5. Get credential statistics");
    console.log("6. Run all scenarios");
    console.log("7. Exit");
    console.log("=".repeat(80));
    process.stdout.write("Select option (1-7): ");
}

async function main() {
    console.log("\n" + "=".repeat(80));
    console.log("🚀 CREDITWORTHINESS REGISTRY - INTERACTIVE TEST");
    console.log("=".repeat(80) + "\n");

    // Get contracts
    const [deployer] = await hre.ethers.getSigners();
    log(`Connected as: ${deployer.address}`, "success");

    // Get deployed contract
    const registryAddress = process.env.REGISTRY_ADDRESS;
    if (!registryAddress) {
        log("REGISTRY_ADDRESS not set. Deploy first with: npm run deploy:local", "error");
        return;
    }

    const registry = await hre.ethers.getContractAt(
        "CreditworthinessRegistry",
        registryAddress,
        deployer
    );

    log("Connected to registry", "success");
    console.log(`  Address: ${registryAddress}`);

    // Interactive loop
    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout
    });

    let running = true;

    const askQuestion = () => {
        if (!running) {
            rl.close();
            return;
        }

        rl.question("\nSelect option (1-7): ", async (option) => {
            switch (option) {
                case "1":
                    await demoIssueCredential(registry);
                    break;
                case "2":
                    await demoVerifyCredential(registry);
                    break;
                case "3":
                    await demoRevokeCredential(registry);
                    break;
                case "4":
                    await demoGetUserCredentials(registry);
                    break;
                case "5":
                    await demoGetCredentialCount(registry);
                    break;
                case "6":
                    log("Running all scenarios...", "info");
                    await demoIssueCredential(registry);
                    await delay(1000);
                    await demoVerifyCredential(registry);
                    await delay(1000);
                    await demoGetUserCredentials(registry);
                    await delay(1000);
                    await demoRevokeCredential(registry);
                    await delay(1000);
                    await demoGetCredentialCount(registry);
                    break;
                case "7":
                    log("Exiting...", "info");
                    running = false;
                    rl.close();
                    return;
                default:
                    log("Invalid option", "warning");
            }

            askQuestion();
        });
    };

    showMenu();
    askQuestion();
}

main().catch((error) => {
    console.error("Error:", error);
    process.exit(1);
});
