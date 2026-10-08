"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {eligibleSubscription, validNumberId, assertSameOwner, verifyAppleOrder} =
    require("../apple_iap");

const UUID = "29df66ca-71cb-46c3-8cba-9e729f9aec29";
const makeTransaction = (fields = {}) => ({
  transactionId: "2000000123456789",
  originalTransactionId: "2000000123456789",
  productId: "premium_monthly",
  bundleId: "com.emploiboost.emploiboost",
  appAccountToken: UUID,
  expiresDate: Date.now() + 86400000,
  ...fields,
});
const makeSdk = (base, latest, status = 1, sandbox = false) => ({
  Environment: {PRODUCTION: "Production", SANDBOX: "Sandbox"},
  AppStoreServerAPIClient: class {
    constructor(_key, _kid, _issuer, _bundle, environment) {
      this.environment = environment;
    }
    async getTransactionInfo() {
      if (sandbox && this.environment === "Production") {
        const error = new Error("Not found in production");
        error.httpStatusCode = 404;
        throw error;
      }
      return {signedTransactionInfo: "purchase"};
    }
    async getAllSubscriptionStatuses() {
      return {data: [{lastTransactions: [{
        signedTransactionInfo: "latest", status,
      }]}]};
    }
  },
  SignedDataVerifier: class {
    async verifyAndDecodeTransaction(encoded) {
      if (encoded === "purchase") return base;
      if (encoded === "latest") return latest;
      throw Error("Unknown mocked signed transaction");
    }
  },
});
const options = (base, latest, status = 1, sandbox = false) => ({
  transactionId: "2000000123456789",
  requestedProductId: base.productId,
  appAccountToken: UUID,
  signingKey: "pretend test-only secret",
  keyId: "TESTKEY",
  issuerId: "test-issuer",
  sdk: makeSdk(base, latest, status, sandbox),
  fetcher: async () => ({
    ok: true, arrayBuffer: async () => new Uint8Array(500).buffer,
  }),
});

test("rejects malformed Apple transaction identifiers", () => {
  assert.equal(validNumberId("x"), false);
  assert.equal(validNumberId("2000000123456789"), true);
});

test("active and billing grace-period subscription states are eligible", () => {
  const tx = makeTransaction();
  assert.equal(eligibleSubscription(1, tx), true);
  assert.equal(eligibleSubscription(4, tx), true);
  assert.equal(eligibleSubscription(2, tx), false);
  assert.equal(eligibleSubscription(3, tx), false);
  assert.equal(eligibleSubscription(5, tx), false);
  assert.equal(eligibleSubscription(1, {...tx, revocationDate: Date.now()}), false);
});

test("refuses a transaction bound to another Apple account UUID", () => {
  assert.throws(
    () => assertSameOwner(makeTransaction({appAccountToken:
      "b2a3207e-4e0d-4e58-b790-62f9ae479cda"}), "2000000123456789", UUID),
    /another user/,
  );
});

test("verifies an active subscription against current Apple status", async () => {
  const tx = makeTransaction();
  const result = await verifyAppleOrder(options(tx, tx));
  assert.equal(result.type, "subscription");
  assert.equal(result.active, true);
  assert.equal(result.productId, "premium_monthly");
});

test("an expired subscription never activates Premium", async () => {
  const tx = makeTransaction({expiresDate: Date.now() - 10000});
  const result = await verifyAppleOrder(options(tx, tx, 2));
  assert.equal(result.active, false);
});

test("handles production not-found lookup with sandbox fallback", async () => {
  const tx = makeTransaction();
  const result = await verifyAppleOrder(options(tx, tx, 1, true));
  assert.equal(result.environment, "Sandbox");
});

test("refuses signed product IDs not matching requested product", async () => {
  const original = makeTransaction({productId: "premium_yearly"});
  await assert.rejects(
    () => verifyAppleOrder({...options(original, original),
      requestedProductId: "premium_monthly"}),
    /Unrecognized or revoked/,
  );
});

test("a revoked transaction cannot be granted", async () => {
  const original = makeTransaction({revocationDate: Date.now()});
  await assert.rejects(
    () => verifyAppleOrder(options(original, original)),
    /Unrecognized or revoked/,
  );
});

test("refuses mismatched signed appAccountToken", async () => {
  const original = makeTransaction({appAccountToken:
    "b2a3207e-4e0d-4e58-b790-62f9ae479cda"});
  await assert.rejects(
    () => verifyAppleOrder(options(original, original)),
    /another user/,
  );
});

test("one-time intensive-exam pass is verified as a pass, not subscription", async () => {
  const pass = makeTransaction({productId: "intensive_exam_pass", expiresDate: null});
  const result = await verifyAppleOrder(options(pass, pass));
  assert.equal(result.type, "pass");
  assert.equal(result.active, true);
});
