// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Groth16MockVerifier
 * @dev Mock verifier for testing purposes
 *
 * In production, replace with actual Groth16Verifier or integrate with snarkjs
 * This allows tests to run while maintaining the verification interface
 */
contract Groth16MockVerifier {

    /**
     * @dev Mock verification function
     *
     * For testing, this accepts any proof with valid input structure.
     * In production, this would perform actual elliptic curve pairings.
     *
     * The mock checks:
     * 1. Verification key is registered
     * 2. Proof components are not zero (basic validation)
     * 3. Public signals match expected thresholds
     */
    function mockVerify(
        uint256[2] memory alpha,
        uint256[2][2] memory beta,
        uint256[2] memory gamma,
        uint256[2] memory delta,
        uint256[][] memory gammaABC,
        uint256[2] memory proofA,
        uint256[2][2] memory proofB,
        uint256[2] memory proofC,
        uint256[] memory input
    ) internal pure returns (bool) {
        // In test mode, verify basic structure

        // Check key structure
        if (alpha[0] == 0 && alpha[1] == 0) {
            return false;
        }

        if (gammaABC.length != input.length + 1) {
            return false;
        }

        // Check proof structure
        if (proofA[0] == 0 && proofA[1] == 0) {
            return false;
        }

        if (proofC[0] == 0 && proofC[1] == 0) {
            return false;
        }

        // Check public signals
        if (input.length == 0) {
            return false;
        }

        // Validate signal ranges (creditworthiness thresholds)
        if (input.length >= 3) {
            uint256 income = input[0];
            uint256 paymentRatio = input[1];
            uint256 creditScore = input[2];

            // Income should be > 0
            if (income == 0) return false;

            // Payment ratio should be 0-100
            if (paymentRatio > 100) return false;

            // Credit score should be > 0
            if (creditScore == 0) return false;
        }

        return true;
    }
}
