// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * BLOCKCHAIN PART 2: CREDENTIAL ISSUANCE
 * This part explains HOW credentials get created and stored on blockchain
 */

// =========================================================================
// PART 2: THE issueCredential() FUNCTION
// =========================================================================
// This is where banks create credentials for borrowers
// Location in CreditworthinessRegistry.sol: Lines 210-264

/*
FUNCTION SIGNATURE:
--------------------

function issueCredential(
    address user,                    // Borrower's wallet address
    uint256[2] memory proofA,        // Part 1 of Groth16 ZK proof
    uint256[2][2] memory proofB,     // Part 2 of Groth16 ZK proof
    uint256[2] memory proofC,        // Part 3 of Groth16 ZK proof
    uint256[] memory publicSignals,  // Array of thresholds [income, payment_ratio, score]
    string memory credentialType,    // Type: "income_verification", "payment_history", etc
    uint256 validityPeriod           // How long valid (in seconds)
) external onlyAuthorizedIssuer nonReentrant returns (bytes32)
*/

// =========================================================================
// STEP-BY-STEP: WHAT HAPPENS WHEN A BANK ISSUES A CREDENTIAL
// =========================================================================

/*
STEP 1: INPUT VALIDATION
========================
Line 220-222 of CreditworthinessRegistry.sol

require(user != address(0), "Invalid user address");
require(publicSignals.length > 0, "Public signals required");
require(validityPeriod > 0, "Validity period must be positive");

What it checks:
  ✓ user is not the zero address (0x0000...)
  ✓ At least one public signal is provided
  ✓ Validity period is positive (not zero)

Why it matters:
  - Prevents invalid/empty credentials
  - Ensures meaningful threshold data
  - Prevents accidental permanent credentials

Example of VALID inputs:
  user = 0x742d35Cc6634C0532925a3b844Bc021e2d6e72da  ✓
  publicSignals = [50000, 95, 700]                    ✓ (length = 3)
  validityPeriod = 31536000 (1 year in seconds)       ✓ (> 0)

Example of INVALID inputs:
  user = 0x0000000000000000000000000000000000000000   ✗ (zero address)
  publicSignals = []                                  ✗ (empty array)
  validityPeriod = 0                                  ✗ (zero)
*/

// =========================================================================

/*
STEP 2: GENERATE UNIQUE CREDENTIAL ID
======================================
Lines 228-236 of CreditworthinessRegistry.sol

bytes32 credentialId = keccak256(
    abi.encodePacked(
        msg.sender,           // Issuer's address (bank)
        user,                 // Borrower's address
        block.timestamp,      // Current block timestamp
        credentialCounter     // Counter starting at 0, incremented each time
    )
);
credentialCounter++;  // Increment for next credential

What it does:
  - Combines 4 pieces of data into a hash
  - Uses keccak256 (SHA3 equivalent) to create unique ID
  - Increments counter to ensure NO TWO credentials have same ID

The 4 inputs guarantee uniqueness:
  1. msg.sender (issuer) - Different banks have different addresses
  2. user (borrower) - Different borrowers have different addresses
  3. block.timestamp - Different times of issuance
  4. credentialCounter - Different counter values prevent duplicates

Example calculation:

Bank A (0x8ba1) issues to Borrower B (0x742d) at block 17,000,000
  Timestamp: 1695312000 (Sep 21, 2023)
  Counter: 0 (first credential)

  credentialId = keccak256(
    abi.encodePacked(
      0x8ba1f109551bD432803012645Ac136ddd64DBA72,  // Bank A
      0x742d35Cc6634C0532925a3b844Bc021e2d6e72da,  // Borrower B
      1695312000,                                   // Timestamp
      0                                             // Counter
    )
  )

  Result: 0x4a5f2b8d9c1e7f3a6b2d8e4c9a1f7b3d (example)

Each different credential produces a different hash!
  - Same borrower, different bank → Different ID ✓
  - Same borrower, same bank, different time → Different ID ✓
  - Same everything, but counter incremented → Different ID ✓
*/

// =========================================================================

