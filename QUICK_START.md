# ⚡ QUICK START - 5 MINUTES TO WORKING SYSTEM

Fast track to getting everything running locally.

---

## 🚀 Step 1: Setup (2 minutes)

```bash
# Navigate to your project
cd creditworthiness-zkp

# Install dependencies
npm install --save-dev @nomicfoundation/hardhat-toolbox hardhat-gas-reporter solidity-coverage
npm install @openzeppelin/contracts ethers dotenv

# Verify installation
npx hardhat --version
```

---

## 📝 Step 2: Create .env file (1 minute)

```bash
# For LOCAL testing (copy below exactly):
cat > .env << 'EOF'
# Local testing - no real keys needed
PRIVATE_KEY=0x0000000000000000000000000000000000000000000000000000000000000000

# For testnet (fill in your actual keys):
# SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
# MUMBAI_RPC_URL=https://polygon-mumbai.g.alchemy.com/v2/YOUR_KEY
# PRIVATE_KEY=your_actual_private_key

ETHERSCAN_API_KEY=dummy_for_local
POLYGONSCAN_API_KEY=dummy_for_local
EOF
```

---

## 🔨 Step 3: Compile & Deploy (2 minutes)

**Terminal 1 - Start Local Blockchain:**
```bash
npx hardhat node
```

You should see output like:
```
Started HTTP and WebSocket JSON-RPC server at http://127.0.0.1:8545/
```

**Terminal 2 - Deploy Contracts:**
```bash
npx hardhat run scripts/deploy.js --network hardhat
```

You should see:
```
✅ DEPLOYMENT COMPLETE
📍 CONTRACT ADDRESSES:
  CreditworthinessRegistry: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
  CredentialSBT: 0x5FbDB2315678afccb333f8a9c45b65d30d3d0Ce6
```

---

## ✅ What You Now Have

✓ Smart contracts deployed and running
✓ Test accounts with ETH
✓ Authorization configured
✓ Verification keys registered
✓ Ready for testing

---

## 🧪 Quick Test Commands

```bash
# Run all tests
npm test

# Run tests with gas info
REPORT_GAS=true npm test

# Generate coverage report
npm run coverage

# See available npm scripts
npm run
```

---

## 📊 File Structure

```
creditworthiness-zkp/
├── contracts/
│   └── CreditworthinessRegistry.sol    # Main contract
├── test/
│   └── CreditworthinessRegistry.test.js # 55+ tests
├── scripts/
│   ├── deploy.js                        # Deployment
│   ├── setup.js                         # Environment setup
│   └── interactive-test.js              # Interactive demo
├── deployments/                         # Generated deployment info
├── .env                                 # Configuration
├── hardhat.config.js                   # Hardhat settings
└── DEPLOYMENT_GUIDE.md                 # Full guide
```

---

## 🎯 Next: Run Tests

```bash
# In Terminal 2 (if Terminal 1 still has node running):
npx hardhat test --network hardhat
```

Expected: 55 tests passing in ~2-3 seconds

---

## 💡 Common Commands Cheat Sheet

```bash
# Development
npx hardhat node                  # Start local blockchain
npx hardhat compile               # Compile contracts
npx hardhat test                  # Run tests
npx hardhat clean                 # Clean artifacts

# Deployment
npx hardhat run scripts/deploy.js --network hardhat    # Local
npx hardhat run scripts/deploy.js --network sepolia    # Testnet

# Debugging
npx hardhat verify ADDRESS        # Verify on explorer
npx hardhat flatten               # Flatten for review
npx hardhat accounts              # List test accounts
```

---

## ⚠️ Troubleshooting Quick Fixes

**"Cannot find module 'hardhat'"**
```bash
npm install --save-dev hardhat
```

**"Contract not compiling"**
```bash
npx hardhat clean
npx hardhat compile
```

**"Transaction reverted"**
- Make sure local node is running in Terminal 1
- Check contract addresses in REGISTRY_ADDRESS env var

**"Out of gas"**
- Increase gasLimit in hardhat.config.js
- Or increase REPORT_GAS setting

---

## 🎓 Learning Path

1. **Understand System** (15 min)
   - Read: `README_BLOCKCHAIN_PARTS.md`
   - Focus: Parts 1-4 flow

2. **Deploy Locally** (5 min)
   - Follow: This Quick Start
   - Result: Working contracts

3. **Run Tests** (5 min)
   - Command: `npm test`
   - Verify: All 55 pass

4. **Explore Code** (30 min)
   - Read: `BLOCKCHAIN_PART_*.sol` files
   - Study: Test cases for examples

5. **Try Interactive** (15 min)
   - Command: `npx hardhat run scripts/interactive-test.js`
   - Play with: Issuance, verification, revocation

---

## 📞 Need Help?

1. Check `DEPLOYMENT_GUIDE.md` for detailed instructions
2. Review test cases in `CreditworthinessRegistry.test.js` for examples
3. Check blockchain parts breakdown in `BLOCKCHAIN_PART_*.sol` files

---

**Time to first deployment: ~5 minutes** ⚡
**Time to running tests: ~8 minutes** ✅
**Time to understanding system: ~1 hour** 📚

---

Created: 2026-09-27
Status: Ready to use
