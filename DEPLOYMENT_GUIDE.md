# 🚀 DEPLOYMENT & SETUP GUIDE

Complete step-by-step guide for setting up, testing, and deploying the Creditworthiness Registry system.

---

## 📋 TABLE OF CONTENTS

1. [Prerequisites](#prerequisites)
2. [Project Setup](#project-setup)
3. [Local Development](#local-development)
4. [Running Tests](#running-tests)
5. [Deploying to Testnet](#deploying-to-testnet)
6. [Interactive Testing](#interactive-testing)
7. [Verification & Security](#verification--security)
8. [Troubleshooting](#troubleshooting)

---

## 📦 PREREQUISITES

Before you begin, ensure you have:

### System Requirements
- **Node.js**: v16.0.0 or higher
- **npm**: v7.0.0 or higher
- **Git**: for version control

### Check your versions:
```bash
node --version    # Should be v16+
npm --version     # Should be v7+
git --version     # Should be installed
```

### Accounts & API Keys

You'll need:
1. **MetaMask or similar wallet** (for testnets)
2. **Alchemy account** (free tier)
   - Get at: https://www.alchemy.com/
   - Create projects for Sepolia & Mumbai
3. **Etherscan API key** (free)
   - Get at: https://etherscan.io/apis
4. **PolygonScan API key** (free)
   - Get at: https://polygonscan.com/apis

---

## 🔧 PROJECT SETUP

### Step 1: Initialize Hardhat Project

```bash
# Create project directory
mkdir creditworthiness-zkp
cd creditworthiness-zkp

# Initialize npm
npm init -y

# Install Hardhat
npm install --save-dev hardhat

# Initialize Hardhat project
npx hardhat
# Select: "Create a basic sample project"
# Select: "Yes" to all prompts
```

### Step 2: Install Dependencies

```bash
npm install --save-dev @nomicfoundation/hardhat-toolbox
npm install --save-dev @nomicfoundation/hardhat-ethers ethers
npm install --save-dev hardhat-gas-reporter
npm install --save-dev solidity-coverage
npm install --save-dev @openzeppelin/contracts
npm install dotenv
```

### Step 3: Copy Smart Contracts

Create `contracts/CreditworthinessRegistry.sol`:
```bash
# Place the main contract file here
# Should contain both CreditworthinessRegistry and CredentialSBT contracts
```

### Step 4: Copy Test Files

Create `test/CreditworthinessRegistry.test.js`:
```bash
# Place the test suite here (1,200+ lines)
# Contains 55+ unit tests covering all functionality
```

### Step 5: Copy Deployment Scripts

Create `scripts/deploy.js`:
```bash
# Place the main deployment script here
# Deploys contracts and initializes the system
```

### Step 6: Configure Environment

Create `.env` file:
```bash
# RPC URLs (get from Alchemy)
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
MUMBAI_RPC_URL=https://polygon-mumbai.g.alchemy.com/v2/YOUR_API_KEY

# Private Key (from MetaMask or test account)
# WARNING: Never commit this file!
PRIVATE_KEY=your_private_key_without_0x_prefix

# API Keys for verification
ETHERSCAN_API_KEY=your_etherscan_api_key
POLYGONSCAN_API_KEY=your_polygonscan_api_key

# Optional: Gas reporting
REPORT_GAS=false
COINMARKETCAP_API_KEY=your_coinmarketcap_key
```

**⚠️ SECURITY WARNING:**
- Never commit `.env` to git
- Add to `.gitignore`:
  ```
  .env
  .env.local
  node_modules/
  artifacts/
  cache/
  ```

---

## 💻 LOCAL DEVELOPMENT

### Compile Contracts

```bash
npx hardhat compile
```

Output:
```
✓ Compiled successfully
✓ Generated 2 artifacts
```

### Start Local Node

Terminal 1:
```bash
npx hardhat node
```

This starts a local Ethereum node at `http://localhost:8545`

Example output:
```
Started HTTP and WebSocket JSON-RPC server at http://127.0.0.1:8545/
Accounts:
0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 (10000 ETH)
0x70997970C51812e339D9B73b0245ad59c36d2ef7 (10000 ETH)
...
```

### Deploy to Local Network

Terminal 2:
```bash
npx hardhat run scripts/deploy.js --network hardhat
```

Output:
```
================================================================================
🚀 CREDITWORTHINESS REGISTRY DEPLOYMENT
================================================================================

📝 Deployer Address: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
🌐 Network: hardhat
💰 Balance: 10000.0 ETH

📋 STEP 1: Deploying CredentialSBT Contract...
✓ CredentialSBT deployed at: 0x5FbDB2315678afccb333f8a9c45b65d30d3d0Ce6

📋 STEP 2: Deploying CreditworthinessRegistry Contract...
✓ CreditworthinessRegistry deployed at: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512

📋 STEP 3: Initializing SBT with Registry Address...
✓ SBT registry initialized

📋 STEP 4: Authorizing Sample Issuers...
✓ Bank A: 0x8ba1...e5e4
✓ Bank B: 0x7a9a...7a9a
✓ Bank C: 0x6b8b...6b8b

📋 STEP 5: Registering Groth16 Verification Keys...
✓ Verification key registered for 0x8ba1...e5e4

✅ DEPLOYMENT COMPLETE
📍 CONTRACT ADDRESSES:
  CreditworthinessRegistry: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
  CredentialSBT: 0x5FbDB2315678afccb333f8a9c45b65d30d3d0Ce6

💾 Deployment info saved to deployments/hardhat-1695312000000.json
```

### Save Contract Addresses

Copy the deployed addresses and save them for later use:
```bash
# Update .env with deployed addresses
REGISTRY_ADDRESS=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
SBT_ADDRESS=0x5FbDB2315678afccb333f8a9c45b65d30d3d0Ce6
```

---

## 🧪 RUNNING TESTS

### Run All Tests

```bash
npx hardhat test
```

Expected output:
```
✓ Issuer Authorization (7 tests)
  ✓ Authorize issuer successfully
  ✓ Reject authorization if already authorized
  ✓ Deauthorize issuer successfully
  ✓ Only owner can authorize/deauthorize
  ✓ Emit AuthorizedIssuer event
  ✓ Emit DeauthorizedIssuer event
  ✓ Verify issuer status

✓ Verification Key Management (3 tests)
  ✓ Register verification key successfully
  ✓ Reject duplicate verification key
  ✓ Only authorized issuers can register

✓ Credential Issuance (9 tests)
  ✓ Issue credential successfully
  ✓ Generate unique credential IDs
  ✓ Store credential data correctly
  ✓ Link credential to user
  ✓ Validate input parameters
  ✓ Emit CredentialIssued event
  ✓ Calculate expiration correctly
  ✓ Hash proof correctly
  ✓ Prevent reentrancy

✓ Credential Verification (7 tests)
  ✓ Verify valid credential
  ✓ Return EXPIRED for expired credential
  ✓ Return REVOKED for revoked credential
  ✓ Return NOT_FOUND for missing credential
  ✓ isCredentialValid() returns boolean
  ✓ Public signals are retrievable
  ✓ Verification is view-only (no gas)

✓ Credential Revocation (8 tests)
  ✓ Borrower can revoke credential
  ✓ Issuer can revoke credential
  ✓ Owner can revoke credential
  ✓ Only authorized parties can revoke
  ✓ Revocation is permanent
  ✓ Emit CredentialRevoked event
  ✓ Revoked credential is marked as revoked
  ✓ Cannot revoke already revoked credential

✓ User Credential Queries (6 tests)
  ✓ Get all user credentials
  ✓ Get valid credential count
  ✓ Get expired credentials
  ✓ Get revoked credentials
  ✓ Handle empty credential lists
  ✓ Return correct credential count

✓ Soul Bound Token (10 tests)
  ✓ Mint SBT on credential issuance
  ✓ SBT linked to credential
  ✓ SBT cannot be transferred
  ✓ SBT cannot be approved
  ✓ SBT cannot be approved for all
  ✓ SBT is burned on revocation
  ✓ Check token validity
  ✓ Token URI is set correctly
  ✓ Only registry can mint
  ✓ Only registry can burn

✓ Security & Edge Cases (5 tests)
  ✓ Reentrancy protection
  ✓ Handle multiple credentials per user
  ✓ Handle large credential arrays
  ✓ Credential immutability
  ✓ Timestamp validation

55 passing (2.3s)
```

### Run Tests with Gas Reporting

```bash
REPORT_GAS=true npx hardhat test
```

This shows gas usage for each function:
```
·                 Deploying Contracts                                      
·  ·   CreditworthinessRegistry        ·  -                ·    3,500,000  ·   3,500,000  ·
·  ·   CredentialSBT                   ·  -                ·    2,100,000  ·   2,100,000  ·
·                 Issuer Functions                                          
·  ·   authorize issuer                ·  -                ·       65,000  ·      65,000  ·
·  ·   issueCredential                 ·  -                ·      250,000  ·      350,000  ·
·  ·   verifyCredential (view)         ·  -                ·            0  ·            0  ·
·  ·   revokeCredential                ·  -                ·      120,000  ·      150,000  ·
```

### Run Tests with Coverage

```bash
npx hardhat coverage
```

Generates coverage report:
```
CreditworthinessRegistry          · 100%  ·  100%  ·  100%  ·  100%
CredentialSBT                     · 100%  ·  100%  ·  100%  ·  100%

All files                         · 100%  ·  100%  ·  100%  ·  100%
```

---

## 🌐 DEPLOYING TO TESTNET

### Setup Testnet Wallet

1. **Export Private Key from MetaMask:**
   - Open MetaMask
   - Click account → Settings → Security & Privacy
   - Click "Export Private Key"
   - Copy the key (without 0x prefix)
   - Add to `.env`: `PRIVATE_KEY=your_key_here`

2. **Get Testnet ETH:**
   - **Sepolia**: https://sepoliafaucet.com
   - **Mumbai**: https://faucet.polygon.technology/

### Deploy to Sepolia

```bash
npx hardhat run scripts/deploy.js --network sepolia
```

### Deploy to Mumbai

```bash
npx hardhat run scripts/deploy.js --network mumbai
```

### Verify Deployment

Check the generated `deployments/` file:
```bash
cat deployments/sepolia-*.json
```

Output:
```json
{
  "network": "sepolia",
  "timestamp": "2024-09-27T10:30:00Z",
  "deployer": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  "contracts": {
    "CreditworthinessRegistry": "0x...",
    "CredentialSBT": "0x..."
  }
}
```

### Verify Contracts on Block Explorer

```bash
npx hardhat verify --network sepolia <CONTRACT_ADDRESS> <CONSTRUCTOR_ARGS>
```

Example:
```bash
npx hardhat verify --network sepolia 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 0x5FbDB2315678afccb333f8a9c45b65d30d3d0Ce6
```

---

## 🧬 INTERACTIVE TESTING

### Run Interactive Demo

```bash
export REGISTRY_ADDRESS=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
npx hardhat run scripts/interactive-test.js --network hardhat
```

### Menu Options

```
📋 INTERACTIVE TEST MENU
================================================================================
1. Issue credential to borrower
2. Verify credential (Lender check)
3. Revoke credential (Borrower action)
4. Query borrower's credentials
5. Get credential statistics
6. Run all scenarios
7. Exit
================================================================================
```

### Example Scenario: Issue & Verify

```
✅ SCENARIO 1: CREDENTIAL ISSUANCE
  Borrower: 0x742d...742d
  Issuer: 0x8ba1...e5e4
  Public Signals (Income, Payment Ratio, Credit Score):
    • 50000 (Monthly income)
    • 95% (Payment history)
    • 700 (Credit score)
✅ Credential issued successfully!

✅ SCENARIO 2: CREDENTIAL VERIFICATION
  Credential ID: 0x4a5f...5f8e
  Status: VALID ✅
  Issuer: 0x8ba1...e5e4
  Type: income_verification
  Public Signals: [50000, 95, 700]
```

---

## 🔐 VERIFICATION & SECURITY

### Code Quality Checks

```bash
# Flatten contract for review
npx hardhat flatten contracts/CreditworthinessRegistry.sol > flattened.sol

# Run slither (requires pip install slither-analyzer)
slither contracts/CreditworthinessRegistry.sol
```

### Security Audit Checklist

- [ ] All tests pass (55/55)
- [ ] Gas usage is optimized
- [ ] Authorization checks are in place
- [ ] Reentrancy guards are implemented
- [ ] Events are emitted for all state changes
- [ ] Input validation is comprehensive
- [ ] No unchecked external calls

### Best Practices

1. **Never hardcode sensitive data**
   - Use `.env` for private keys
   - Use `.env.local` for local overrides

2. **Always verify on block explorer**
   - Sepolia: https://sepolia.etherscan.io
   - Mumbai: https://mumbaiscan.com

3. **Monitor contract interactions**
   - Use Etherscan event logs
   - Track gas consumption
   - Monitor for suspicious activity

---

## 🐛 TROUBLESHOOTING

### Error: "Cannot find module 'hardhat'"

```bash
npm install --save-dev hardhat
npx hardhat
```

### Error: "PRIVATE_KEY not set"

```bash
# Create .env file
echo "PRIVATE_KEY=your_key_here" > .env
```

### Error: "Insufficient funds"

```bash
# Get testnet ETH
# Sepolia: https://sepoliafaucet.com
# Mumbai: https://faucet.polygon.technology/
```

### Error: "Contract already deployed at address"

The script detects existing contracts. To redeploy:
```bash
# Start fresh
npx hardhat clean
npx hardhat compile
npx hardhat run scripts/deploy.js --network hardhat
```

### Error: "Transaction reverted: contract not authorized"

Make sure:
1. Issuer is authorized: `authorizeIssuer(issuerAddress)`
2. Verification key is registered: `registerVerificationKey(...)`
3. Caller has proper role

### Slow Block Confirmation

```bash
# Increase gas price for Sepolia
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
# May need to wait 30-60 seconds for confirmation
```

### Contract Verification Fails

```bash
# Make sure source code matches exactly
# Verify constructor arguments
npx hardhat verify --network sepolia ADDRESS "arg1" "arg2"

# If still fails, try with solc version
npx hardhat verify --network sepolia ADDRESS --solc-input solc.json
```

---

## 📊 USEFUL COMMANDS REFERENCE

```bash
# Compilation
npx hardhat compile              # Compile contracts
npx hardhat clean                # Clean artifacts

# Testing
npx hardhat test                 # Run all tests
npx hardhat test --grep "Issue"  # Run specific tests
REPORT_GAS=true npx hardhat test # With gas reporting
npx hardhat coverage             # Code coverage

# Deployment
npx hardhat run scripts/deploy.js --network hardhat   # Local
npx hardhat run scripts/deploy.js --network sepolia   # Sepolia
npx hardhat run scripts/deploy.js --network mumbai    # Mumbai

# Verification
npx hardhat verify --network sepolia ADDRESS          # Verify contract
npx hardhat flatten contracts/CreditworthinessRegistry.sol  # Flatten code

# Node Management
npx hardhat node                 # Start local node
npx hardhat accounts             # List accounts
npx hardhat network              # Show network info

# Utility
npx hardhat help                 # Show all commands
```

---

## ✅ FINAL CHECKLIST

Before going to production:

- [ ] All 55 tests pass
- [ ] Gas usage optimized
- [ ] Code coverage > 95%
- [ ] Smart contracts verified on block explorer
- [ ] Environment variables configured
- [ ] Private keys stored securely
- [ ] Deployment logs saved
- [ ] Team has access to deployment info
- [ ] Monitoring setup complete
- [ ] Backup of deployment artifacts

---

## 🎓 NEXT STEPS

After deployment:

1. **Implement Groth16 Verification** (Phase 3)
   - Add proof verification logic
   - Test with actual proofs from snarkjs
   - Optimize verification gas costs

2. **Build Frontend UI** (Phase 4)
   - Create borrower dashboard
   - Create lender verification interface
   - Connect to deployed contracts

3. **Setup Monitoring**
   - Contract event tracking
   - Gas price monitoring
   - Security event alerts

4. **Documentation**
   - API documentation
   - User guides
   - Integration guide for lenders

---

**Last Updated**: 2026-09-27
**Status**: Ready for deployment
**Version**: 1.0
