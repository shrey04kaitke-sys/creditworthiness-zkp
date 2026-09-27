// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

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

        // TODO: Verify ZK proof using verificationKeys[msg.sender]
        // For now, we'll accept the proof as valid

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
