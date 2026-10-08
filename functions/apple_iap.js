"use strict";

// EmploiBoost Apple purchase verification. No client-provided entitlement
// decisions are trusted; Apple signed transactions are verified server-side.
const APPLE_BUNDLE_ID = "com.emploiboost.emploiboost";
const APP_APPLE_ID = 6811853468;
const SUBSCRIPTIONS = new Set(["premium_monthly", "premium_yearly"]);
const PASSES = new Set(["intensive_exam_pass"]);
const ROOT_URLS = [
  "https://www.apple.com/certificateauthority/AppleRootCA-G2.cer",
  "https://www.apple.com/certificateauthority/AppleRootCA-G3.cer",
  "https://www.apple.com/certificateauthority/AppleIncRootCertificate.cer",
];
let rootPromise;

async function getAppleRoots(fetcher = fetch) {
  if (!rootPromise) {
    rootPromise = Promise.all(ROOT_URLS.map(async (url) => {
      const res = await fetcher(url, {signal: AbortSignal.timeout(12000)});
      if (!res.ok) throw Error("Apple trust roots unavailable");
      const bytes = Buffer.from(await res.arrayBuffer());
      if (bytes.length < 250 || bytes.length > 10000) throw Error("Invalid Apple root certificate");
      return bytes;
    })).catch((error) => {
      rootPromise = null;
      throw error;
    });
  }
  return rootPromise;
}

function eligibleSubscription(status, tx, now = Date.now()) {
  return [1, 4].includes(Number(status)) &&
    Number(tx?.expiresDate) > now &&
    !tx?.revocationDate &&
    SUBSCRIPTIONS.has(tx?.productId);
}

function validNumberId(id) {
  return typeof id === "string" && /^[0-9]{8,25}$/.test(id);
}

function assertSameOwner(transaction, originalId, expectedUuid) {
  if (String(transaction?.originalTransactionId || "") !== originalId) {
    throw Error("Apple transaction family does not match");
  }
  if (transaction.appAccountToken &&
      String(transaction.appAccountToken).toLowerCase() !== expectedUuid.toLowerCase()) {
    throw Error("Apple transaction belongs to another user");
  }
}

async function verifyAppleOrder({
  transactionId, requestedProductId, appAccountToken,
  signingKey, keyId, issuerId,
  sdk = require("@apple/app-store-server-library"),
  fetcher = fetch,
  now = Date.now(),
}) {
  if (!validNumberId(transactionId) ||
      !(SUBSCRIPTIONS.has(requestedProductId) || PASSES.has(requestedProductId))) {
    throw Error("Invalid transaction or product");
  }
  if (!/^[0-9a-f]{8}-[0-9a-f-]{27,}$/i.test(appAccountToken)) {
    throw Error("Missing account identity");
  }
  if (![signingKey, keyId, issuerId].every((value) => typeof value === "string" && value.trim())) {
    throw Error("Apple purchase server credentials missing");
  }
  const roots = await getAppleRoots(fetcher);
  const environments = [sdk.Environment.PRODUCTION, sdk.Environment.SANDBOX];
  let server, verifier, base, environment;
  for (const candidate of environments) {
    const client = new sdk.AppStoreServerAPIClient(
      signingKey, keyId, issuerId, APPLE_BUNDLE_ID, candidate);
    try {
      const response = await client.getTransactionInfo(transactionId);
      if (!response.signedTransactionInfo) throw Error("Unsigned App Store transaction");
      const checker = new sdk.SignedDataVerifier(
        roots, true, candidate, APPLE_BUNDLE_ID,
        candidate === sdk.Environment.PRODUCTION ? APP_APPLE_ID : undefined);
      const transaction = await checker.verifyAndDecodeTransaction(
        response.signedTransactionInfo);
      if (String(transaction.transactionId) !== transactionId) {
        throw Error("Apple returned a different transaction ID");
      }
      base = transaction;
      verifier = checker;
      server = client;
      environment = candidate;
      break;
    } catch (error) {
      // Only a transaction not found in Production permits a Sandbox lookup.
      if (candidate === sdk.Environment.PRODUCTION && error.httpStatusCode === 404) {
        continue;
      }
      throw error;
    }
  }
  if (!base) throw Error("Transaction not found in App Store");
  if (base.bundleId !== APPLE_BUNDLE_ID || base.productId !== requestedProductId ||
      base.revocationDate) throw Error("Unrecognized or revoked Apple transaction");

  const originalId = String(base.originalTransactionId || base.transactionId);
  assertSameOwner(base, originalId, appAccountToken);
  if (PASSES.has(requestedProductId)) {
    return {
      type: "pass", environment, productId: base.productId,
      transactionId: String(base.transactionId), originalId,
      appAccountToken: base.appAccountToken || null,
      verified: true, active: true, expiryMs: null,
    };
  }

  const subscriptionStatus = await server.getAllSubscriptionStatuses(originalId);
  const current = [];
  for (const group of subscriptionStatus.data || []) {
    for (const entry of group.lastTransactions || []) {
      if (!entry.signedTransactionInfo) continue;
      const tx = await verifier.verifyAndDecodeTransaction(entry.signedTransactionInfo);
      if (tx.bundleId !== APPLE_BUNDLE_ID) throw Error("Different app in subscription status");
      if (String(tx.originalTransactionId || tx.transactionId) !== originalId) {
        // Different original subscription families in same group may coexist.
        continue;
      }
      assertSameOwner(tx, originalId, appAccountToken);
      if (!SUBSCRIPTIONS.has(tx.productId)) continue;
      current.push({tx, status: Number(entry.status)});
    }
  }
  if (!current.length) throw Error("Apple subscription status missing");
  current.sort((a, b) => Number(b.tx.expiresDate || 0) - Number(a.tx.expiresDate || 0));
  const activeEntry = current.find(({tx, status}) => eligibleSubscription(status, tx, now));
  const best = activeEntry || current[0];
  return {
    type: "subscription", environment, productId: best.tx.productId,
    transactionId: String(best.tx.transactionId), originalId,
    appAccountToken: best.tx.appAccountToken || null,
    verified: true, active: Boolean(activeEntry),
    expiryMs: Number(best.tx.expiresDate) || null, status: best.status,
  };
}

module.exports = {
  APPLE_BUNDLE_ID, APP_APPLE_ID, SUBSCRIPTIONS, PASSES,
  eligibleSubscription, validNumberId, assertSameOwner, verifyAppleOrder,
};