/*
STEP 3: CALCULATE EXPIRATION TIMESTAMP
======================================
Line 239 of CreditworthinessRegistry.sol

uint256 expiresAt = block.timestamp + validityPeriod;

What it does:
  - Adds validity period to current timestamp
  - Stores absolute expiration time (Unix timestamp)

Example:

Issued at: block.timestamp = 1695312000 (Sep 21, 2023)
Validity:  validityPeriod = 31536000 (exactly 1 year in seconds)

Calculation:
  1695312000 + 31536000 = 1726848000 (Sep 21, 2024)

  expiresAt = 1726848000

So this credential expires on Sep 21, 2024

Later, when verifying:
  - If current time < 1726848000 → Credential still valid ✓
  - If current time >= 1726848000 → Credential expired ✗

How to calculate validityPeriod for different durations:
  1 day   = 86,400 seconds = 24*60*60
  1 week  = 604,800 seconds = 7*24*60*60
  1 month = 2,592,000 seconds = 30*24*60*60
  1 year  = 31,536,000 seconds = 365*24*60*60
*/

// =========================================================================

/*
STEP 4: HASH THE ZK PROOF
=========================
Line 242 of CreditworthinessRegistry.sol

bytes32 proofHash = keccak256(abi.encodePacked(proofA, proofB, proofC));

What it does:
  - Takes 3 components of Groth16 proof
  - Combines them and hashes with keccak256
  - Stores hash, NOT the actual proof

Why we store hash, not full proof:

  Issue 1: Storage Cost
    - proofA, proofB, proofC are large numbers
    - Storing them costs ~300,000 gas
    - Hash costs only ~32 bytes
    - Hash costs ~5,000 gas
    → Saves 60x in storage costs!

  Issue 2: Privacy
    - Hash is one-way (cannot reverse to get proof)
    - Actual proof could contain sensitive info
    - Hash proves "proof was submitted" without revealing it

Example:

Groth16 proof has 3 components:
  proofA = [123456789012345678901234567890, 987654321098765432109876543210]
  proofB = [[111..., 222...], [333..., 444...]]
  proofC = [555666777888, 999000111222]

We calculate:
  proofHash = keccak256(
    abi.encodePacked(proofA, proofB, proofC)
  )

  Result: 0x9e2c7a1b5f3d8a4c6e2b9f7a1d3c5b8a (example)

This hash is stored in blockchain
The actual proofA, proofB, proofC are sent to verifier off-chain
  (they don't need to be on blockchain)
*/

// =========================================================================

/*
STEP 5: STORE CREDENTIAL ON BLOCKCHAIN
========================================
Lines 245-255 of CreditworthinessRegistry.sol

credentials[credentialId] = Credential({
    id: credentialId,
    user: user,
    issuer: msg.sender,
    proofHash: proofHash,
    publicSignals: publicSignals,
    issuedAt: block.timestamp,
    expiresAt: expiresAt,
    revoked: false,
    credentialType: credentialType
});

What it does:
  - Creates a Credential struct with all 9 fields
  - Stores it in mapping using credentialId as key
  - Data persists on blockchain forever

The Credential struct contains:
  id               = 0x4a5f...          (unique identifier)
  user             = 0x742d...          (borrower wallet)
  issuer           = 0x8ba1...          (bank wallet)
  proofHash        = 0x9e2c...          (hash of ZK proof)
  publicSignals    = [50000, 95, 700]   (income, payment, score)
  issuedAt         = 1695312000         (issue timestamp)
  expiresAt        = 1726848000         (expiry timestamp)
  revoked          = false              (currently valid)
  credentialType   = "income_verification" (credential type)

Storage diagram:

  credentials mapping:
  ┌─────────────────────────────────────────────────┐
  │ Key: 0x4a5f...                                  │
  │ Value: Credential {                             │
  │   id: 0x4a5f...,                                │
  │   user: 0x742d...,                              │
  │   issuer: 0x8ba1...,                            │
  │   proofHash: 0x9e2c...,                         │
  │   publicSignals: [50000, 95, 700],              │
  │   issuedAt: 1695312000,                         │
  │   expiresAt: 1726848000,                        │
  │   revoked: false,                               │
  │   credentialType: "income_verification"         │
  │ }                                               │
  └─────────────────────────────────────────────────┘

This data is now stored on blockchain and CAN NEVER BE DELETED
  (only revoked, but remains stored)
*/

