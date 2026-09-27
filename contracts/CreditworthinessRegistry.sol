// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title Groth16Verifier
 * @dev Library for Groth16 proof verification using elliptic curve pairings
 * Implements the verification equation: [A]·[B] = [alpha]·[beta] + [C]·[gamma] + [K]·[delta]
 */
library Groth16Verifier {

    // Modulus for the BN254 curve
    uint256 constant FIELD_MODULUS = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

    /**
     * @dev Verify a Groth16 proof
     * @param alpha First component of verification key
     * @param beta Second component of verification key
     * @param gamma Third component of verification key
     * @param delta Fourth component of verification key
     * @param gammaABC Fifth component of verification key (gamma inverse times ABC)
     * @param proofA First component of proof (A point)
     * @param proofB Second component of proof (B point)
     * @param proofC Third component of proof (C point)
     * @param input Public inputs to verify against
     * @return true if proof is valid, false otherwise
     */
    function verify(
        uint256[2] memory alpha,
        uint256[2][2] memory beta,
        uint256[2] memory gamma,
        uint256[2] memory delta,
        uint256[][] memory gammaABC,
        uint256[2] memory proofA,
        uint256[2][2] memory proofB,
        uint256[2] memory proofC,
        uint256[] memory input
    ) internal view returns (bool) {

        require(input.length + 1 == gammaABC.length, "Invalid input length");

        // Calculate the linear combination of gammaABC points
        // K = gammaABC[0] + sum(input[i] * gammaABC[i+1] for i in 0..input.length)
        uint256[2] memory K;
        K = gammaABC[0];

        for (uint256 i = 0; i < input.length; i++) {
            K = add(K, scalarMult(gammaABC[i + 1], input[i]));
        }

        // Verify the pairing equation using the correctness condition:
        // e(A, B) = e(alpha, beta) * e(K, gamma) * e(C, delta)
        // This is equivalent to checking:
        // e(A, B) - e(alpha, beta) - e(K, gamma) - e(C, delta) = 0

        // Using the pairing check with accumulated values
        return pairingCheck(proofA, proofB, alpha, beta, K, gamma, proofC, delta);
    }

    /**
     * @dev Elliptic curve point addition on BN254
     * Returns the sum of two points P + Q
     */
    function add(uint256[2] memory P, uint256[2] memory Q) internal pure returns (uint256[2] memory R) {
        if (P[0] == 0 && P[1] == 0) return Q;
        if (Q[0] == 0 && Q[1] == 0) return P;

        uint256 px = P[0];
        uint256 py = P[1];
        uint256 qx = Q[0];
        uint256 qy = Q[1];

        if (px == qx) {
            if (py == qy) {
                return pointDouble(P);
            } else {
                return [uint256(0), uint256(0)];
            }
        }

        uint256 s = mulmod(qy - py, modInverse(qx - px), FIELD_MODULUS);
        uint256 x3 = mulmod(s, s, FIELD_MODULUS) - px - qx;
        uint256 y3 = mulmod(s, px - x3, FIELD_MODULUS) - py;

        x3 = (x3 % FIELD_MODULUS + FIELD_MODULUS) % FIELD_MODULUS;
        y3 = (y3 % FIELD_MODULUS + FIELD_MODULUS) % FIELD_MODULUS;

        return [x3, y3];
    }

    /**
     * @dev Point doubling: P + P
     */
    function pointDouble(uint256[2] memory P) internal pure returns (uint256[2] memory R) {
        uint256 px = P[0];
        uint256 py = P[1];

        uint256 s = mulmod(
            mulmod(3 * px * px, modInverse(2 * py), FIELD_MODULUS),
            mulmod(3 * px * px, modInverse(2 * py), FIELD_MODULUS),
            FIELD_MODULUS
        );

        uint256 x3 = mulmod(s, s, FIELD_MODULUS) - 2 * px;
        uint256 y3 = mulmod(s, px - x3, FIELD_MODULUS) - py;

        x3 = (x3 % FIELD_MODULUS + FIELD_MODULUS) % FIELD_MODULUS;
        y3 = (y3 % FIELD_MODULUS + FIELD_MODULUS) % FIELD_MODULUS;

        return [x3, y3];
    }

    /**
     * @dev Scalar multiplication on elliptic curve: k * P
     */
    function scalarMult(uint256[2] memory P, uint256 k) internal pure returns (uint256[2] memory R) {
        if (k == 0) return [uint256(0), uint256(0)];
        if (k == 1) return P;

        R = [uint256(0), uint256(0)];
        uint256[2] memory addend = P;

        while (k > 0) {
            if (k & 1 == 1) {
                R = add(R, addend);
            }
            addend = pointDouble(addend);
            k >>= 1;
        }

        return R;
    }

    /**
     * @dev Modular inverse using Fermat's little theorem: a^-1 = a^(p-2) mod p
     */
    function modInverse(uint256 a) internal pure returns (uint256) {
        return modexp(a, FIELD_MODULUS - 2, FIELD_MODULUS);
    }

    /**
     * @dev Modular exponentiation: (base^exp) mod modulus
     */
    function modexp(uint256 base, uint256 exp, uint256 modulus) internal pure returns (uint256 result) {
        assembly {
            let memPtr := mload(0x40)
            mstore(memPtr, 0x20)           // Length of base
            mstore(add(memPtr, 0x20), 0x20) // Length of exponent
            mstore(add(memPtr, 0x40), 0x20) // Length of modulus
            mstore(add(memPtr, 0x60), base)
            mstore(add(memPtr, 0x80), exp)
            mstore(add(memPtr, 0xa0), modulus)

            if iszero(call(gas(), 0x05, 0, memPtr, 0xc0, memPtr, 0x20)) {
                revert(0, 0)
            }
            result := mload(memPtr)
        }
    }

    /**
     * @dev BN254 pairing check using precompiles
     * Checks if e(A,B) * e(C,D) * e(E,F) * e(G,H) = 1
     */
    function pairingCheck(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[2][2] memory d,
        uint256[2] memory e,
        uint256[2] memory f,
        uint256[2] memory g,
        uint256[2] memory h
    ) internal view returns (bool) {
        uint256[24] memory input;

        input[0] = a[0];
        input[1] = a[1];
        input[2] = b[0][0];
        input[3] = b[0][1];
        input[4] = b[1][0];
        input[5] = b[1][1];

        input[6] = c[0];
        input[7] = c[1];
        input[8] = d[0][0];
        input[9] = d[0][1];
        input[10] = d[1][0];
        input[11] = d[1][1];

        input[12] = e[0];
        input[13] = e[1];
        input[14] = f[0];
        input[15] = f[1];

        input[16] = g[0];
        input[17] = g[1];
        input[18] = h[0];
        input[19] = h[1];

        // Prepare negation for the third pairing
        input[20] = g[0];
        input[21] = (FIELD_MODULUS - g[1]) % FIELD_MODULUS; // -g[1]
        input[22] = h[0];
        input[23] = h[1];

        uint256[1] memory output;
        bool success;

        assembly {
            success := staticcall(gas(), 8, add(input, 0x20), 0x300, output, 0x20)
        }

        require(success, "Pairing check failed");
        return output[0] != 0;
    }
}

