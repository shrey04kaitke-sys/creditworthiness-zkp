// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * BLOCKCHAIN PART 3: CREDENTIAL VERIFICATION
 * This part explains HOW lenders check if credentials are valid
 */

// =========================================================================
// PART 3: THE verifyCredential() FUNCTION
// =========================================================================
// This is where lenders check if a credential is still valid
// Location in CreditworthinessRegistry.sol: Lines 275-296

/*
FUNCTION SIGNATURE:
--------------------

function verifyCredential(bytes32 credentialId)
    external
    view
    returns (CredentialStatus)

What it returns:
  - CredentialStatus.VALID     → Credential is good, approve the loan!
  - CredentialStatus.EXPIRED   → Credential expired, ask borrower to renew
  - CredentialStatus.REVOKED   → Credential revoked, reject the loan
  - CredentialStatus.NOT_FOUND → Credential doesn't exist

Key word: "view" → This function doesn't modify blockchain state
         It only READS data, costs no gas (when called read-only)
*/

// =========================================================================
// THE VERIFICATION LOGIC: 4 CHECKS
// =========================================================================

/*
When lender calls: verifyCredential(credentialId)

The contract performs 4 checks IN ORDER:

CHECK 1: DOES THE CREDENTIAL EXIST?
====================================
Line 280-282 of CreditworthinessRegistry.sol

if (cred.id == bytes32(0)) {
    return CredentialStatus.NOT_FOUND;
}

What it checks:
  Is the credential ID stored in blockchain?

How it works:
  - bytes32(0) = 0x0000000000000000000000000000000000000000000000000000000000000000
  - If credential was never created, cred.id will be this empty value
  - If credential exists, cred.id will have actual value

Example NOT_FOUND:

Lender checks: verifyCredential(0x9999...)
  ↓
Contract looks up: credentials[0x9999...]
  ↓
Result: Returns empty Credential struct
  (all fields are zero/empty)
  ↓
Check: cred.id == bytes32(0)?
  YES! ✓
  ↓
Return: CredentialStatus.NOT_FOUND ❌

Why it happens:
  - Borrower typo'd the credential ID
  - Credential was never issued in first place
  - Credential was deleted (shouldn't happen, but check anyway)

Example FOUND:

Lender checks: verifyCredential(0x4a5f...)
  ↓
Contract looks up: credentials[0x4a5f...]
  ↓
Result: Returns actual Credential {
  id: 0x4a5f...,
  user: 0x742d...,
  issuer: 0x8ba1...,
  ...
}
  ↓
Check: cred.id == bytes32(0)?
  NO! The ID is 0x4a5f..., not zero
  ↓
Continue to CHECK 2...
*/

// =========================================================================

/*
CHECK 2: IS THE CREDENTIAL REVOKED?
====================================
Line 284-287 of CreditworthinessRegistry.sol

if (cred.revoked) {
    return CredentialStatus.REVOKED;
}

What it checks:
  Has the borrower or issuer revoked this credential?

The revoked field:
  revoked = false  → Credential is still active
  revoked = true   → Credential has been cancelled

Example REVOKED:

Scenario:
  Borrower had good income when credential issued
  But borrower lost their job
  Borrower revokes the credential

  credentials[0x4a5f...].revoked = true

Later, lender checks:
  verifyCredential(0x4a5f...)
  ↓
  Check 1: Does it exist? YES ✓
  ↓
  Check 2: cred.revoked?
    YES! revoked = true
  ↓
  Return: CredentialStatus.REVOKED ❌
  ↓
  Lender says: "Your credential was revoked, can't approve loan"

Example NOT REVOKED:

credentials[0x4a5f...].revoked = false (normal state)

Lender checks:
  verifyCredential(0x4a5f...)
  ↓
  Check 1: Does it exist? YES ✓
  ↓
  Check 2: cred.revoked?
    NO! revoked = false
  ↓
  Continue to CHECK 3...

Why borrowers revoke credentials:

  1. Income changed
     "My income dropped, credential might not be accurate"

  2. Employment status changed
     "I got fired, revoke my income verification"

  3. Credit score dropped
     "My credit score fell, don't want lenders seeing old credential"

  4. Privacy concerns
     "I don't want this credential floating around anymore"

Why issuers revoke credentials:

  1. Discovered fraud
     "Borrower's income documents were fake"

  2. Account closure
     "Borrower's account with us is closed"

  3. Policy change
     "We no longer stand behind this credential"

Why contract owner revokes credentials:

  1. System maintenance
     "Found a bug in credential issuance, revoke until fixed"

  2. Security incident
     "Revoke compromised credentials after data breach"
*/

