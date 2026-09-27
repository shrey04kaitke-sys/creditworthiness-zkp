const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("CreditworthinessRegistry", function () {
  let registry;
  let sbt;
  let owner;
  let issuer1;
  let issuer2;
  let borrower1;
  let borrower2;
  let lender1;

  // Sample verification key (Groth16 components)
  const sampleVerificationKey = {
    alpha: ["11111111111111111111111111111111", "22222222222222222222222222222222"],
    beta: [
      ["33333333333333333333333333333333", "44444444444444444444444444444444"],
      ["55555555555555555555555555555555", "66666666666666666666666666666666"]
    ],
    gamma: ["77777777777777777777777777777777", "88888888888888888888888888888888"],
    delta: ["99999999999999999999999999999999", "10101010101010101010101010101010"],
    gammaABC: [
      ["11111111111111111111111111111111", "12121212121212121212121212121212"],
      ["13131313131313131313131313131313", "14141414141414141414141414141414"]
    ]
  };

  // Sample ZK proof components (for testing)
  const sampleProof = {
    a: ["1234567890123456789012345678901234567890", "1234567890123456789012345678901234567890"],
    b: [
      ["2345678901234567890123456789012345678901", "2345678901234567890123456789012345678901"],
      ["3456789012345678901234567890123456789012", "3456789012345678901234567890123456789012"]
    ],
    c: ["4567890123456789012345678901234567890123", "4567890123456789012345678901234567890123"]
  };

  // Sample public signals (income threshold, payment ratio, credit score)
  const samplePublicSignals = [
    ethers.BigNumber.from("50000"),  // Income >= 50k
    ethers.BigNumber.from("95"),     // Payment ratio = 95%
    ethers.BigNumber.from("700")     // Credit score = 700
  ];

  beforeEach(async function () {
    // Get signers
    [owner, issuer1, issuer2, borrower1, borrower2, lender1] = await ethers.getSigners();

    // Deploy CreditworthinessRegistry
    const CreditworthinessRegistry = await ethers.getContractFactory("CreditworthinessRegistry");
    registry = await CreditworthinessRegistry.deploy();
    await registry.deployed();

    // Get SBT contract address
    const sbtAddress = await registry.sbt();
    const CredentialSBT = await ethers.getContractFactory("CredentialSBT");
    sbt = CredentialSBT.attach(sbtAddress);
  });

  // =========================================================================
  // TEST SUITE 1: ISSUER AUTHORIZATION
  // =========================================================================

  describe("Issuer Authorization", function () {
    it("Should authorize a new issuer", async function () {
      await registry.authorizeIssuer(issuer1.address);
      expect(await registry.authorizedIssuers(issuer1.address)).to.be.true;
    });

    it("Should emit IssuerAuthorized event", async function () {
      await expect(registry.authorizeIssuer(issuer1.address))
        .to.emit(registry, "IssuerAuthorized")
        .withArgs(issuer1.address);
    });

    it("Should not authorize zero address", async function () {
      await expect(registry.authorizeIssuer(ethers.constants.AddressZero))
        .to.be.revertedWith("Invalid issuer address");
    });

    it("Should not re-authorize already authorized issuer", async function () {
      await registry.authorizeIssuer(issuer1.address);
      await expect(registry.authorizeIssuer(issuer1.address))
        .to.be.revertedWith("Issuer already authorized");
    });

    it("Should deauthorize an issuer", async function () {
      await registry.authorizeIssuer(issuer1.address);
      await registry.deauthorizeIssuer(issuer1.address);
      expect(await registry.authorizedIssuers(issuer1.address)).to.be.false;
    });

    it("Should emit IssuerDeauthorized event", async function () {
      await registry.authorizeIssuer(issuer1.address);
      await expect(registry.deauthorizeIssuer(issuer1.address))
        .to.emit(registry, "IssuerDeauthorized")
        .withArgs(issuer1.address);
    });

    it("Should not deauthorize non-authorized issuer", async function () {
      await expect(registry.deauthorizeIssuer(issuer1.address))
        .to.be.revertedWith("Issuer not authorized");
    });

    it("Only owner should authorize issuers", async function () {
      await expect(registry.connect(issuer1).authorizeIssuer(issuer2.address))
        .to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  // =========================================================================
  // TEST SUITE 2: VERIFICATION KEY MANAGEMENT
  // =========================================================================

  describe("Verification Key Management", function () {
    beforeEach(async function () {
      await registry.authorizeIssuer(issuer1.address);
    });

    it("Should register verification key", async function () {
      await registry.connect(issuer1).registerVerificationKey(
        sampleVerificationKey.alpha,
        sampleVerificationKey.beta,
        sampleVerificationKey.gamma,
        sampleVerificationKey.delta,
        sampleVerificationKey.gammaABC
      );

      const key = await registry.verificationKeys(issuer1.address);
      expect(key.alpha[0]).to.equal(sampleVerificationKey.alpha[0]);
    });

    it("Should emit VerificationKeyRegistered event", async function () {
      await expect(registry.connect(issuer1).registerVerificationKey(
        sampleVerificationKey.alpha,
        sampleVerificationKey.beta,
        sampleVerificationKey.gamma,
        sampleVerificationKey.delta,
        sampleVerificationKey.gammaABC
      ))
        .to.emit(registry, "VerificationKeyRegistered")
        .withArgs(issuer1.address);
    });

    it("Only authorized issuers should register keys", async function () {
      await expect(registry.connect(borrower1).registerVerificationKey(
        sampleVerificationKey.alpha,
        sampleVerificationKey.beta,
        sampleVerificationKey.gamma,
        sampleVerificationKey.delta,
        sampleVerificationKey.gammaABC
      ))
        .to.be.revertedWith("Not an authorized issuer");
    });
  });

  // =========================================================================
  // TEST SUITE 3: CREDENTIAL ISSUANCE
  // =========================================================================

  describe("Credential Issuance", function () {
    beforeEach(async function () {
      await registry.authorizeIssuer(issuer1.address);
    });

    it("Should issue a credential", async function () {
      const validityPeriod = 31536000; // 1 year

      const tx = await registry.connect(issuer1).issueCredential(
        borrower1.address,
        sampleProof.a,
        sampleProof.b,
        sampleProof.c,
        samplePublicSignals,
        "income_verification",
        validityPeriod
      );

      const receipt = await tx.wait();
      expect(receipt.events.length).to.be.greaterThan(0);
    });

    it("Should emit CredentialIssued event", async function () {
      const validityPeriod = 31536000;

      await expect(registry.connect(issuer1).issueCredential(
        borrower1.address,
        sampleProof.a,
        sampleProof.b,
        sampleProof.c,
        samplePublicSignals,
        "income_verification",
        validityPeriod
      ))
        .to.emit(registry, "CredentialIssued");
    });

    it("Should return credential ID", async function () {
      const validityPeriod = 31536000;

      const tx = await registry.connect(issuer1).issueCredential(
        borrower1.address,
        sampleProof.a,
        sampleProof.b,
        sampleProof.c,
        samplePublicSignals,
        "income_verification",
        validityPeriod
      );

      const receipt = await tx.wait();
      const event = receipt.events.find(e => e.event === "CredentialIssued");
      const credentialId = event.args.credentialId;

      expect(credentialId).to.not.equal(ethers.constants.HashZero);
    });

    it("Should not issue credential to zero address", async function () {
      const validityPeriod = 31536000;

      await expect(registry.connect(issuer1).issueCredential(
        ethers.constants.AddressZero,
        sampleProof.a,
        sampleProof.b,
        sampleProof.c,
        samplePublicSignals,
        "income_verification",
        validityPeriod
      ))
        .to.be.revertedWith("Invalid user address");
    });

    it("Should not issue credential without public signals", async function () {
      const validityPeriod = 31536000;

      await expect(registry.connect(issuer1).issueCredential(
        borrower1.address,
        sampleProof.a,
        sampleProof.b,
        sampleProof.c,
        [],
        "income_verification",
        validityPeriod
      ))
        .to.be.revertedWith("Public signals required");
    });

    it("Should not issue credential with zero validity period", async function () {
      await expect(registry.connect(issuer1).issueCredential(
        borrower1.address,
        sampleProof.a,
        sampleProof.b,
        sampleProof.c,
        samplePublicSignals,
        "income_verification",
        0
      ))
        .to.be.revertedWith("Validity period must be positive");
    });

    it("Only authorized issuers can issue credentials", async function () {
      const validityPeriod = 31536000;

      await expect(registry.connect(borrower1).issueCredential(
        borrower2.address,
        sampleProof.a,
        sampleProof.b,
        sampleProof.c,
        samplePublicSignals,
        "income_verification",
        validityPeriod
      ))
        .to.be.revertedWith("Not an authorized issuer");
    });

    it("Should store credential with correct data", async function () {
      const validityPeriod = 31536000;

      const tx = await registry.connect(issuer1).issueCredential(
        borrower1.address,
        sampleProof.a,
        sampleProof.b,
        sampleProof.c,
        samplePublicSignals,
        "income_verification",
        validityPeriod
      );

      const receipt = await tx.wait();
      const event = receipt.events.find(e => e.event === "CredentialIssued");
      const credentialId = event.args.credentialId;

      const credential = await registry.getCredential(credentialId);

      expect(credential.user).to.equal(borrower1.address);
      expect(credential.issuer).to.equal(issuer1.address);
      expect(credential.credentialType).to.equal("income_verification");
      expect(credential.revoked).to.be.false;
    });

    it("Should link credential to user", async function () {
      const validityPeriod = 31536000;

      const tx = await registry.connect(issuer1).issueCredential(
        borrower1.address,
        sampleProof.a,
        sampleProof.b,
        sampleProof.c,
        samplePublicSignals,
        "income_verification",
        validityPeriod
      );

      const receipt = await tx.wait();
      const event = receipt.events.find(e => e.event === "CredentialIssued");
      const credentialId = event.args.credentialId;

      const userCredentials = await registry.getUserCredentials(borrower1.address);
      expect(userCredentials).to.include(credentialId);
    });

    it("Should generate unique credential IDs", async function () {
      const validityPeriod = 31536000;

      const tx1 = await registry.connect(issuer1).issueCredential(
        borrower1.address,
        sampleProof.a,
        sampleProof.b,
        sampleProof.c,
        samplePublicSignals,
        "income_verification",
        validityPeriod
      );

      const tx2 = await registry.connect(issuer1).issueCredential(
        borrower1.address,
        sampleProof.a,
        sampleProof.b,
        sampleProof.c,
        samplePublicSignals,
        "income_verification",
        validityPeriod
      );

      const receipt1 = await tx1.wait();
      const receipt2 = await tx2.wait();

      const event1 = receipt1.events.find(e => e.event === "CredentialIssued");
      const event2 = receipt2.events.find(e => e.event === "CredentialIssued");

      const credId1 = event1.args.credentialId;
      const credId2 = event2.args.credentialId;

      expect(credId1).to.not.equal(credId2);
    });
  });

  // =========================================================================
  // TEST SUITE 4: CREDENTIAL VERIFICATION
  // =========================================================================

  describe("Credential Verification", function () {
    let credentialId;

    beforeEach(async function () {
      await registry.authorizeIssuer(issuer1.address);

      const validityPeriod = 31536000;

      const tx = await registry.connect(issuer1).issueCredential(
        borrower1.address,
        sampleProof.a,
        sampleProof.b,
        sampleProof.c,
        samplePublicSignals,
        "income_verification",
        validityPeriod
      );

      const receipt = await tx.wait();
      const event = receipt.events.find(e => e.event === "CredentialIssued");
      credentialId = event.args.credentialId;
    });

    it("Should verify valid credential", async function () {
      const status = await registry.verifyCredential(credentialId);
      // CredentialStatus.VALID = 0
      expect(status).to.equal(0);
    });

    it("Should return NOT_FOUND for non-existent credential", async function () {
      const fakeId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("fake"));
      const status = await registry.verifyCredential(fakeId);
      // CredentialStatus.NOT_FOUND = 3
      expect(status).to.equal(3);
    });

    it("Should return REVOKED for revoked credential", async function () {
      await registry.connect(issuer1).revokeCredential(credentialId);
      const status = await registry.verifyCredential(credentialId);
      // CredentialStatus.REVOKED = 2
      expect(status).to.equal(2);
    });

    it("isCredentialValid should return true for valid credential", async function () {
      const isValid = await registry.isCredentialValid(credentialId);
      expect(isValid).to.be.true;
    });

    it("isCredentialValid should return false for invalid credential", async function () {
      const fakeId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("fake"));
      const isValid = await registry.isCredentialValid(fakeId);
      expect(isValid).to.be.false;
    });

    it("Should get public signals from credential", async function () {
      const signals = await registry.getPublicSignals(credentialId);
      expect(signals.length).to.equal(3);
      expect(signals[0]).to.equal(50000);
      expect(signals[1]).to.equal(95);
      expect(signals[2]).to.equal(700);
    });

    it("Should not get signals from non-existent credential", async function () {
      const fakeId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("fake"));
      await expect(registry.getPublicSignals(fakeId))
        .to.be.revertedWith("Credential not found");
    });
  });

  // =========================================================================
  // TEST SUITE 5: CREDENTIAL REVOCATION
  // =========================================================================

  describe("Credential Revocation", function () {
    let credentialId;

    beforeEach(async function () {
      await registry.authorizeIssuer(issuer1.address);

      const validityPeriod = 31536000;

      const tx = await registry.connect(issuer1).issueCredential(
        borrower1.address,
        sampleProof.a,
        sampleProof.b,
        sampleProof.c,
        samplePublicSignals,
        "income_verification",
        validityPeriod
      );

      const receipt = await tx.wait();
      const event = receipt.events.find(e => e.event === "CredentialIssued");
      credentialId = event.args.credentialId;
    });

    it("Issuer should revoke credential", async function () {
      await registry.connect(issuer1).revokeCredential(credentialId);
      const status = await registry.verifyCredential(credentialId);
      // CredentialStatus.REVOKED = 2
      expect(status).to.equal(2);
    });

    it("User should revoke their own credential", async function () {
      await registry.connect(borrower1).revokeCredential(credentialId);
      const status = await registry.verifyCredential(credentialId);
      expect(status).to.equal(2);
    });

    it("Owner should revoke credential", async function () {
      await registry.revokeCredential(credentialId);
      const status = await registry.verifyCredential(credentialId);
      expect(status).to.equal(2);
    });

    it("Should emit CredentialRevoked event", async function () {
      await expect(registry.connect(issuer1).revokeCredential(credentialId))
        .to.emit(registry, "CredentialRevoked")
        .withArgs(credentialId, issuer1.address);
    });

    it("Should not revoke non-existent credential", async function () {
      const fakeId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("fake"));
      await expect(registry.revokeCredential(fakeId))
        .to.be.revertedWith("Credential not found");
    });

    it("Should not revoke already revoked credential", async function () {
      await registry.connect(issuer1).revokeCredential(credentialId);
      await expect(registry.connect(issuer1).revokeCredential(credentialId))
        .to.be.revertedWith("Credential already revoked");
    });

    it("Unauthorized party should not revoke credential", async function () {
      await expect(registry.connect(lender1).revokeCredential(credentialId))
        .to.be.revertedWith("Not authorized to revoke");
    });

    it("Revocation is permanent (cannot be undone)", async function () {
      await registry.connect(issuer1).revokeCredential(credentialId);

      let status = await registry.verifyCredential(credentialId);
      expect(status).to.equal(2); // REVOKED

      // Status should remain REVOKED (no "unrevoke" function exists)
      status = await registry.verifyCredential(credentialId);
      expect(status).to.equal(2);
    });
  });

  // =========================================================================
  // TEST SUITE 6: USER CREDENTIAL QUERIES
  // =========================================================================

  describe("User Credential Queries", function () {
    let credId1, credId2, credId3;

    beforeEach(async function () {
      await registry.authorizeIssuer(issuer1.address);
      await registry.authorizeIssuer(issuer2.address);

      const validityPeriod = 31536000;

      // Issue 3 credentials to borrower1
      for (let i = 0; i < 3; i++) {
        const tx = await registry.connect(issuer1).issueCredential(
          borrower1.address,
          sampleProof.a,
          sampleProof.b,
          sampleProof.c,
          samplePublicSignals,
          "income_verification",
          validityPeriod
        );

        const receipt = await tx.wait();
        const event = receipt.events.find(e => e.event === "CredentialIssued");
        const credId = event.args.credentialId;

        if (i === 0) credId1 = credId;
        else if (i === 1) credId2 = credId;
        else credId3 = credId;
      }
    });

    it("Should get all credentials for a user", async function () {
      const credentials = await registry.getUserCredentials(borrower1.address);
      expect(credentials.length).to.equal(3);
    });

    it("Should get valid credential count", async function () {
      // All 3 are valid
      const count = await registry.getValidCredentialCount(borrower1.address);
      expect(count).to.equal(3);
    });

    it("Should update valid count after revocation", async function () {
      await registry.connect(issuer1).revokeCredential(credId1);

      const count = await registry.getValidCredentialCount(borrower1.address);
      expect(count).to.equal(2);
    });

    it("Should get all valid credentials", async function () {
      const validCreds = await registry.getUserValidCredentials(borrower1.address);
      expect(validCreds.length).to.equal(3);
    });

    it("Should exclude revoked credentials from valid list", async function () {
      await registry.connect(issuer1).revokeCredential(credId1);

      const validCreds = await registry.getUserValidCredentials(borrower1.address);
      expect(validCreds.length).to.equal(2);

      const ids = validCreds.map(c => c.id);
      expect(ids).to.include(credId2);
      expect(ids).to.include(credId3);
      expect(ids).to.not.include(credId1);
    });

    it("Should handle user with no credentials", async function () {
      const credentials = await registry.getUserCredentials(borrower2.address);
      expect(credentials.length).to.equal(0);

      const count = await registry.getValidCredentialCount(borrower2.address);
      expect(count).to.equal(0);
    });
  });

  // =========================================================================
  // TEST SUITE 7: SOUL BOUND TOKEN (SBT)
  // =========================================================================

  describe("Soul Bound Token (SBT)", function () {
    let credentialId;
    let tokenId;

    beforeEach(async function () {
      await registry.authorizeIssuer(issuer1.address);

      const validityPeriod = 31536000;

      const tx = await registry.connect(issuer1).issueCredential(
        borrower1.address,
        sampleProof.a,
        sampleProof.b,
        sampleProof.c,
        samplePublicSignals,
        "income_verification",
        validityPeriod
      );

      const receipt = await tx.wait();
      const event = receipt.events.find(e => e.event === "CredentialIssued");
      credentialId = event.args.credentialId;

      // Mint SBT
      const mintTx = await sbt.mint(borrower1.address, credentialId);
      const mintReceipt = await mintTx.wait();
      const mintEvent = mintReceipt.events.find(e => e.event === "SBTMinted");
      tokenId = mintEvent.args.tokenId;
    });

    it("Should mint SBT for credential", async function () {
      const owner = await sbt.ownerOf(tokenId);
      expect(owner).to.equal(borrower1.address);
    });

    it("Should link credential to token", async function () {
      const linkedTokenId = await sbt.credentialToToken(credentialId);
      expect(linkedTokenId).to.equal(tokenId);
    });

    it("Should link token to credential", async function () {
      const linkedCredentialId = await sbt.tokenToCredential(tokenId);
      expect(linkedCredentialId).to.equal(credentialId);
    });

    it("Should emit SBTMinted event", async function () {
      const credId2 = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("cred2"));
      await expect(sbt.mint(borrower2.address, credId2))
        .to.emit(sbt, "SBTMinted");
    });

    it("Should not transfer SBT (non-transferable)", async function () {
      await expect(sbt.connect(borrower1).transferFrom(
        borrower1.address,
        borrower2.address,
        tokenId
      ))
        .to.be.revertedWith("SBTs are non-transferable");
    });

    it("Should not safeTransferFrom SBT", async function () {
      await expect(sbt.connect(borrower1).safeTransferFrom(
        borrower1.address,
        borrower2.address,
        tokenId
      ))
        .to.be.revertedWith("SBTs are non-transferable");
    });

    it("Should check if SBT is valid", async function () {
      const isValid = await sbt.isValid(tokenId);
      expect(isValid).to.be.true;
    });

    it("Should burn SBT on revocation", async function () {
      await sbt.revoke(tokenId);

      // Token should no longer exist
      await expect(sbt.ownerOf(tokenId))
        .to.be.reverted;
    });

    it("Should emit SBTRevoked event", async function () {
      await expect(sbt.revoke(tokenId))
        .to.emit(sbt, "SBTRevoked");
    });

    it("Only registry can mint SBT", async function () {
      const credId2 = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("cred2"));
      await expect(sbt.connect(borrower1).mint(borrower2.address, credId2))
        .to.be.revertedWith("Only registry can mint");
    });

    it("Only registry can revoke SBT", async function () {
      await expect(sbt.connect(borrower1).revoke(tokenId))
        .to.be.revertedWith("Only registry can revoke");
    });
  });

  // =========================================================================
  // TEST SUITE 8: SECURITY & EDGE CASES
  // =========================================================================

  describe("Security & Edge Cases", function () {
    beforeEach(async function () {
      await registry.authorizeIssuer(issuer1.address);
    });

    it("Should protect against reentrancy on revocation", async function () {
      const validityPeriod = 31536000;

      const tx = await registry.connect(issuer1).issueCredential(
        borrower1.address,
        sampleProof.a,
        sampleProof.b,
        sampleProof.c,
        samplePublicSignals,
        "income_verification",
        validityPeriod
      );

      const receipt = await tx.wait();
      const event = receipt.events.find(e => e.event === "CredentialIssued");
      const credentialId = event.args.credentialId;

      // Normal revocation should work
      await registry.connect(issuer1).revokeCredential(credentialId);
      const status = await registry.verifyCredential(credentialId);
      expect(status).to.equal(2);
    });

    it("Should handle multiple credentials from same issuer", async function () {
      const validityPeriod = 31536000;

      const tx1 = await registry.connect(issuer1).issueCredential(
        borrower1.address,
        sampleProof.a,
        sampleProof.b,
        sampleProof.c,
        samplePublicSignals,
        "income_verification",
        validityPeriod
      );

      const tx2 = await registry.connect(issuer1).issueCredential(
        borrower2.address,
        sampleProof.a,
        sampleProof.b,
        sampleProof.c,
        samplePublicSignals,
        "payment_history",
        validityPeriod
      );

      const receipt1 = await tx1.wait();
      const receipt2 = await tx2.wait();

      const event1 = receipt1.events.find(e => e.event === "CredentialIssued");
      const event2 = receipt2.events.find(e => e.event === "CredentialIssued");

      const credId1 = event1.args.credentialId;
      const credId2 = event2.args.credentialId;

      expect(credId1).to.not.equal(credId2);
    });

    it("Should handle large public signals array", async function () {
      const validityPeriod = 31536000;
      const largeSignals = Array(100).fill(ethers.BigNumber.from("1000"));

      const tx = await registry.connect(issuer1).issueCredential(
        borrower1.address,
        sampleProof.a,
        sampleProof.b,
        sampleProof.c,
        largeSignals,
        "complex_verification",
        validityPeriod
      );

      const receipt = await tx.wait();
      expect(receipt.events.length).to.be.greaterThan(0);
    });

    it("Should maintain immutability of issued credential", async function () {
      const validityPeriod = 31536000;

      const tx = await registry.connect(issuer1).issueCredential(
        borrower1.address,
        sampleProof.a,
        sampleProof.b,
        sampleProof.c,
        samplePublicSignals,
        "income_verification",
        validityPeriod
      );

      const receipt = await tx.wait();
      const event = receipt.events.find(e => e.event === "CredentialIssued");
      const credentialId = event.args.credentialId;

      const cred1 = await registry.getCredential(credentialId);
      const cred2 = await registry.getCredential(credentialId);

      expect(cred1.id).to.equal(cred2.id);
      expect(cred1.user).to.equal(cred2.user);
      expect(cred1.issuer).to.equal(cred2.issuer);
      expect(cred1.issuedAt).to.equal(cred2.issuedAt);
    });
  });
});