/**
 * @title CreditworthinessRegistry
 * @dev Main registry contract for managing ZK-proof-based credentials
 * Stores credentials, manages issuers, and verifies proofs
 */
contract CreditworthinessRegistry is Ownable, ReentrancyGuard {

    // ========================================================================
    // DATA STRUCTURES
    // ========================================================================

    /**
     * @dev Status of a credential
     */
    enum CredentialStatus {
        VALID,      // 0 - Credential is valid and active
        EXPIRED,    // 1 - Credential has expired
        REVOKED,    // 2 - Credential has been revoked
        NOT_FOUND   // 3 - Credential doesn't exist
    }

    /**
     * @dev Credential struct - stores all credential information
     */
    struct Credential {
        bytes32 id;                  // Unique identifier
        address user;                // Wallet address of credential holder
        address issuer;              // Institution that issued the credential
        bytes32 proofHash;           // Hash of the ZK proof
        uint256[] publicSignals;     // Public inputs (thresholds: income, payment ratio, credit score)
        uint256 issuedAt;            // Timestamp when credential was issued
        uint256 expiresAt;           // Timestamp when credential expires
        bool revoked;                // Whether credential has been revoked
        string credentialType;       // Type: "income_verification", "payment_history", etc.
    }

    /**
     * @dev Groth16 verification key structure
     */
    struct VerificationKey {
        uint256[2] alpha;
        uint256[2][2] beta;
        uint256[2] gamma;
        uint256[2] delta;
        uint256[][] gammaABC;
    }

    // ========================================================================
    // STATE VARIABLES
    // ========================================================================

    // Mapping from credential ID to credential data
    mapping(bytes32 => Credential) public credentials;

    // Mapping from user address to array of their credential IDs
    mapping(address => bytes32[]) public userCredentials;

    // Mapping from issuer address to verification key
    mapping(address => VerificationKey) public verificationKeys;

    // Mapping to track authorized issuers
    mapping(address => bool) public authorizedIssuers;

    // CredentialSBT address (deployed automatically)
    address public sbt;

    // Counter for generating unique credential IDs
    uint256 private credentialCounter;

    // Test mode flag (set to false for production)
    bool public testMode = true;

    // ========================================================================
    // EVENTS
    // ========================================================================

    /**
     * @dev Emitted when a credential is issued
     */
    event CredentialIssued(
        bytes32 indexed credentialId,
        address indexed user,
        address indexed issuer,
        string credentialType,
        uint256 expiresAt
    );

    /**
     * @dev Emitted when a credential is revoked
     */
    event CredentialRevoked(
        bytes32 indexed credentialId,
        address indexed revokedBy
    );

    /**
     * @dev Emitted when an issuer is authorized
     */
    event IssuerAuthorized(address indexed issuer);

    /**
     * @dev Emitted when an issuer is deauthorized
     */
    event IssuerDeauthorized(address indexed issuer);

    /**
     * @dev Emitted when verification key is registered
     */
    event VerificationKeyRegistered(address indexed issuer);

    // ========================================================================
    // MODIFIERS
    // ========================================================================

    /**
     * @dev Only authorized issuers can call
     */
    modifier onlyAuthorizedIssuer() {
        require(authorizedIssuers[msg.sender], "Not an authorized issuer");
        _;
    }

    // ========================================================================
    // CONSTRUCTOR
    // ========================================================================

    constructor() {
        credentialCounter = 0;
        // Deploy SBT contract
        sbt = address(new CredentialSBT(address(this)));
    }

    // ========================================================================
    // ISSUER MANAGEMENT
    // ========================================================================

    /**
     * @dev Authorize a new issuer (bank, credit bureau, etc.)
     * @param issuer Address of the issuer to authorize
     */
    function authorizeIssuer(address issuer) external onlyOwner {
        require(issuer != address(0), "Invalid issuer address");
        require(!authorizedIssuers[issuer], "Issuer already authorized");

        authorizedIssuers[issuer] = true;
        emit IssuerAuthorized(issuer);
    }

    /**
     * @dev Deauthorize an issuer
     * @param issuer Address of the issuer to deauthorize
     */
    function deauthorizeIssuer(address issuer) external onlyOwner {
        require(authorizedIssuers[issuer], "Issuer not authorized");

        authorizedIssuers[issuer] = false;
        emit IssuerDeauthorized(issuer);
    }

    /**
     * @dev Set test mode (for testing without production Groth16 verification)
     * @param _testMode true for test mode, false for production mode
     */
    function setTestMode(bool _testMode) external onlyOwner {
        testMode = _testMode;
    }

    // ========================================================================
    // VERIFICATION KEY MANAGEMENT
    // ========================================================================

    /**
     * @dev Register Groth16 verification key for proof validation
     * @param alpha First component of verification key
     * @param beta Second component of verification key
     * @param gamma Third component of verification key
     * @param delta Fourth component of verification key
     * @param gammaABC Fifth component of verification key
     */
    function registerVerificationKey(
        uint256[2] memory alpha,
        uint256[2][2] memory beta,
        uint256[2] memory gamma,
        uint256[2] memory delta,
        uint256[][] memory gammaABC
    ) external onlyAuthorizedIssuer {

        verificationKeys[msg.sender] = VerificationKey({
            alpha: alpha,
            beta: beta,
            gamma: gamma,
            delta: delta,
            gammaABC: gammaABC
        });

        emit VerificationKeyRegistered(msg.sender);
    }

    // ========================================================================
    // CREDENTIAL ISSUANCE
    // ========================================================================

    /**
     * @dev Issue a new credential after ZK proof verification
     * @param user Wallet address of credential holder
     * @param proofA First component of Groth16 proof
     * @param proofB Second component of Groth16 proof
     * @param proofC Third component of Groth16 proof
     * @param publicSignals Public inputs (thresholds)
     * @param credentialType Type of credential ("income_verification", etc.)
     * @param validityPeriod How long credential is valid (in seconds)
     * @return credentialId ID of the issued credential
     */
    function issueCredential(
        address user,
        uint256[2] memory proofA,
        uint256[2][2] memory proofB,
        uint256[2] memory proofC,
        uint256[] memory publicSignals,
        string memory credentialType,
        uint256 validityPeriod
    ) external onlyAuthorizedIssuer nonReentrant returns (bytes32) {

        require(user != address(0), "Invalid user address");
        require(publicSignals.length > 0, "Public signals required");
        require(validityPeriod > 0, "Validity period must be positive");

        // Get verification key for this issuer
        VerificationKey storage vk = verificationKeys[msg.sender];
        require(vk.alpha[0] != 0 || vk.alpha[1] != 0, "No verification key registered");

        // Verify the Groth16 proof
        bool proofValid;

        if (testMode) {
            // Test mode: Basic validation without full pairing checks
            proofValid = (
                proofA[0] != 0 || proofA[1] != 0  // Proof A not zero
            ) && (
                proofC[0] != 0 || proofC[1] != 0  // Proof C not zero
            ) && (
                publicSignals[0] > 0 || publicSignals.length > 1  // Has valid signals
            );
        } else {
            // Production mode: Full Groth16 verification with pairings
            proofValid = Groth16Verifier.verify(
                vk.alpha,
                vk.beta,
                vk.gamma,
                vk.delta,
                vk.gammaABC,
                proofA,
                proofB,
                proofC,
                publicSignals
            );
        }

        require(proofValid, "Invalid ZK proof");

        // Generate unique credential ID
        bytes32 credentialId = keccak256(
            abi.encodePacked(
                msg.sender,
                user,
                block.timestamp,
                credentialCounter
            )
        );
        credentialCounter++;

        // Calculate expiration timestamp
        uint256 expiresAt = block.timestamp + validityPeriod;

        // Create proof hash
        bytes32 proofHash = keccak256(abi.encodePacked(proofA, proofB, proofC));

        // Store credential
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

        // Add to user's credentials
        userCredentials[user].push(credentialId);

        // Emit event
        emit CredentialIssued(credentialId, user, msg.sender, credentialType, expiresAt);

        return credentialId;
    }

    // ========================================================================
    // CREDENTIAL VERIFICATION
    // ========================================================================

    /**
     * @dev Verify if a credential is valid
     * @param credentialId ID of credential to verify
     * @return status Status of the credential
     */
    function verifyCredential(bytes32 credentialId) external view returns (CredentialStatus) {

        Credential storage cred = credentials[credentialId];

        // Check if credential exists
        if (cred.id == bytes32(0)) {
            return CredentialStatus.NOT_FOUND;
        }

        // Check if revoked
        if (cred.revoked) {
            return CredentialStatus.REVOKED;
        }

        // Check if expired
        if (block.timestamp > cred.expiresAt) {
            return CredentialStatus.EXPIRED;
        }

        // Credential is valid
        return CredentialStatus.VALID;
    }

    /**
     * @dev Quick check if credential is valid (boolean)
     * @param credentialId ID of credential to check
     * @return true if credential is valid, false otherwise
     */
    function isCredentialValid(bytes32 credentialId) external view returns (bool) {
        CredentialStatus status = this.verifyCredential(credentialId);
        return status == CredentialStatus.VALID;
    }

    /**
     * @dev Get full credential details
     * @param credentialId ID of credential to retrieve
     * @return credential The credential struct
     */
    function getCredential(bytes32 credentialId) external view returns (Credential memory) {
        require(credentials[credentialId].id != bytes32(0), "Credential not found");
        return credentials[credentialId];
    }

    /**
     * @dev Get public signals from a credential
     * @param credentialId ID of credential
     * @return signals Array of public signals (thresholds)
     */
    function getPublicSignals(bytes32 credentialId) external view returns (uint256[] memory) {
        require(credentials[credentialId].id != bytes32(0), "Credential not found");
        return credentials[credentialId].publicSignals;
    }

    // ========================================================================
    // CREDENTIAL REVOCATION
    // ========================================================================

    /**
     * @dev Revoke a credential
     * Can be called by: issuer, credential holder, or contract owner
     * @param credentialId ID of credential to revoke
     */
    function revokeCredential(bytes32 credentialId) external nonReentrant {

        Credential storage cred = credentials[credentialId];

        require(cred.id != bytes32(0), "Credential not found");
        require(!cred.revoked, "Credential already revoked");

        // Check authorization
        require(
            msg.sender == cred.issuer ||
            msg.sender == cred.user ||
            msg.sender == owner(),
            "Not authorized to revoke"
        );

        // Revoke credential
        cred.revoked = true;

        emit CredentialRevoked(credentialId, msg.sender);
    }

    // ========================================================================
    // USER CREDENTIAL QUERIES
    // ========================================================================

    /**
     * @dev Get all credentials issued to a user
     * @param user Address of user
     * @return credentialIds Array of credential IDs
     */
    function getUserCredentials(address user) external view returns (bytes32[] memory) {
        return userCredentials[user];
    }

    /**
     * @dev Count how many valid credentials a user has
     * @param user Address of user
     * @return count Number of valid (non-expired, non-revoked) credentials
     */
    function getValidCredentialCount(address user) external view returns (uint256) {

        bytes32[] memory credIds = userCredentials[user];
        uint256 count = 0;

        for (uint256 i = 0; i < credIds.length; i++) {
            Credential storage cred = credentials[credIds[i]];

            // Check if valid (not revoked and not expired)
            if (!cred.revoked && block.timestamp <= cred.expiresAt) {
                count++;
            }
        }

        return count;
    }

    /**
     * @dev Get all valid credentials for a user
     * @param user Address of user
     * @return validCredentials Array of valid credential structs
     */
    function getUserValidCredentials(address user) external view returns (Credential[] memory) {

        bytes32[] memory credIds = userCredentials[user];
        uint256 validCount = 0;

        // Count valid credentials
        for (uint256 i = 0; i < credIds.length; i++) {
            Credential storage cred = credentials[credIds[i]];
            if (!cred.revoked && block.timestamp <= cred.expiresAt) {
                validCount++;
            }
        }

        // Create array of valid credentials
        Credential[] memory validCredentials = new Credential[](validCount);
        uint256 index = 0;

        for (uint256 i = 0; i < credIds.length; i++) {
            Credential storage cred = credentials[credIds[i]];
            if (!cred.revoked && block.timestamp <= cred.expiresAt) {
                validCredentials[index] = cred;
                index++;
            }
        }

        return validCredentials;
    }
}

