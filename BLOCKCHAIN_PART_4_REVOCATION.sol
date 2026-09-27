// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * BLOCKCHAIN PART 4: CREDENTIAL REVOCATION & SOUL BOUND TOKEN
 * This part explains HOW credentials can be revoked + non-transferable tokens
 */

// =========================================================================
// PART 4A: THE revokeCredential() FUNCTION
// =========================================================================
// This is where credentials get cancelled
// Location in CreditworthinessRegistry.sol: Lines 337-356

/*
FUNCTION SIGNATURE:
--------------------

function revokeCredential(bytes32 credentialId)
    external
    nonReentrant

What it does:
  - Marks credential as revoked (cancelled)
  - Only authorized parties can revoke
  - Revocation is PERMANENT (can't be undone)

Key word: nonReentrant
  Prevents re-entrancy attacks
  Ensures revocation completes atomically
*/

// =========================================================================
// WHO CAN REVOKE A CREDENTIAL?
// =========================================================================

/*
Lines 345-350 of CreditworthinessRegistry.sol

require(
    msg.sender == cred.issuer ||     // The bank that issued it
    msg.sender == cred.user ||       // The borrower themselves
    msg.sender == owner(),           // Contract owner
    "Not authorized to revoke"
);

Three parties can revoke:

1. ISSUER (The bank that issued the credential)
   Example: Bank A revokes a credential it issued
   Reason: "We discovered the borrower's income data was fraudulent"

   if (msg.sender == cred.issuer) → Can revoke ✓

2. USER (The credential holder/borrower)
   Example: Borrower revokes their own credential
   Reason: "My employment status changed, I don't want this valid anymore"

   if (msg.sender == cred.user) → Can revoke ✓

3. OWNER (Contract administrator)
   Example: Contract owner revokes after security audit
   Reason: "We found a bug in how credentials were issued"

   if (msg.sender == owner()) → Can revoke ✓

ANYONE ELSE:
   Lender, random third party, other borrower
   → Cannot revoke! ✗
   → Transaction reverts with: "Not authorized to revoke"

   This prevents:
   - Lender sabotaging borrower's credential
   - Competitors damaging each other
   - Random people cancelling credentials

PRINCIPLE: Principle of Least Privilege
  Each party can only revoke things they control
  Issuer controls credentials it created
  User controls their own credentials
  Owner controls system as last resort
*/

// =========================================================================
// REVOCATION CHECKS
// =========================================================================

/*
Before revoking, contract checks:

Line 341: require(cred.id != bytes32(0), "Credential not found");
  Ensures credential exists
  If trying to revoke non-existent credential → Revert

Line 342: require(!cred.revoked, "Credential already revoked");
  Ensures credential not already revoked
  Can't revoke twice
  If already revoked → Revert

Why this check?
  Prevents accidental re-revocation
  Revocation should be idempotent (same result)
  But contract prevents even attempting twice

Example:

First revocation:
  revokeCredential(0x4a5f...)
  ✓ cred.id != bytes32(0)? YES, credential exists
  ✓ !cred.revoked? YES, not yet revoked
  → Transaction succeeds
  → credentials[0x4a5f...].revoked = true

Second revocation (same ID):
  revokeCredential(0x4a5f...)
  ✓ cred.id != bytes32(0)? YES, still exists
  ✗ !cred.revoked? NO, already revoked!
  → Transaction reverts: "Credential already revoked"
*/

// =========================================================================
// THE REVOCATION ACTION
// =========================================================================

/*
Line 353 of CreditworthinessRegistry.sol

cred.revoked = true;

What it does:
  Sets the revoked flag to true
  That's it! Simple as that.

Effect:
  After this, credential is marked as revoked
  verifyCredential() will always return REVOKED
  Lenders will reject this credential

Before revocation:
  credentials[0x4a5f...] = {
    id: 0x4a5f...,
    user: 0x742d...,
    issuer: 0x8ba1...,
    ...
    revoked: false,  ← Currently active
    ...
  }

After revocation:
  credentials[0x4a5f...] = {
    id: 0x4a5f...,
    user: 0x742d...,
    issuer: 0x8ba1...,
    ...
    revoked: true,   ← Now marked as cancelled
    ...
  }

The credential data itself doesn't change:
  - ID stays same
  - Issue date stays same
  - Expiration date stays same
  - Public signals stay same

Only the "revoked" flag changes
  from false → true

IMPORTANT: Revocation is PERMANENT
  Once revoked, it stays revoked forever
  No function to "unrevoke" a credential
  Only way to get valid credential again:
    Issuer creates NEW credential with different ID
*/