// =========================================================================

/*
STEP 6: LINK CREDENTIAL TO USER
=================================
Line 258 of CreditworthinessRegistry.sol

userCredentials[user].push(credentialId);

What it does:
  - Adds credentialId to user's array of credentials
  - Allows quick lookup: "Get all credentials for borrower X"

Example:

Before Step 6:
  userCredentials[0x742d] = []  (empty array)

After Step 6:
  userCredentials[0x742d] = [0x4a5f]

If same borrower gets another credential later:
  userCredentials[0x742d] = [0x4a5f, 0x7b2e]

If another borrower gets a credential:
  userCredentials[0x1234] = [0x9c1f]

This enables queries like:
  "How many credentials does borrower 0x742d have?"
  → Loop through userCredentials[0x742d] array

This is faster than searching ALL credentials:
  - Without this: check every credential in database
  - With this: check only borrower's credentials
*/

// =========================================================================

/*
STEP 7: EMIT EVENT (LOG TO BLOCKCHAIN)
=======================================
Line 261 of CreditworthinessRegistry.sol

emit CredentialIssued(
    credentialId,     // The ID of credential just created
    user,             // Borrower's address
    msg.sender,       // Bank's address (issuer)
    credentialType,   // Type of credential
    expiresAt         // When it expires
);

What it does:
  - Creates a log entry on blockchain
  - Front-end apps can "listen" for this event
  - Anyone can see it happened

Event definition (line 84-90):
  event CredentialIssued(
      bytes32 indexed credentialId,
      address indexed user,
      address indexed issuer,
      string credentialType,
      uint256 expiresAt
  );

Why events matter:

  1. Notifications
     - Front-end listens for CredentialIssued event
     - Shows "Your credential was issued!" notification

  2. Indexing
     - Blockchain explorers index events
     - Allows searching: "Show all credentials issued by Bank A"

  3. Off-chain tracking
     - Applications can build databases from events
     - Without reading entire blockchain state

Example event log:

  Block: 17,000,100
  Transaction: 0xabc123...
  Event: CredentialIssued
    credentialId: 0x4a5f...
    user: 0x742d...
    issuer: 0x8ba1...
    credentialType: "income_verification"
    expiresAt: 1726848000

Anyone watching blockchain sees this event immediately
Notifications can be triggered, databases updated, etc.
*/

// =========================================================================

/*
STEP 8: RETURN CREDENTIAL ID
=============================
Line 263 of CreditworthinessRegistry.sol

return credentialId;

What it does:
  - Returns the credentialId to the calling bank
  - Bank can display this to borrower
  - Borrower needs this ID to use credential later

Bank gets back: 0x4a5f...
Bank shows borrower: "Your credential ID: 0x4a5f..."
Borrower can use this ID to:
  - Share with lenders
  - Check status
  - Request revocation
*/

// =========================================================================
// COMPLETE EXAMPLE: BANK ISSUES CREDENTIAL TO BORROWER
// =========================================================================