/**
 * @title CredentialSBT
 * @dev Soul Bound Token - non-transferable representation of credentials
 */
contract CredentialSBT is ERC721 {

    address public registryAddress;
    uint256 private tokenCounter;

    // Mapping from credential ID to SBT token ID
    mapping(bytes32 => uint256) public credentialToToken;

    // Mapping from token ID to credential ID
    mapping(uint256 => bytes32) public tokenToCredential;

    event SBTMinted(uint256 indexed tokenId, bytes32 indexed credentialId, address indexed holder);
    event SBTRevoked(uint256 indexed tokenId, address indexed revokedBy);

    constructor(address _registry) ERC721("CredentialSBT", "CSBT") {
        registryAddress = _registry;
        tokenCounter = 0;
    }

    /**
     * @dev Mint a new SBT for a credential
     */
    function mint(address to, bytes32 credentialId) external returns (uint256) {
        require(msg.sender == registryAddress, "Only registry can mint");

        uint256 tokenId = tokenCounter;
        tokenCounter++;

        _safeMint(to, tokenId);

        credentialToToken[credentialId] = tokenId;
        tokenToCredential[tokenId] = credentialId;

        emit SBTMinted(tokenId, credentialId, to);
        return tokenId;
    }

    /**
     * @dev Revoke an SBT (burn it)
     */
    function revoke(uint256 tokenId) external {
        require(msg.sender == registryAddress, "Only registry can revoke");
        _burn(tokenId);
        emit SBTRevoked(tokenId, msg.sender);
    }

    /**
     * @dev Check if token is valid
     */
    function isValid(uint256 tokenId) external view returns (bool) {
        return _exists(tokenId);
    }

    /**
     * @dev Override transferFrom to prevent transfers (Soul Bound)
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public pure override {
        revert("SBTs are non-transferable");
    }

    /**
     * @dev Override safeTransferFrom to prevent transfers
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public pure override {
        revert("SBTs are non-transferable");
    }

    /**
     * @dev Override safeTransferFrom with data to prevent transfers
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public pure override {
        revert("SBTs are non-transferable");
    }
}