// =========================================================================
// EMIT REVOCATION EVENT
// =========================================================================

/*
Line 355 of CreditworthinessRegistry.sol

emit CredentialRevoked(credentialId, msg.sender);

What it does:
  Logs the revocation to blockchain
  Anyone listening can see credential was revoked

Event definition (lines 95-98):
  event CredentialRevoked(
      bytes32 indexed credentialId,
      address indexed revokedBy
  );

Example event:

  Block: 17,000,500
  Transaction: 0xdef456...
  Event: CredentialRevoked
    credentialId: 0x4a5f...
    revokedBy: 0x742d... (borrower revoked it)

Anyone can see:
  - Which credential was revoked
  - Who revoked it (issuer, user, or owner)
  - When it was revoked (block number/timestamp)

Uses:
  - Lenders see revocation in real-time
  - Auditors track who revoked what
  - Applications log all credential changes
*/

// =========================================================================
// COMPLETE EXAMPLE: BORROWER REVOKES CREDENTIAL
// =========================================================================

/*
SCENARIO:
  Borrower B (0x742d) had stable income when credential issued
  Credential ID: 0x4a5f...

  But then:
  - Borrower lost their job
  - Got a lower-paying job
  - Knows credential no longer reflects reality

  Borrower decides: "I'll revoke this credential"

STEP-BY-STEP:

1. Borrower calls: revokeCredential(0x4a5f...)

2. Contract reads: credentials[0x4a5f...]
   Result:
   {
     id: 0x4a5f...,
     user: 0x742d... (Borrower),
     issuer: 0x8ba1...,
     ...
     revoked: false,
     ...
   }

3. Check 1: Does credential exist?
   cred.id != bytes32(0)?
   YES! Exists ✓

4. Check 2: Is it already revoked?
   !cred.revoked?
   YES! (revoked = false, so !revoked = true) ✓

5. Check 3: Who is calling?
   msg.sender == cred.issuer?  NO
   msg.sender == cred.user?    YES! ✓ (Borrower is user)
   → Authorization passes!

6. Revoke the credential:
   credentials[0x4a5f...].revoked = true

7. Emit event:
   CredentialRevoked(
     0x4a5f...,
     0x742d... (Borrower who revoked it)
   )

8. Transaction completes ✅

RESULT:
  ✅ Credential successfully revoked
  ✅ Event logged
  ✅ Borrower can't use this credential anymore

Later, if borrower tries to use it:
  Lender checks: verifyCredential(0x4a5f...)
  Check 2: Is revoked?
    YES! revoked = true
  ↓
  Return: CredentialStatus.REVOKED
  ↓
  Lender rejects loan

Lender might ask: "Why did you revoke it?"
Borrower explains: "My income changed, it's not accurate anymore"
Lender says: "Get a fresh credential from your new employer"
*/

// =========================================================================
// WHY BORROWERS REVOKE CREDENTIALS
// =========================================================================

/*
Scenario 1: EMPLOYMENT CHANGE
  Borrower: "I got a new job with different salary"
  Action: Revoke old income verification credential
  Reason: "Old credential might hurt my loan chances"

Scenario 2: CREDIT SCORE DROP
  Borrower: "My credit score fell due to missed payment"
  Action: Revoke credit score credential
  Reason: "I don't want lender knowing about the drop yet"

Scenario 3: FRAUD DISCOVERED
  Borrower: "I realized I provided fake documents to bank"
  Action: Revoke credential before bank finds out
  Reason: "Better to revoke than face fraud charges"

Scenario 4: PRIVACY CONCERNS
  Borrower: "I don't want this credential shared with others"
  Action: Revoke credential
  Reason: "Lender isn't the only one who might see it"

Scenario 5: CREDENTIALING AUTHORITY COMPROMISED
  Borrower: "My bank was hacked, credentials might be fake"
  Action: Revoke all credentials from that bank
  Reason: "Safer to revoke than use potentially fake data"
*/

// =========================================================================
// WHY ISSUERS REVOKE CREDENTIALS
// =========================================================================

/*
Scenario 1: FRAUD DETECTED
  Bank discovers: Borrower lied on income documents
  Bank action: Revoke credential
  Reason: "Credential is based on false information"

Scenario 2: ACCOUNT CLOSURE
  Borrower: Closes account with bank
  Bank action: Revoke all credentials issued to them
  Reason: "We no longer stand behind this customer"

Scenario 3: POLICY VIOLATION
  Bank discovers: Borrower violated lending agreement
  Bank action: Revoke credential
  Reason: "Relationship terminated, credential no longer valid"

Scenario 4: DATA INTEGRITY ISSUE
  Bank: Finds bug in how it verified borrower
  Bank action: Revoke affected credentials
  Reason: "Verification may have been incorrect"

Scenario 5: COMPLIANCE REQUIREMENT
  Regulator: "Revoke all income credentials issued before 2024"
  Bank action: Mass revoke (programmatically)
  Reason: "Compliance with new regulations"
*/

