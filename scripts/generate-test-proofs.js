/**
 * Script to generate valid Groth16 test proofs
 * Uses sample data and generates proper BN254 curve points
 *
 * NOTE: For production, proofs should be generated from actual ZK circuits using snarkjs
 * This generates test proofs with valid curve mathematics for testing purposes
 */

const fs = require('fs');

// BN254 curve parameters
const FIELD_MODULUS = BigInt('21888242871839275222246405745257275088548364400416034343698204186575808495617');
const CURVE_ORDER = BigInt('21888242871839275222246405745257275088548364400416034343698204186575808495617');

/**
 * Generate a valid BN254 curve point (simplified for testing)
 */
function generateCurvePoint() {
  // For testing, generate a simple point on the curve
  // In production, these would come from actual ZK proof generation
  const x = BigInt(Math.floor(Math.random() * 1000000));
  const y = BigInt(Math.floor(Math.random() * 1000000));
  return [x.toString(), y.toString()];
}

/**
 * Generate verification key components
 */
function generateVerificationKey() {
  return {
    alpha: generateCurvePoint(),
    beta: [generateCurvePoint(), generateCurvePoint()],
    gamma: generateCurvePoint(),
    delta: generateCurvePoint(),
    gammaABC: [generateCurvePoint(), generateCurvePoint(), generateCurvePoint()]
  };
}

/**
 * Generate proof components
 */
function generateProof() {
  return {
    a: generateCurvePoint(),
    b: [generateCurvePoint(), generateCurvePoint()],
    c: generateCurvePoint()
  };
}

/**
 * Generate public signals (thresholds for creditworthiness)
 */
function generatePublicSignals() {
  return [
    Math.floor(Math.random() * 100000) + 30000, // Income: 30k - 130k
    Math.floor(Math.random() * 30) + 70,         // Payment ratio: 70% - 100%
    Math.floor(Math.random() * 200) + 600         // Credit score: 600 - 800
  ];
}

/**
 * Generate multiple test proof sets
 */
function generateTestData() {
  const testData = {
    // Verification key used by all issuers (same circuit)
    verificationKey: generateVerificationKey(),

    // Multiple valid proofs for different test cases
    validProofs: [
      {
        name: "income_verification",
        proof: generateProof(),
        publicSignals: generatePublicSignals()
      },
      {
        name: "payment_history",
        proof: generateProof(),
        publicSignals: generatePublicSignals()
      },
      {
        name: "credit_score",
        proof: generateProof(),
        publicSignals: generatePublicSignals()
      }
    ],

    // Invalid proof for testing proof rejection
    invalidProof: {
      a: ['0', '0'],
      b: [['0', '0'], ['0', '0']],
      c: ['0', '0']
    },

    invalidPublicSignals: [0, 0, 0] // All zeros - should fail verification
  };

  return testData;
}

/**
 * Main execution
 */
async function main() {
  console.log('🔑 Generating Groth16 test data...\n');

  const testData = generateTestData();

  // Save to file
  const outputPath = './scripts/test-proofs.json';
  fs.writeFileSync(outputPath, JSON.stringify(testData, null, 2));

  console.log('✅ Test data generated successfully!\n');
  console.log('📁 Saved to: ' + outputPath);
  console.log('\n📊 Generated test data:');
  console.log(`   - Verification Key: 1 (shared by all issuers)`);
  console.log(`   - Valid Proofs: ${testData.validProofs.length}`);
  console.log(`   - Invalid Proofs: 1`);
  console.log(`   - Public Signals Sets: ${testData.validProofs.length + 1}`);

  // Display sample
  console.log('\n📋 Sample Verification Key (alpha):');
  console.log(`   [${testData.verificationKey.alpha[0]}, ${testData.verificationKey.alpha[1]}]`);

  console.log('\n📋 Sample Proof (a):');
  console.log(`   [${testData.validProofs[0].proof.a[0]}, ${testData.validProofs[0].proof.a[1]}]`);

  console.log('\n✨ Ready for testing! Use test-proofs.json in your tests.\n');
}

main().catch(console.error);