// =========================================================================

/*
CHECK 3: HAS THE CREDENTIAL EXPIRED?
====================================
Line 289-292 of CreditworthinessRegistry.sol

if (block.timestamp > cred.expiresAt) {
    return CredentialStatus.EXPIRED;
}

What it checks:
  Is the current time after the expiration time?

How it works:
  - block.timestamp = current time on blockchain (Unix timestamp)
  - cred.expiresAt = when this credential expires (Unix timestamp)
  - If current time > expiration time → Credential has expired

Example EXPIRED:

Credential details:
  issuedAt: 1695312000 (Sep 21, 2023)
  expiresAt: 1726848000 (Sep 21, 2024)

Current situation: Today is Oct 1, 2024
  block.timestamp = 1727740800 (Oct 1, 2024)

Check:
  block.timestamp (1727740800) > expiresAt (1726848000)?
  YES! 1727740800 > 1726848000 ✓
  ↓
  Return: CredentialStatus.EXPIRED ⏰

Lender sees: "Your credential expired on Sep 21, 2024"
Lender says: "Request a new credential from your bank"

Example NOT EXPIRED:

Same credential, but today is Sep 10, 2024
  block.timestamp = 1725912000 (Sep 10, 2024)

Check:
  block.timestamp (1725912000) > expiresAt (1726848000)?
  NO! 1725912000 < 1726848000
  ↓
  Continue to CHECK 4...

Why credentials expire:

  1. Ensure freshness
     "Income from 2023 might not reflect 2024 reality"

  2. Reduce fraud risk
     "Stale credentials reduce relevance"

  3. Force periodic re-verification
     "Banks want to re-verify borrower status annually"

  4. Market standard
     "Most credit reports expire after 1-2 years"

Typical validity periods:

  Employment verification: 3-6 months (job can change)
  Income verification: 1 year (usually annual tax returns)
  Credit score: 1 month (scores change frequently)
  Payment history: 6-12 months (payment habits may change)

Unix timestamp examples:

  Sep 21, 2023: 1695312000
  Sep 21, 2024: 1726848000 (+ 31,536,000 seconds = 1 year)
  Sep 21, 2025: 1758384000 (+ 31,536,000 seconds = 2 years)
*/

// =========================================================================

/*
CHECK 4: ALL GOOD! CREDENTIAL IS VALID
========================================
Line 294-296 of CreditworthinessRegistry.sol

return CredentialStatus.VALID;

If all three checks passed:
  ✓ Credential exists (not NOT_FOUND)
  ✓ Credential not revoked (not REVOKED)
  ✓ Credential not expired (not EXPIRED)

Then: The credential is VALID!

Lender sees: CredentialStatus.VALID ✅
Lender approves: "Credential is good, approve the loan!"

This is the happy path - everything checks out
*/

// =========================================================================
// HELPER FUNCTION: isCredentialValid()
// =========================================================================

/*
Line 303-306 of CreditworthinessRegistry.sol

function isCredentialValid(bytes32 credentialId)
    external
    view
    returns (bool)
{
    CredentialStatus status = this.verifyCredential(credentialId);
    return status == CredentialStatus.VALID;
}

What it does:
  Wrapper around verifyCredential()
  Returns simple boolean instead of CredentialStatus enum

Usage:
  if (isCredentialValid(credentialId)) {
      // Credential is valid, approve loan
  } else {
      // Credential is NOT valid
  }

Convenience:
  When you only care about "valid" vs "not valid"
  Instead of checking all 4 statuses
  Just use this true/false shortcut
*/