// =========================================================================
// WHY CONTRACT OWNER REVOKES CREDENTIALS
// =========================================================================

/*
Scenario 1: SECURITY BREACH
  Event: Smart contract was hacked
  Owner action: Revoke all credentials
  Reason: "Credentials may have been tampered with"

Scenario 2: SYSTEM UPGRADE
  Event: Found critical bug in credential logic
  Owner action: Revoke affected credentials
  Reason: "Pause system while fixing bug"

Scenario 3: EMERGENCY STOP
  Event: Unusual activity detected
  Owner action: Revoke suspicious credentials
  Reason: "Prevent fraud while investigating"

Scenario 4: MIGRATION
  Event: Moving to new smart contract version
  Owner action: Revoke old credentials before migration
  Reason: "Force users to re-credential on new system"
*/

// =========================================================================
// PART 4B: SOUL BOUND TOKEN (SBT)
// =========================================================================
// Non-transferable NFT representation of credentials
// Location in CreditworthinessRegistry.sol: Lines 431-517

/*
WHAT IS A SOUL BOUND TOKEN?

A Soul Bound Token (SBT) is:
  ✓ An NFT (non-fungible token) - unique digital asset
  ✓ Tied to one person (soul)
  ✓ Cannot be transferred (bound to that person)
  ✓ Cannot be sold or traded
  ✓ Stays with its owner forever

Example analogy:
  Regular NFT (like Bored Apes):
    Can buy, sell, trade freely
    "I'll sell my Ape for $100k"

  Soul Bound Token (like diploma):
    Cannot trade
    "Your diploma stays yours, can't be sold to someone else"
    "Diploma proves YOU graduated, not whoever has it"

Why SBTs matter for credentials:

  Problem without SBT:
    Credential could be transferred
    Borrower A issues credential
    Borrower A sells it to Borrower B
    Lender thinks B has A's income!
    → Fraud!

  Solution with SBT:
    Credential is bound to Borrower A only
    Borrower A cannot transfer it to B
    Even if A tries to transfer, contract blocks it
    → Fraud prevented!
*/

// =========================================================================
// THE CredentialSBT CONTRACT
// =========================================================================

/*
Contract: CredentialSBT (lines 431-517)
Extends: ERC721 (standard NFT contract)

Customizations:
  1. Override transferFrom() → Always reverts
  2. Override safeTransferFrom() (2 versions) → Always reverts
  3. Add mint() → Only registry can mint
  4. Add revoke() → Burn token when credential revoked
  5. Add isValid() → Check if token exists

Key mappings:

  credentialToToken[credentialId] = tokenId
    Example: 0x4a5f... → 42
    Maps credential ID to its NFT token ID

  tokenToCredential[tokenId] = credentialId
    Example: 42 → 0x4a5f...
    Maps token ID back to credential ID
*/

// =========================================================================
// PREVENTING TRANSFERS: THE TRANSFER BLOCK
// =========================================================================

/*
Lines 487-493 of CreditworthinessRegistry.sol

function transferFrom(
    address from,
    address to,
    uint256 tokenId
) public pure override {
    revert("SBTs are non-transferable");
}

What it does:
  Overrides ERC721's transferFrom() function
  Immediately reverts with error message
  ALWAYS reverts, no conditions

Why "pure"?
  "pure" = doesn't read state or modify state
  Since it always reverts, no need to access storage

Example attempt to transfer:

  Holder A (0x742d) owns token #42
  Holder A tries to sell to Holder B (0x1234)

  transferFrom(0x742d, 0x1234, 42)
  ↓
  Contract reads function
  ↓
  Immediately: revert("SBTs are non-transferable")
  ↓
  Transaction fails ❌

  Error message: "SBTs are non-transferable"

Same for safeTransferFrom (lines 498-516):
  Two versions of safeTransferFrom
  Both override ERC721's versions
  Both immediately revert

  Prevents:
  - transferFrom()
  - safeTransferFrom(from, to, tokenId)
  - safeTransferFrom(from, to, tokenId, data)

  All three blocked!

This triple-blocking ensures:
  No way to transfer token
  Even if someone knows Solidity
  Even if someone tries advanced transfer methods
  → Cannot transfer! ✓
*/

// =========================================================================
// MINTING SBT: CREATING THE TOKEN
// =========================================================================

