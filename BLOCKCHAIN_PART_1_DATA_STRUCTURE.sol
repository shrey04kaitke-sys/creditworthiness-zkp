// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * BLOCKCHAIN PART 1: DATA STRUCTURE
 * This part defines HOW credentials are stored on the blockchain
 */

// =========================================================================
// PART 1A: CREDENTIAL STATUS ENUM
// =========================================================================
// This defines the 4 possible states of a credential

enum CredentialStatus {
    VALID,      // 0 - Credential is currently valid and active
    EXPIRED,    // 1 - Credential has passed its expiration date
    REVOKED,    // 2 - Credential was manually cancelled/revoked
    NOT_FOUND   // 3 - Credential doesn't exist on blockchain
}

// =========================================================================
// PART 1B: CREDENTIAL STRUCT
// =========================================================================
// This defines the exact structure of data stored for each credential

struct Credential {
    bytes32 id;                      // Unique identifier (like a serial number)
                                     // Generated using: keccak256(issuer, user, timestamp, counter)

    address user;                    // Wallet address of the credential holder (borrower)
                                     // Example: 0x742d35Cc6634C0532925a3b844Bc021e2d6e72da

    address issuer;                  // Wallet address of who issued it (bank/credit bureau)
                                     // Example: 0x8ba1f109551bD432803012645Ac136ddd64DBA72

    bytes32 proofHash;               // Hash of the Zero-Knowledge Proof
                                     // Generated using: keccak256(proofA, proofB, proofC)
                                     // We store hash, NOT the actual proof (saves gas, keeps privacy)

    uint256[] publicSignals;         // Array of public signals (thresholds)
                                     // Example: [50000, 95, 700]
                                     // Meaning: Income >= 50k, Payment Ratio = 95%, Credit Score = 700
                                     // These values PROVE conditions WITHOUT revealing actual data

    uint256 issuedAt;                // Unix timestamp when credential was created
                                     // Example: 1695312000 (Sep 21, 2023)

    uint256 expiresAt;               // Unix timestamp when credential expires
                                     // Example: 1726848000 (Sep 21, 2024)
                                     // After this time, verifyCredential() returns EXPIRED

    bool revoked;                    // Boolean: has this credential been revoked?
                                     // true = revoked (cancelled, no longer valid)
                                     // false = not revoked (still valid if not expired)

    string credentialType;           // Type of credential this represents
                                     // Examples: "income_verification", "payment_history",
                                     //           "credit_score_check", "employment_proof"
}

// =========================================================================
// PART 1C: VERIFICATION KEY STRUCT
// =========================================================================
// This stores the Groth16 verification key used to verify ZK proofs

struct VerificationKey {
    uint256[2] alpha;                // Alpha component of verification key
    uint256[2][2] beta;              // Beta component of verification key
    uint256[2] gamma;                // Gamma component of verification key
    uint256[2] delta;                // Delta component of verification key
    uint256[][] gammaABC;            // GammaABC component of verification key
}

// =========================================================================
// HOW DATA IS STORED: MAPPINGS
// =========================================================================

// Map 1: Credential ID → Credential Data
// Purpose: Store all credentials, indexed by their unique ID
mapping(bytes32 => Credential) public credentials;
// Usage: credential = credentials[credentialId];

// Map 2: User Address → Array of Credential IDs
// Purpose: Find all credentials belonging to a user
mapping(address => bytes32[]) public userCredentials;
// Usage: credentialIds = userCredentials[userAddress];

// Map 3: Issuer Address → Verification Key
// Purpose: Store which issuer has which verification key
mapping(address => VerificationKey) public verificationKeys;
// Usage: key = verificationKeys[issuerAddress];

// Map 4: Issuer Address → Boolean
// Purpose: Track which issuers are authorized
mapping(address => bool) public authorizedIssuers;
// Usage: isAuthorized = authorizedIssuers[issuerAddress];

// =========================================================================
// EXAMPLE: HOW DATA LOOKS ON BLOCKCHAIN
// =========================================================================

/*
Let's say Bank A (0x8ba1) issues a credential to Borrower B (0x742d):

credentials[0x4a5f...] = Credential {
    id: 0x4a5f...,
    user: 0x742d35Cc6634C0532925a3b844Bc021e2d6e72da,     // Borrower
    issuer: 0x8ba1f109551bD432803012645Ac136ddd64DBA72,   // Bank A
    proofHash: 0x9e2c...,                                   // Hash of ZK proof
    publicSignals: [50000, 95, 700],                        // Income, Payment, Score
    issuedAt: 1695312000,                                   // Sep 21, 2023
    expiresAt: 1726848000,                                  // Sep 21, 2024
    revoked: false,                                         // Still valid
    credentialType: "income_verification"                   // Type of credential
}

userCredentials[0x742d35Cc...] = [
    0x4a5f...,  // Credential ID 1
    0x7b2e...,  // Credential ID 2
    0x9c1f...   // Credential ID 3
]

authorizedIssuers[0x8ba1f109...] = true   // Bank A is authorized
authorizedIssuers[0x1234abcd...] = false  // Some address is NOT authorized

verificationKeys[0x8ba1f109...] = VerificationKey {
    alpha: [123456..., 789012...],
    beta: [[111..., 222...], [333..., 444...]],
    gamma: [555..., 666...],
    delta: [777..., 888...],
    gammaABC: [[999..., 000...], ...]
}

*/

// =========================================================================
// KEY POINTS ABOUT PART 1
// =========================================================================

/*
1. UNIQUE ID GENERATION:
   - Each credential gets unique ID using keccak256()
   - ID = keccak256(issuer_address, user_address, block.timestamp, counter)
   - This ensures NO TWO credentials have same ID

2. PUBLIC SIGNALS (Privacy Preserved):
   - Instead of storing: "Income = $87,500"
   - We store: publicSignals = [50000] meaning "Income >= 50k"
   - This is proven with Zero-Knowledge Proof
   - Actual income amount is hidden!

3. TIMESTAMPS:
   - issuedAt: When credential was created (can't be changed)
   - expiresAt: When credential becomes invalid
   - Times are Unix timestamps (seconds since Jan 1, 1970)

4. REVOCATION:
   - Credentials can be revoked by setting revoked = true
   - Once revoked, verifyCredential() will always return REVOKED
   - Revocation is permanent (can't be undone)

5. PROOF HASH:
   - We don't store entire ZK proof (too much data, too expensive)
   - We store hash of proof: proofHash = keccak256(proofA, proofB, proofC)
   - This verifies proof was submitted without storing it
*/