// =========================================================================
// COMPLETE EXAMPLE: LENDER VERIFIES CREDENTIAL
// =========================================================================

/*
SCENARIO:
  Borrower B (0x742d) applies for loan with Lender L
  Borrower provides credential ID: 0x4a5f...
  Lender wants to verify it's real

STEP-BY-STEP:

1. Lender calls verifyCredential(0x4a5f...)

2. Contract reads: credentials[0x4a5f...]
   Result:
   {
     id: 0x4a5f...,
     user: 0x742d...,
     issuer: 0x8ba1... (Bank A),
     proofHash: 0x9e2c...,
     publicSignals: [50000, 95, 700],
     issuedAt: 1695312000 (Sep 21, 2023),
     expiresAt: 1726848000 (Sep 21, 2024),
     revoked: false,
     credentialType: "income_verification"
   }

3. CHECK 1: Does credential exist?
   cred.id == bytes32(0)?
   0x4a5f... == 0x0000...?
   NO! ✓
   Continue...

4. CHECK 2: Is credential revoked?
   cred.revoked?
   false?
   NO! (revoked = false means NOT revoked) ✓
   Continue...

5. CHECK 3: Has credential expired?
   block.timestamp > cred.expiresAt?
   Current time: 1700000000 (Nov 14, 2023)
   Expiration: 1726848000 (Sep 21, 2024)
   1700000000 > 1726848000?
   NO! Still 10 months until expiration ✓
   Continue...

6. CHECK 4: All checks passed!
   Return: CredentialStatus.VALID ✅

7. Lender receives: VALID
   Lender approves: "Credential is valid, approve the loan!"

RESULT:
  ✅ Borrower's loan approved
  ✅ Lender confirmed credential authenticity
  ✅ No fraud detected
*/

// =========================================================================
// EXAMPLE 2: CREDENTIAL HAS EXPIRED
// =========================================================================

/*
Same credential (0x4a5f...), but now it's Oct 1, 2024

Credential stored:
  expiresAt: 1726848000 (Sep 21, 2024)

Current time: 1727740800 (Oct 1, 2024)

1. Lender calls: verifyCredential(0x4a5f...)

2. Contract reads: credentials[0x4a5f...]

3. CHECK 1: Does credential exist?
   cred.id == bytes32(0)?
   NO! Exists ✓
   Continue...

4. CHECK 2: Is credential revoked?
   cred.revoked?
   NO! (still false) ✓
   Continue...

5. CHECK 3: Has credential expired?
   block.timestamp > cred.expiresAt?
   1727740800 > 1726848000?
   YES! ✗ Expired 10 days ago!
   ↓
   Return: CredentialStatus.EXPIRED ⏰

6. Lender receives: EXPIRED
   Lender says: "Your credential expired on Sep 21, 2024"
   Lender rejects: "Get a fresh credential from your bank and reapply"

RESULT:
  ❌ Loan not approved
  ⏰ Borrower needs to renew credential
  → Borrower goes back to Bank A
  → Bank A re-verifies income
  → Bank A issues new credential
  → Borrower tries again with new credential
*/

// =========================================================================
// EXAMPLE 3: CREDENTIAL WAS REVOKED
// =========================================================================

/*
Same credential (0x4a5f...), but now it's been revoked

Credential stored:
  revoked: true (just set to true by borrower)
  expiresAt: 1726848000 (not expired yet)

Current time: 1723608000 (Aug 14, 2024) - Before expiration!

1. Lender calls: verifyCredential(0x4a5f...)

2. Contract reads: credentials[0x4a5f...]

3. CHECK 1: Does credential exist?
   cred.id == bytes32(0)?
   NO! Exists ✓
   Continue...

4. CHECK 2: Is credential revoked?
   cred.revoked?
   YES! ✗ revoked = true!
   ↓
   Return: CredentialStatus.REVOKED 🚫

5. Lender receives: REVOKED
   Lender says: "This credential was revoked"
   Lender rejects: "Can't approve loan with revoked credential"

RESULT:
  ❌ Loan not approved
  🚫 Credential actively cancelled
  → Borrower must request new credential from bank
  → But revocation suggests borrower situation changed
  → Lender might ask: "Why was it revoked? What changed?"
  → More verification might be required
*/