/*
Lines 453-466 of CreditworthinessRegistry.sol

function mint(address to, bytes32 credentialId)
    external
    returns (uint256)
{
    require(msg.sender == registryAddress, "Only registry can mint");

    uint256 tokenId = tokenCounter;
    tokenCounter++;

    _safeMint(to, tokenId);

    credentialToToken[credentialId] = tokenId;
    tokenToCredential[tokenId] = credentialId;

    emit SBTMinted(tokenId, credentialId, to);
    return tokenId;
}

Process:

Step 1: Authorization check
  Only CreditworthinessRegistry can mint
  Prevents random people from minting SBTs

Step 2: Assign token ID
  tokenId = tokenCounter (starts at 0)
  First credential gets tokenId = 0
  Second credential gets tokenId = 1
  etc.

Step 3: Increment counter
  tokenCounter++
  Ensures next mint gets different ID

Step 4: Create NFT
  _safeMint(to, tokenId)
  Creates NFT and assigns to address "to"
  Uses safe transfer (checks if "to" is contract)

Step 5: Link credential to token
  credentialToToken[0x4a5f...] = 0
  tokenToCredential[0] = 0x4a5f...

  Bidirectional mapping
  Can look up token from credential
  Can look up credential from token

Step 6: Emit event
  SBTMinted(0, 0x4a5f..., 0x742d)
  Logs: Token 0 created for credential 0x4a5f...
        Given to holder 0x742d

Step 7: Return token ID
  return 0
  Registry gets back the token ID it created

Example:

Bank issues credential to Borrower:
  1. issueCredential() called
  2. Returns credentialId = 0x4a5f...
  3. Bank's app calls: sbt.mint(0x742d, 0x4a5f...)
  4. SBT contract mints token ID 0
  5. Token 0 is given to borrower 0x742d
  6. Borrower now owns SBT #0
  7. Function returns 0 (the token ID)

Borrower now has:
  ✓ Credential record on blockchain
  ✓ SBT #0 in their wallet
  ✓ Cannot transfer SBT #0 to anyone else
*/

// =========================================================================
// REVOKING SBT: BURNING THE TOKEN
// =========================================================================

/*
Lines 471-475 of CreditworthinessRegistry.sol

function revoke(uint256 tokenId) external {
    require(msg.sender == registryAddress, "Only registry can revoke");
    _burn(tokenId);
    emit SBTRevoked(tokenId, msg.sender);
}

What it does:
  Burns the SBT token (destroys it)
  Only registry can call

Process:

When credential is revoked:
  1. Registry calls: revokeCredential(credentialId)
  2. Credential marked as revoked
  3. Registry also calls: sbt.revoke(tokenId)
     (mapping gives tokenId from credentialId)
  4. SBT contract burns the token
  5. Token is destroyed and removed from blockchain

Example:

Credential 0x4a5f is revoked
  ↓
Registry also revokes SBT #0
  ↓
_burn(0) called
  ↓
Token #0 destroyed
  ↓
Borrower no longer owns token #0
  ↓
If borrower tries to transfer token #0:
  "This token doesn't exist"

Why burn the token?
  ✓ Makes revocation visible in wallet
  ✓ Borrower immediately sees token gone
  ✓ Clear indication credential was cancelled
  ✓ Prevents accidental use of revoked credential
*/

// =========================================================================
// CHECKING IF SBT IS VALID
// =========================================================================

/*
Lines 480-482 of CreditworthinessRegistry.sol

function isValid(uint256 tokenId) external view returns (bool) {
    return _exists(tokenId);
}

What it does:
  Checks if SBT token still exists
  Returns true if token exists, false if burnt

Uses:
  Applications can check: "Does borrower still have valid SBT?"
  Wallets can check: "Is this NFT still active?"
*/

// =========================================================================
// COMPLETE EXAMPLE: SBT LIFECYCLE
// =========================================================================