/*
SCENARIO:
  Bank A (0x8ba1) issues income verification credential to Borrower B (0x742d)
  Credential valid for 1 year
  Public signals: Income ≥ $50k, 95% payment ratio, 700 credit score

STEP-BY-STEP EXECUTION:

1. Bank calls issueCredential() with:

   user = 0x742d35Cc6634C0532925a3b844Bc021e2d6e72da
   proofA = [11111..., 22222...]
   proofB = [[33333..., 44444...], [55555..., 66666...]]
   proofC = [77777..., 88888...]
   publicSignals = [50000, 95, 700]
   credentialType = "income_verification"
   validityPeriod = 31536000 (1 year)

2. Contract validates inputs:
   ✓ user != 0x0000...
   ✓ publicSignals.length = 3 (> 0)
   ✓ validityPeriod = 31536000 (> 0)

3. Contract generates unique ID:
   credentialId = keccak256(
     0x8ba1f109551bD432803012645Ac136ddd64DBA72,  // Bank A
     0x742d35Cc6634C0532925a3b844Bc021e2d6e72da,  // Borrower B
     1695312000,                                   // Current time
     0                                             // Counter = 0
   )
   → credentialId = 0x4a5f2b8d9c1e7f3a6b2d8e4c9a1f7b3d
   → credentialCounter incremented to 1

4. Contract calculates expiration:
   expiresAt = 1695312000 + 31536000 = 1726848000

5. Contract hashes proof:
   proofHash = keccak256(
     [11111..., 22222...],
     [[33333..., 44444...], [55555..., 66666...]],
     [77777..., 88888...]
   )
   → proofHash = 0x9e2c7a1b5f3d8a4c6e2b9f7a1d3c5b8a

6. Contract stores credential:
   credentials[0x4a5f...] = {
     id: 0x4a5f...,
     user: 0x742d...,
     issuer: 0x8ba1...,
     proofHash: 0x9e2c...,
     publicSignals: [50000, 95, 700],
     issuedAt: 1695312000,
     expiresAt: 1726848000,
     revoked: false,
     credentialType: "income_verification"
   }

7. Contract links to user:
   userCredentials[0x742d...] = [0x4a5f...]

8. Contract emits event:
   CredentialIssued(
     0x4a5f...,
     0x742d...,
     0x8ba1...,
     "income_verification",
     1726848000
   )

9. Contract returns:
   → 0x4a5f...

RESULT:
  ✅ Credential stored on blockchain
  ✅ Borrower can now use this credential with lenders
  ✅ Event logged for visibility
  ✅ ID returned to bank for confirmation

Later, when Borrower shares with Lender:
  Borrower says: "Here's my credential ID: 0x4a5f..."
  Lender looks it up: credentials[0x4a5f...]
  Lender verifies: It's valid, not expired, not revoked
  Lender approves loan!
*/

// =========================================================================
// KEY POINTS ABOUT ISSUANCE
// =========================================================================

/*
1. AUTHORIZATION CHECK:
   Only authorized issuers can call issueCredential()
   Modifier: onlyAuthorizedIssuer (line 122-125)

   require(authorizedIssuers[msg.sender], "Not an authorized issuer");

   Prevents random people from issuing credentials
   Only banks/credit bureaus registered in authorizedIssuers can issue

2. REENTRANCY PROTECTION:
   Modifier: nonReentrant (line 218)

   Prevents re-entrancy attacks:
   - Call issueCredential() recursively
   - Modify state multiple times in one call
   - nonReentrant blocks this

3. UNIQUENESS GUARANTEE:
   credentialId = keccak256(issuer, user, timestamp, counter)

   Four factors ensure no two credentials are identical:
   - issuer: Different banks can't reuse same ID
   - user: Different borrowers can't reuse same ID
   - timestamp: Different times produce different hashes
   - counter: Even at same time, counter increments

4. IMMUTABILITY:
   Once stored, credential data cannot be changed
   Can only be revoked (revoked = true)
   Original data is preserved forever

5. PRIVACY PRESERVATION:
   - Store proofHash, not actual proof
   - Public signals show thresholds, not actual data
   - Borrower's income, score, etc. stay private
   - Only proof of meeting threshold is public
*/

// =========================================================================
// SECURITY CONSIDERATIONS
// =========================================================================

/*
1. INPUT VALIDATION
   ✓ User address must not be zero
   ✓ Public signals must not be empty
   ✓ Validity period must be positive

2. ACCESS CONTROL
   ✓ Only authorized issuers can issue
   ✓ Prevents unauthorized credential creation

3. REENTRANCY PROTECTION
   ✓ nonReentrant guard prevents attacks
   ✓ State changes are atomic

4. ZERO-KNOWLEDGE PROOF VERIFICATION (TODO)
   ✗ Currently accepts proof without verification
   ✗ Line 224: "TODO: Verify ZK proof"
   → Future: Implement Groth16 verification
      using verificationKeys[msg.sender]
*/