// =========================================================================
// EXAMPLE 4: CREDENTIAL DOESN'T EXIST
// =========================================================================

/*
Lender calls: verifyCredential(0x9999...)
This credential ID was never issued

Credential lookup:
  credentials[0x9999...] = returns empty struct

Current time: any time

1. Lender calls: verifyCredential(0x9999...)

2. Contract reads: credentials[0x9999...]
   Result: Empty Credential struct (all zeros)

3. CHECK 1: Does credential exist?
   cred.id == bytes32(0)?
   YES! It's still zero ✓
   ↓
   Return: CredentialStatus.NOT_FOUND ❌

4. Lender receives: NOT_FOUND
   Lender says: "This credential ID doesn't exist"
   Lender rejects: "Credential not found on blockchain"

Possible reasons:
  1. Borrower typo'd the ID
  2. Credential was issued on different blockchain
  3. Borrower doesn't actually have a credential
  4. Credential was deleted (shouldn't happen, but checking)

RESULT:
  ❌ Loan not approved
  ❌ No proof of creditworthiness found
  → Borrower says: "Let me check with my bank..."
  → Borrower realizes they never got a credential issued
  → Borrower must apply for credential first
*/

// =========================================================================
// DECISION TREE: HOW LENDERS USE VERIFICATION
// =========================================================================

/*
Lender receives credential ID from borrower

         ↓
    verifyCredential(ID)
         ↓
    ┌────────────────────────────────────────┐
    │ What status returned?                  │
    └────────────────────────────────────────┘
         ↓
    ┌────────────────────────────────────────┐
    │ ├─ VALID                               │ ✅ APPROVE LOAN
    │ │                                      │    Check other criteria too
    │ │                                      │    (debt ratio, employment, etc)
    │ │                                      │
    │ ├─ EXPIRED                             │ ⏰ ASK BORROWER TO RENEW
    │ │                                      │    "Get fresh credential from bank"
    │ │                                      │    "Resubmit and reapply"
    │ │                                      │
    │ ├─ REVOKED                             │ 🚫 REJECT LOAN
    │ │                                      │    "Credential was cancelled"
    │ │                                      │    "Cannot approve with revoked ID"
    │ │                                      │
    │ └─ NOT_FOUND                           │ ❌ REJECT LOAN
    │                                        │    "Credential doesn't exist"
    │                                        │    "No record on blockchain"
    └────────────────────────────────────────┘
*/

// =========================================================================
// WHY VERIFICATION MATTERS
// =========================================================================

/*
1. AUTHENTICATION
   Proves credential actually exists on blockchain
   Prevents borrower from lying about credentials

   "You can't claim you have an income credential if it's not there"

2. RECENCY
   Ensures credential is recent (not expired)
   Income from 3 years ago doesn't prove current income

   "Your 2021 income verification isn't valid in 2024"

3. VALIDITY
   Ensures credential hasn't been cancelled
   If borrower revoked it, situation probably changed

   "If borrower revoked it, maybe they know it's no longer accurate"

4. IMMUTABILITY
   Credential data on blockchain cannot be forged
   Can't modify old credential to look better

   "Once issued, data is locked in - can't be changed"

5. TRANSPARENCY
   Both borrower and lender can verify
   Third parties can audit
   Smart contract enforces rules, not humans

   "Anyone can call verifyCredential() and get same answer"
*/

// =========================================================================
// GAS COSTS
// =========================================================================

/*
verifyCredential() is a "view" function
  - Doesn't modify blockchain state
  - Costs ZERO gas when called by users
  - Costs NO transaction fees

Why free?
  - Just reading existing data
  - No writes to blockchain
  - Miners don't need to process it

When called from another contract:
  - Costs ~3,000 to 5,000 gas (minimal)
  - Much cheaper than state-modifying functions

This makes verification:
  ✓ Cheap for lenders
  ✓ Instantaneous (no mining delay)
  ✓ Can be called unlimited times
  ✓ Suitable for real-time approval systems
*/