/*
STEP 1: CREDENTIAL ISSUED

Bank A issues credential to Borrower B
  issueCredential() called
  Returns: credentialId = 0x4a5f...

Token status: None yet

STEP 2: SBT MINTED

Registry mints SBT:
  sbt.mint(0x742d, 0x4a5f...)

  Creates: Token ID #0
  Owner: 0x742d (Borrower)
  Linked to: Credential 0x4a5f...

Token status: ✓ CREATED and owned by borrower

Storage:
  credentialToToken[0x4a5f...] = 0
  tokenToCredential[0] = 0x4a5f...

STEP 3: BORROWER USES CREDENTIAL

Borrower shows credential to Lender
  Lender verifies: verifyCredential(0x4a5f...)
  Result: VALID ✅
  Lender approves loan

Borrower can also check wallet:
  Borrower sees NFT #0 in their wallet
  Shows visual proof of credential

STEP 4: BORROWER TRIES TO TRANSFER

Borrower decides: "I'll sell this SBT to someone else"
Borrower calls: transferFrom(0x742d, 0x1234, 0)

Contract responds:
  revert("SBTs are non-transferable")
  ↓
  Transaction fails ❌

Borrower cannot sell the SBT

STEP 5: CREDENTIAL GETS REVOKED

Borrower's income changes
Borrower calls: revokeCredential(0x4a5f...)

Registry action:
  1. credentials[0x4a5f...].revoked = true
  2. sbt.revoke(0) (burn the token)
     → _burn(0)
     → Token #0 destroyed

Token status: ✗ BURNT and removed

STEP 6: CREDENTIAL VERIFICATION AFTER REVOCATION

Lender checks: verifyCredential(0x4a5f...)
Result: REVOKED ❌ (because revoked = true)

Lender rejects new loan

Borrower checks wallet:
  NFT #0 is gone!
  Visual confirmation: Credential revoked

For new credential:
  1. Borrower applies again to Bank A
  2. Bank A issues new credential
  3. New credentialId = 0x7b2e... (different)
  4. New SBT minted: Token ID #1
  5. Borrower gets NFT #1 in wallet
  6. Process repeats...
*/

// =========================================================================
// WHY SOUL BOUND TOKENS MATTER FOR CREDITWORTHINESS
// =========================================================================

/*
1. PREVENTS CREDENTIAL TRADING
   Without SBT:
     Credential could be sold
     "I'll buy your good credit score for $500"
     Fraud!

   With SBT:
     Credential tied to person
     Cannot be transferred
     Credential = proof of YOUR status only

2. MAKES REVOCATION VISIBLE
   Without SBT:
     Revocation only marked in contract state
     Borrower might not know
     Accidentally try to use revoked credential

   With SBT:
     Token disappears from wallet
     Clear visual indication
     Borrower immediately knows

3. ENABLES WALLET DISCOVERY
   Without SBT:
     Would need separate app to view credentials
     Check website, log in, view list

   With SBT:
     Open any Web3 wallet
     See all SBTs
     Immediate credential discovery

4. PROVIDES CRYPTOGRAPHIC PROOF
   Without SBT:
     Credential is in smart contract
     Borrower says: "I have a credential with ID 0x4a5f..."
     Could be lying

   With SBT:
     Token in wallet is cryptographic proof
     "Here's my wallet, you can see NFT #0"
     Proof verified by blockchain

5. INTEROPERABILITY
   Without SBT:
     Credential only works with this system
     Other lenders can't see it

   With SBT:
     Any Web3 app can check wallet
     Any lender can see SBT
     Credential works across platforms
*/

// =========================================================================
// SECURITY CONSIDERATIONS FOR REVOCATION & SBT
// =========================================================================

/*
1. REVOCATION PERMANENCE
   ✓ Once revoked, cannot be unrevoked
   ✓ Only way forward: get new credential with new ID
   ✓ Prevents accidental unrevocation

2. AUTHORIZATION CHECKS
   ✓ Only issuer, user, or owner can revoke
   ✓ Prevents malicious revocation by third parties
   ✓ Protects credentials from sabotage

3. SBT NON-TRANSFERABILITY
   ✓ Cannot transfer (blocked on all 3 methods)
   ✓ Cannot be sold or traded
   ✓ Tied to original holder permanently

4. REENTRANCY PROTECTION
   ✓ nonReentrant guard on revoke()
   ✓ Prevents exploits during revocation

5. REGISTRY-ONLY MINTING
   ✓ Only registry can mint SBT
   ✓ Prevents unauthorized token creation
   ✓ Ensures SBT linked to credential
*/

// =========================================================================
// SUMMARY: PART 4
// =========================================================================

/*
REVOCATION:
  - Permanent way to cancel credential
  - Can be done by: issuer, user, or owner
  - Sets revoked = true (changes single flag)
  - Verification will return REVOKED
  - Cannot be undone (new credential needed)

SOUL BOUND TOKEN:
  - Non-transferable NFT for each credential
  - Tied to one person forever
  - Cannot be sold or traded
  - Transfers blocked on all transfer methods
  - Burnt when credential is revoked
  - Provides wallet-level proof of credential

TOGETHER:
  - Credentials cannot be fraudulently transferred
  - Revocation is immediately visible to holder
  - System prevents credential trading
  - Maintains integrity of creditworthiness proof
*/

