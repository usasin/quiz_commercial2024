"use strict";

const crypto = require("node:crypto");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue, Timestamp} = require("firebase-admin/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onMessagePublished} = require("firebase-functions/v2/pubsub");
const {defineSecret} = require("firebase-functions/params");
const {GoogleAuth} = require("google-auth-library");

initializeApp();
const db = getFirestore();
const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");
const REGION = "europe-west1";
const PACKAGE_NAME = "com.emploiboost.emploiboost";
const SUBSCRIPTIONS = new Set(["premium_monthly", "premium_yearly"]);
const CREDIT_PACKS = new Map([
  ["credits_pack_s", 3],
  ["credits_pack_m", 9],
  ["credits_pack_l", 15],
]);
const INTENSIVE_EXAM_PRODUCTS = new Map([
  ["intensive_exam_pass", 1],
]);
const DAY_MS = 86400000;
const TRAINING_LIMITS = Object.freeze({
  free: {guidedPerDay: 0, guidedTurns: 5, examEveryDays: 0, examTurns: 0},
  premium: {guidedPerDay: 2, guidedTurns: 10, examEveryDays: 7, examTurns: 18},
  admin: {guidedPerDay: 10, guidedTurns: 14, examEveryDays: 0, examTurns: 24},
});

function requireUid(request) {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Connexion requise.");
  return uid;
}

function adminFromData(data) {
  return data?.isAdmin === true || data?.admin === true;
}

async function requireAdmin(request) {
  const uid = requireUid(request);
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists || !adminFromData(snap.data())) {
    throw new HttpsError("permission-denied", "Accès Super Admin requis.");
  }
  return uid;
}

async function adminAudit(uid, action, details = {}) {
  await db.collection("_private_admin_audit").add({
    uid,
    action,
    details,
    createdAt: FieldValue.serverTimestamp(),
  });
}

function asText(value, max = 12000) {
  return String(value ?? "").trim().slice(0, max);
}

function asObject(value) {
  return value && typeof value === "object" && !Array.isArray(value) ? value : {};
}

function asStringList(value, maxItems = 30, maxChars = 500) {
  return Array.isArray(value) ? value.slice(0, maxItems).map((x) => asText(x, maxChars)).filter(Boolean) : [];
}

function safeHistory(value, maxItems = 8, maxChars = 1200) {
  if (!Array.isArray(value)) return [];
  return value.slice(-maxItems).map((item) => ({
    role: item?.role === "assistant" ? "assistant" : "user",
    content: asText(item?.content, maxChars),
  })).filter((item) => item.content);
}

function extractOutputText(payload) {
  for (const item of payload?.output ?? []) {
    if (item?.type !== "message") continue;
    for (const content of item?.content ?? []) {
      if ((content?.type === "output_text" || content?.type === "text") && content?.text) {
        return typeof content.text === "string" ? content.text : String(content.text.value ?? "");
      }
    }
  }
  return "";
}

function recordAiHealth({ok, reason = "", message = ""}) {
  const update = ok ? {
    ok: true,
    reason: "",
    message: "Service IA opérationnel.",
    lastSuccessAt: FieldValue.serverTimestamp(),
  } : {
    ok: false,
    reason: asText(reason, 100),
    message: asText(message, 300),
    lastFailureAt: FieldValue.serverTimestamp(),
  };
  db.collection("system").doc("aiHealth").set(update, {merge: true})
    .catch((error) => console.error("AI health status write failed", error));
}

function openAiFailure(status, rawBody, fallbackMessage = "Le service IA est momentanément indisponible.") {
  let payload = {};
  try { payload = JSON.parse(rawBody); } catch (_) { /* réponse non JSON */ }
  const providerCode = asText(payload?.error?.code || payload?.error?.type, 120);
  console.error("OpenAI request failed", status, providerCode || "unknown", rawBody.slice(0, 500));

  if (status === 429 && (providerCode === "insufficient_quota" || providerCode === "billing_hard_limit_reached")) {
    recordAiHealth({ok: false, reason: "insufficient_quota", message: "Crédit OpenAI épuisé."});
    return new HttpsError(
      "failed-precondition",
      "La simulation IA est temporairement indisponible : le crédit du service est épuisé. Aucun crédit de simulation n'a été consommé.",
      {reason: "openai_insufficient_quota"},
    );
  }
  if (status === 429) {
    recordAiHealth({ok: false, reason: "rate_limit", message: "Limite de débit OpenAI atteinte."});
    return new HttpsError(
      "unavailable",
      "Le service IA est très sollicité. Réessaie dans quelques instants.",
      {reason: "openai_rate_limit"},
    );
  }
  if (status === 401 || status === 403) {
    recordAiHealth({ok: false, reason: "authentication", message: "Clé ou projet OpenAI à vérifier."});
    return new HttpsError(
      "failed-precondition",
      "La configuration du service IA doit être vérifiée par l'administrateur.",
      {reason: "openai_auth"},
    );
  }
  if (status === 404 || providerCode === "model_not_found") {
    recordAiHealth({ok: false, reason: "model_not_found", message: "Modèle OpenAI indisponible."});
    return new HttpsError(
      "failed-precondition",
      "Le modèle IA configuré n'est pas disponible.",
      {reason: "openai_model"},
    );
  }
  if (status >= 500) {
    recordAiHealth({ok: false, reason: "provider_incident", message: "Incident temporaire OpenAI."});
    return new HttpsError("unavailable", "Le service IA rencontre un incident. Réessaie dans quelques instants.");
  }
  recordAiHealth({ok: false, reason: providerCode || `http_${status}`, message: fallbackMessage});
  return new HttpsError("internal", fallbackMessage);
}

async function openAiJson(path, body, timeoutMs = 45000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(`https://api.openai.com/v1/${path}`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENAI_API_KEY.value()}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
    const text = await response.text();
    if (!response.ok) {
      throw openAiFailure(response.status, text, "Le coach IA est momentanément indisponible.");
    }
    recordAiHealth({ok: true});
    return JSON.parse(text);
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error("OpenAI request error", error);
    if (error?.name === "AbortError") {
      recordAiHealth({ok: false, reason: "timeout", message: "Délai OpenAI dépassé."});
      throw new HttpsError("deadline-exceeded", "Le coach IA met trop de temps à répondre.");
    }
    recordAiHealth({ok: false, reason: "network", message: "Connexion OpenAI indisponible."});
    throw new HttpsError("unavailable", "Impossible de joindre le service IA. Vérifie ta connexion puis réessaie.");
  } finally {
    clearTimeout(timer);
  }
}

async function entitlement(uid) {
  const snap = await db.collection("users").doc(uid).get();
  const data = snap.data() ?? {};
  const ent = data.entitlements ?? {};
  const admin = adminFromData(data);
  const testPremium = data.testAccess?.premium === true;
  return {
    premium: admin || testPremium || ent.isPremium === true,
    admin,
    testPremium,
    intensiveExamPasses: Math.max(0, Number(ent.intensiveExamPasses) || 0),
    plan: admin ? "ADMIN" : testPremium ? "ADMIN_TEST" : asText(ent.activePlan, 80) || "FREE",
  };
}

function requirePremiumExam(request, ent) {
  if (request.data?.examMode === true && !ent.premium) {
    throw new HttpsError(
      "permission-denied",
      "L’examen blanc complet est réservé aux abonnés Premium.",
    );
  }
}

function countOf(snapshot) {
  return Number(snapshot.data()?.count ?? 0);
}

function isoDate(value) {
  if (value?.toDate) return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  return null;
}

function publicCommunication(data) {
  const raw = asObject(data?.communication);
  if (!raw.enabled) return {enabled: false};
  return {
    id: asText(raw.id, 100),
    enabled: raw.enabled === true,
    kind: asText(raw.kind, 30),
    displayMode: asText(raw.displayMode, 30),
    audience: asText(raw.audience, 30),
    title: asText(raw.title, 120),
    message: asText(raw.message, 1500),
    imageUrl: safeHttpUrl(raw.imageUrl),
    actionLabel: asText(raw.actionLabel, 60),
    actionUrl: safeHttpUrl(raw.actionUrl),
    dismissible: raw.dismissible !== false,
    forceUpdate: raw.forceUpdate === true,
    minimumBuild: Math.max(0, Number(raw.minimumBuild) || 0),
    latestBuild: Math.max(0, Number(raw.latestBuild) || 0),
    startsAt: isoDate(raw.startsAt),
    expiresAt: isoDate(raw.expiresAt),
  };
}

function publicGamification(data) {
  const raw = asObject(data?.gamification);
  const challenge = asObject(raw.challenge);
  const metric = ["quiz", "simulation", "lesson", "assistant", "xp"].includes(challenge.metric) ? challenge.metric : "quiz";
  return {
    enabled: raw.enabled !== false,
    dailyGoal: Math.min(10, Math.max(1, Number(raw.dailyGoal) || 3)),
    dailyBonusXp: Math.min(500, Math.max(0, Number(raw.dailyBonusXp) || 25)),
    challenge: {
      id: asText(challenge.id, 100),
      enabled: challenge.enabled === true,
      title: asText(challenge.title, 100),
      description: asText(challenge.description, 300),
      metric,
      target: Math.min(10000, Math.max(1, Number(challenge.target) || 5)),
      bonusXp: Math.min(5000, Math.max(0, Number(challenge.bonusXp) || 150)),
      startsAt: isoDate(challenge.startsAt),
      expiresAt: isoDate(challenge.expiresAt),
    },
  };
}

exports.publicAppConfig = onCall({region: REGION}, async () => {
  const snap = await db.collection("system").doc("appConfig").get();
  return {
    communication: publicCommunication(snap.data()),
    gamification: publicGamification(snap.data()),
  };
});

exports.publicGamificationConfig = onCall({region: REGION}, async () => {
  const snap = await db.collection("system").doc("appConfig").get();
  return {gamification: publicGamification(snap.data())};
});

exports.adminGetAppConfig = onCall({region: REGION}, async (request) => {
  await requireAdmin(request);
  const snap = await db.collection("system").doc("appConfig").get();
  return {
    communication: publicCommunication(snap.data()),
    gamification: publicGamification(snap.data()),
  };
});

function subscriptionProductId(entitlement, receipt) {
  const productId = asText(entitlement?.productId || receipt?.productId, 100);
  if (SUBSCRIPTIONS.has(productId)) return productId;
  if (entitlement?.activePlan === "PREMIUM_YEARLY") return "premium_yearly";
  if (entitlement?.activePlan === "PREMIUM_MONTHLY") return "premium_monthly";
  return "";
}

function valueMillis(value) {
  if (value?.toMillis) return value.toMillis();
  if (value instanceof Date) return value.getTime();
  return 0;
}

async function collectSubscriptions() {
  const [usersSnap, receiptsSnap] = await Promise.all([
    db.collection("users").limit(500).get(),
    db.collection("_private_purchase_receipts")
      .where("productId", "in", [...SUBSCRIPTIONS])
      .limit(1500)
      .get(),
  ]);
  const receiptsByUid = new Map();
  for (const doc of receiptsSnap.docs) {
    const receipt = doc.data();
    if (!receipt?.uid || !SUBSCRIPTIONS.has(asText(receipt.productId, 100))) continue;
    const previous = receiptsByUid.get(receipt.uid);
    const receiptDate = valueMillis(receipt.verifiedAt || receipt.deliveredAt);
    const previousDate = valueMillis(previous?.verifiedAt || previous?.deliveredAt);
    if (!previous || receiptDate >= previousDate) receiptsByUid.set(receipt.uid, receipt);
  }

  return usersSnap.docs.map((doc) => {
    const data = doc.data();
    const ent = data.entitlements ?? {};
    const receipt = receiptsByUid.get(doc.id);
    const productId = subscriptionProductId(ent, receipt);
    const serverVerified = ent.verifiedBy === "google_play";
    const hasReceipt = Boolean(receipt);
    const legacyEntitlement = ent.isPremium === true && Boolean(productId);
    if (!serverVerified && !hasReceipt && !legacyEntitlement) return null;
    const plan = productId === "premium_yearly" ? "PREMIUM_YEARLY" : "PREMIUM_MONTHLY";
    const status = asText(ent.subscriptionStatus, 120) ||
      (ent.isPremium === true ? "LEGACY_ACTIVE" : "LEGACY_RECEIPT");
    return {
      uid: doc.id,
      name: asText(data.name || data.displayName, 160) || "Utilisateur",
      email: asText(data.email, 240),
      active: ent.isPremium === true,
      plan,
      productId,
      status,
      autoRenewing: ent.autoRenewing === true,
      startedAt: isoDate(ent.subscriptionStartedAt),
      expiresAt: isoDate(ent.subscriptionExpiresAt),
      verifiedAt: isoDate(ent.lastVerifiedAt || ent.updatedAt || receipt?.verifiedAt || receipt?.deliveredAt),
      orderId: asText(ent.latestOrderId, 200),
      regionCode: asText(ent.regionCode, 20),
      source: serverVerified ? "google_play" : hasReceipt ? "historical_receipt" : "legacy_entitlement",
      needsRefresh: !serverVerified,
    };
  }).filter(Boolean).sort((a, b) =>
    String(b.verifiedAt ?? b.startedAt ?? "").localeCompare(String(a.verifiedAt ?? a.startedAt ?? "")),
  );
}

exports.adminDashboardStats = onCall({region: REGION, timeoutSeconds: 60}, async (request) => {
  await requireAdmin(request);
  const users = db.collection("users");
  const now = Date.now();
  const since7 = Timestamp.fromMillis(now - 7 * 86400000);
  const since30 = Timestamp.fromMillis(now - 30 * 86400000);

  const [totalSnap, premiumSnap, new7Snap, new30Snap, subscriptions, aiHealthSnap, contentMarkerSnap] = await Promise.all([
    users.count().get(),
    users.where("entitlements.isPremium", "==", true).count().get(),
    users.where("createdAt", ">=", since7).count().get(),
    users.where("createdAt", ">=", since30).count().get(),
    collectSubscriptions(),
    db.collection("system").doc("aiHealth").get(),
    db.collection("app_config").doc("exam_v2").get(),
  ]);

  const today = new Date().toISOString().slice(0, 10);
  const month = today.slice(0, 7) + "-01";
  const [usageSnap, commerceSnap] = await Promise.all([
    db.collection("_private_ai_usage").where("day", ">=", month).get(),
    db.collection("_private_commerce_daily").where("day", ">=", month).get(),
  ]);
  let aiCallsToday = 0;
  let aiCallsMonth = 0;
  let guidedSessionsToday = 0;
  let guidedSessionsMonth = 0;
  let examSessionsMonth = 0;
  for (const doc of usageSnap.docs) {
    const d = doc.data();
    const calls = ["roleplay", "audio", "feedback", "writing"]
      .reduce((sum, key) => sum + Number(d[key] ?? 0), 0);
    aiCallsMonth += calls;
    guidedSessionsMonth += Number(d.guidedSessions ?? 0);
    examSessionsMonth += Number(d.examSessions ?? 0);
    if (d.day === today) {
      aiCallsToday += calls;
      guidedSessionsToday += Number(d.guidedSessions ?? 0);
    }
  }
  let intensivePassesSoldMonth = 0;
  for (const doc of commerceSnap.docs) {
    intensivePassesSoldMonth += Number(doc.data()?.intensiveExamPassesSold ?? 0);
  }

  let monthlyUsers = 0;
  let yearlyUsers = 0;
  let activePaidSubscribers = 0;
  let cancellingSubscribers = 0;
  let paymentIssueSubscribers = 0;
  for (const subscription of subscriptions) {
    if (subscription.active === true) {
      activePaidSubscribers++;
      if (subscription.plan === "PREMIUM_YEARLY") yearlyUsers++;
      else if (subscription.plan === "PREMIUM_MONTHLY") monthlyUsers++;
    }
    if (subscription.status === "SUBSCRIPTION_STATE_CANCELED" && subscription.active === true) cancellingSubscribers++;
    if (["SUBSCRIPTION_STATE_IN_GRACE_PERIOD", "SUBSCRIPTION_STATE_ON_HOLD"].includes(subscription.status)) {
      paymentIssueSubscribers++;
    }
  }
  const health = aiHealthSnap.data() ?? {};
  return {
    totalUsers: countOf(totalSnap),
    premiumUsers: countOf(premiumSnap),
    monthlyUsers,
    yearlyUsers,
    newUsers7Days: countOf(new7Snap),
    newUsers30Days: countOf(new30Snap),
    aiCallsToday,
    aiCallsMonth,
    guidedSessionsToday,
    guidedSessionsMonth,
    examSessionsMonth,
    intensivePassesSoldMonth,
    intensivePassRevenueMonth: Number((intensivePassesSoldMonth * 0.99).toFixed(2)),
    activePaidSubscribers,
    cancellingSubscribers,
    paymentIssueSubscribers,
    aiHealth: {
      ok: health.ok === true,
      reason: asText(health.reason, 100),
      message: asText(health.message, 300),
      lastSuccessAt: isoDate(health.lastSuccessAt),
      lastFailureAt: isoDate(health.lastFailureAt),
    },
    contentMigration: {
      applied: contentMarkerSnap.exists,
      curriculumVersion: contentMarkerSnap.exists ? 2 : 1,
      updatedAt: isoDate(contentMarkerSnap.data()?.updatedAt),
    },
    estimatedMonthlyRevenue: Number((monthlyUsers * 7.99 + yearlyUsers * (29.99 / 12)).toFixed(2)),
    estimatedRevenueWithPasses: Number((monthlyUsers * 7.99 + yearlyUsers * (29.99 / 12) +
      intensivePassesSoldMonth * 0.99).toFixed(2)),
  };
});

exports.adminListUsers = onCall({region: REGION, timeoutSeconds: 60}, async (request) => {
  await requireAdmin(request);
  const query = asText(request.data?.query, 160).toLowerCase();
  const snapshot = await db.collection("users").limit(500).get();
  const users = snapshot.docs.map((doc) => {
    const data = doc.data();
    const ent = data.entitlements ?? {};
    const testPremium = data.testAccess?.premium === true;
    const admin = adminFromData(data);
    return {
      uid: doc.id,
      name: asText(data.name || data.displayName, 160) || "Utilisateur",
      email: asText(data.email, 240),
      admin,
      premium: admin || testPremium || ent.isPremium === true,
      paidPremium: ent.isPremium === true,
      testPremium,
      plan: admin ? "ADMIN" : testPremium ? "ADMIN_TEST" : asText(ent.activePlan, 80) || "FREE",
      intensiveExamPasses: Math.max(0, Number(ent.intensiveExamPasses) || 0),
      createdAt: isoDate(data.createdAt),
      updatedAt: isoDate(data.updatedAt),
    };
  }).filter((user) => {
    if (!query) return true;
    return `${user.name} ${user.email} ${user.uid}`.toLowerCase().includes(query);
  }).sort((a, b) => String(b.updatedAt ?? b.createdAt ?? "").localeCompare(String(a.updatedAt ?? a.createdAt ?? "")));

  return {users: users.slice(0, 100)};
});

exports.adminListSubscriptions = onCall({region: REGION, timeoutSeconds: 60}, async (request) => {
  await requireAdmin(request);
  const subscriptions = await collectSubscriptions();
  return {subscriptions};
});

exports.adminSetTestPremium = onCall({region: REGION}, async (request) => {
  const adminUid = await requireAdmin(request);
  const targetUid = asText(request.data?.uid, 160);
  const enabled = request.data?.enabled === true;
  if (!targetUid) throw new HttpsError("invalid-argument", "Utilisateur manquant.");
  const targetRef = db.collection("users").doc(targetUid);
  const target = await targetRef.get();
  if (!target.exists) throw new HttpsError("not-found", "Utilisateur introuvable.");

  await targetRef.set({
    testAccess: {
      premium: enabled,
      grantedBy: adminUid,
      updatedAt: FieldValue.serverTimestamp(),
    },
  }, {merge: true});
  await adminAudit(adminUid, "set_test_premium", {targetUid, enabled});
  return {ok: true};
});

function safeHttpUrl(value) {
  const text = asText(value, 2000);
  if (!text) return "";
  try {
    const url = new URL(text);
    if (url.protocol !== "https:" && url.protocol !== "http:") return "";
    return url.toString();
  } catch (_) {
    return "";
  }
}

exports.adminPublishCommunication = onCall({region: REGION}, async (request) => {
  const adminUid = await requireAdmin(request);
  const raw = asObject(request.data?.communication);
  if (raw.enabled === false) {
    await db.collection("system").doc("appConfig").set({
      communication: {
        enabled: false,
        id: `disabled_${Date.now()}`,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: adminUid,
      },
    }, {merge: true});
    await adminAudit(adminUid, "disable_communication");
    return {ok: true};
  }

  const kinds = new Set(["announcement", "update", "maintenance"]);
  const modes = new Set(["banner", "modal", "fullscreen"]);
  const audiences = new Set(["all", "free", "premium"]);
  const title = asText(raw.title, 120);
  const message = asText(raw.message, 1500);
  if (!title || !message) throw new HttpsError("invalid-argument", "Titre et message requis.");

  const kind = kinds.has(raw.kind) ? raw.kind : "announcement";
  const forceUpdate = kind === "update" && raw.forceUpdate === true;
  const expiresInDays = Math.min(365, Math.max(0, Number(raw.expiresInDays) || 0));
  const communication = {
    id: `message_${Date.now()}`,
    enabled: true,
    kind,
    displayMode: forceUpdate ? "fullscreen" : modes.has(raw.displayMode) ? raw.displayMode : "modal",
    audience: audiences.has(raw.audience) ? raw.audience : "all",
    title,
    message,
    imageUrl: safeHttpUrl(raw.imageUrl),
    actionLabel: asText(raw.actionLabel, 60) || (kind === "update" ? "Mettre à jour" : "En savoir plus"),
    actionUrl: safeHttpUrl(raw.actionUrl),
    dismissible: forceUpdate ? false : raw.dismissible !== false,
    forceUpdate,
    minimumBuild: Math.max(0, Number(raw.minimumBuild) || 0),
    latestBuild: Math.max(0, Number(raw.latestBuild) || 0),
    startsAt: new Date(),
    expiresAt: expiresInDays > 0 ? new Date(Date.now() + expiresInDays * 86400000) : null,
    publishedAt: FieldValue.serverTimestamp(),
    updatedBy: adminUid,
  };
  if (forceUpdate && !communication.actionUrl) {
    throw new HttpsError("invalid-argument", "Le lien Play Store est obligatoire pour une mise à jour forcée.");
  }
  if (forceUpdate && communication.minimumBuild <= 0) {
    throw new HttpsError("invalid-argument", "Le build minimum est obligatoire.");
  }

  await db.collection("system").doc("appConfig").set({communication}, {merge: true});
  await adminAudit(adminUid, "publish_communication", {
    kind: communication.kind,
    displayMode: communication.displayMode,
    audience: communication.audience,
    forceUpdate,
  });
  return {ok: true, id: communication.id};
});

exports.adminPublishGamification = onCall({region: REGION}, async (request) => {
  const adminUid = await requireAdmin(request);
  const raw = asObject(request.data?.gamification);
  const challengeRaw = asObject(raw.challenge);
  const metrics = new Set(["quiz", "simulation", "lesson", "assistant", "xp"]);
  const enabled = raw.enabled !== false;
  const challengeEnabled = challengeRaw.enabled === true;
  const title = asText(challengeRaw.title, 100);
  if (challengeEnabled && !title) {
    throw new HttpsError("invalid-argument", "Le titre du défi est obligatoire.");
  }
  const durationDays = Math.min(90, Math.max(1, Number(challengeRaw.durationDays) || 7));
  const now = new Date();
  const gamification = {
    enabled,
    dailyGoal: Math.min(10, Math.max(1, Number(raw.dailyGoal) || 3)),
    dailyBonusXp: Math.min(500, Math.max(0, Number(raw.dailyBonusXp) || 25)),
    challenge: {
      id: challengeEnabled ? `challenge_${Date.now()}` : `disabled_${Date.now()}`,
      enabled: challengeEnabled,
      title,
      description: asText(challengeRaw.description, 300),
      metric: metrics.has(challengeRaw.metric) ? challengeRaw.metric : "quiz",
      target: Math.min(10000, Math.max(1, Number(challengeRaw.target) || 5)),
      bonusXp: Math.min(5000, Math.max(0, Number(challengeRaw.bonusXp) || 150)),
      startsAt: now,
      expiresAt: new Date(now.getTime() + durationDays * 86400000),
    },
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: adminUid,
  };
  await db.collection("system").doc("appConfig").set({gamification}, {merge: true});
  await adminAudit(adminUid, "publish_gamification", {
    challengeEnabled,
    metric: gamification.challenge.metric,
    target: gamification.challenge.target,
  });
  return {ok: true, id: gamification.challenge.id};
});

function dayKey(now = new Date()) {
  return now.toISOString().slice(0, 10);
}

function trainingTier(data) {
  if (adminFromData(data)) return "admin";
  const ent = asObject(data?.entitlements);
  if (data?.testAccess?.premium === true || ent.isPremium === true) return "premium";
  return "free";
}

function timestampMillis(value) {
  if (value?.toMillis) return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const parsed = Date.parse(value ?? "");
  return Number.isFinite(parsed) ? parsed : 0;
}

function trainingError(reason, message, details = {}) {
  return new HttpsError("resource-exhausted", message, {reason, ...details});
}

async function trainingAccess(uid) {
  const now = new Date();
  const today = dayKey(now);
  const [userSnap, usageSnap] = await Promise.all([
    db.collection("users").doc(uid).get(),
    db.collection("_private_ai_usage").doc(`${uid}_${today}`).get(),
  ]);
  const user = userSnap.data() ?? {};
  const ent = asObject(user.entitlements);
  const training = asObject(user.aiTraining);
  const usage = usageSnap.data() ?? {};
  const tier = trainingTier(user);
  const limits = TRAINING_LIMITS[tier];
  const guidedUsed = Math.max(0, Number(usage.guidedSessions) || 0);
  const lastIncludedExamMs = timestampMillis(training.lastIncludedExamAt);
  const includedExamAvailable = tier === "admin" || (tier === "premium" &&
    (!lastIncludedExamMs || now.getTime() - lastIncludedExamMs >= limits.examEveryDays * DAY_MS));
  const freeDiscoveryAvailable = tier === "free" && training.freeDiscoveryUsed !== true;
  return {
    tier,
    guidedDailyLimit: tier === "free" ? 1 : limits.guidedPerDay,
    guidedUsedToday: guidedUsed,
    guidedRemainingToday: tier === "free" ? (freeDiscoveryAvailable ? 1 : 0) :
      Math.max(0, limits.guidedPerDay - guidedUsed),
    freeDiscoveryAvailable,
    includedExamAvailable,
    nextIncludedExamAt: tier === "premium" && !includedExamAvailable ?
      new Date(lastIncludedExamMs + limits.examEveryDays * DAY_MS).toISOString() : null,
    intensiveExamPasses: Math.max(0, Number(ent.intensiveExamPasses) || 0),
  };
}

exports.aiTrainingAccess = onCall({region: REGION}, async (request) => {
  const uid = requireUid(request);
  return trainingAccess(uid);
});

exports.aiStartTrainingSession = onCall({region: REGION}, async (request) => {
  const uid = requireUid(request);
  const type = request.data?.type === "exam" ? "exam" : "guided";
  const scenarioId = asText(request.data?.scenarioId, 200);
  const track = asText(request.data?.track, 80).toLowerCase();
  const now = new Date();
  const today = dayKey(now);
  const userRef = db.collection("users").doc(uid);
  const usageRef = db.collection("_private_ai_usage").doc(`${uid}_${today}`);
  const sessionRef = db.collection("_private_ai_sessions").doc();
  let result = null;

  await db.runTransaction(async (tx) => {
    const [userSnap, usageSnap] = await Promise.all([tx.get(userRef), tx.get(usageRef)]);
    const user = userSnap.data() ?? {};
    const ent = asObject(user.entitlements);
    const training = asObject(user.aiTraining);
    const usage = usageSnap.data() ?? {};
    const tier = trainingTier(user);
    const limits = TRAINING_LIMITS[tier];
    let accessSource = tier;
    let maxTurns = type === "exam" ? limits.examTurns : limits.guidedTurns;
    let maxFeedback = type === "exam" ? 2 : 1;
    let maxWriting = type === "exam" ? 2 : (tier === "free" ? 0 : 2);

    if (type === "guided") {
      const used = Math.max(0, Number(usage.guidedSessions) || 0);
      if (tier === "free") {
        if (training.freeDiscoveryUsed === true) {
          throw trainingError(
            "discovery_used",
            "Ton essai découverte est terminé. Passe en Premium pour poursuivre les entraînements guidés.",
          );
        }
        accessSource = "free_discovery";
        maxTurns = TRAINING_LIMITS.free.guidedTurns;
        maxFeedback = 1;
        maxWriting = 0;
        tx.set(userRef, {aiTraining: {freeDiscoveryUsed: true, updatedAt: FieldValue.serverTimestamp()}}, {merge: true});
      } else if (used >= limits.guidedPerDay) {
        throw trainingError(
          "guided_daily_complete",
          "Excellent entraînement aujourd’hui. Révise les axes du coach : de nouvelles séances guidées seront disponibles demain.",
          {dailyLimit: limits.guidedPerDay},
        );
      }
      tx.set(usageRef, {
        uid,
        day: today,
        guidedSessions: used + 1,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    } else {
      const examSessions = Math.max(0, Number(usage.examSessions) || 0);
      if (tier === "free") maxTurns = TRAINING_LIMITS.premium.examTurns;
      if (tier === "admin") {
        if (examSessions >= 10) {
          throw trainingError(
            "admin_daily_complete",
            "Plafond de test Admin atteint pour aujourd’hui.",
            {dailyLimit: 10},
          );
        }
        accessSource = "admin";
      } else {
        const lastIncludedMs = timestampMillis(training.lastIncludedExamAt);
        const included = tier === "premium" &&
          (!lastIncludedMs || now.getTime() - lastIncludedMs >= limits.examEveryDays * DAY_MS);
        if (included) {
          accessSource = "premium_included";
          tx.set(userRef, {aiTraining: {
            lastIncludedExamAt: Timestamp.fromDate(now),
            updatedAt: FieldValue.serverTimestamp(),
          }}, {merge: true});
        } else {
          const passes = Math.max(0, Number(ent.intensiveExamPasses) || 0);
          if (passes <= 0) {
            throw trainingError(
              "intensive_pass_required",
              tier === "premium" ?
                "Ton examen inclus est déjà utilisé. Le Pass intensif débloque immédiatement un nouvel examen blanc complet." :
                "Le Pass intensif débloque un examen blanc complet avec bilan.",
              {nextIncludedExamAt: tier === "premium" && lastIncludedMs ?
                new Date(lastIncludedMs + limits.examEveryDays * DAY_MS).toISOString() : null},
            );
          }
          accessSource = "intensive_pass";
          tx.set(userRef, {entitlements: {
            intensiveExamPasses: passes - 1,
            updatedAt: FieldValue.serverTimestamp(),
          }}, {merge: true});
        }
      }
      tx.set(usageRef, {
        uid,
        day: today,
        examSessions: examSessions + 1,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }

    const expiresAt = Timestamp.fromMillis(now.getTime() + (type === "exam" ? 8 : 2) * 3600000);
    tx.set(sessionRef, {
      uid,
      type,
      tier,
      accessSource,
      scenarioId,
      track,
      maxTurns,
      maxFeedback,
      maxWriting,
      maxSpeech: type === "exam" ? 4 : 2,
      roleplay: 0,
      audio: 0,
      feedback: 0,
      writing: 0,
      speech: 0,
      createdAt: FieldValue.serverTimestamp(),
      expiresAt,
    });
    result = {
      sessionId: sessionRef.id,
      type,
      tier,
      accessSource,
      maxTurns,
      expiresAt: expiresAt.toDate().toISOString(),
    };
  });
  return result;
});

async function useQuota(uid, kind, ent) {
  const now = new Date();
  const day = dayKey(now);
  const limits = ent.admin ?
    {roleplay: 160, audio: 160, feedback: 20, writing: 20, speech: 20} : ent.premium ?
      {roleplay: 20, audio: 20, feedback: 3, writing: 2, speech: 5} :
      {roleplay: 5, audio: 5, feedback: 1, writing: 0, speech: 0};
  const limit = limits[kind] ?? 0;
  if (limit <= 0) throw new HttpsError("permission-denied", "Fonction réservée à Premium.");
  const ref = db.collection("_private_ai_usage").doc(`${uid}_${day}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const current = Number(snap.data()?.[kind] ?? 0);
    if (current >= limit) {
      throw trainingError(
        "legacy_daily_complete",
        "Excellent entraînement aujourd’hui. Reprends les conseils du coach avant ta prochaine séance.",
        {dailyLimit: limit},
      );
    }
    tx.set(ref, {uid, day, [kind]: current + 1, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  });
}

async function refundQuota(uid, kind) {
  const day = new Date().toISOString().slice(0, 10);
  const ref = db.collection("_private_ai_usage").doc(`${uid}_${day}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const current = Number(snap.data()?.[kind] ?? 0);
    if (current > 0) {
      tx.set(ref, {[kind]: current - 1, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
    }
  });
}

async function withQuota(uid, kind, ent, action) {
  await useQuota(uid, kind, ent);
  try {
    return await action();
  } catch (error) {
    try {
      await refundQuota(uid, kind);
    } catch (refundError) {
      console.error("AI quota refund failed", uid, kind, refundError);
    }
    throw error;
  }
}

async function useSessionQuota(uid, sessionId, kind, examMode) {
  const sessionRef = db.collection("_private_ai_sessions").doc(sessionId);
  const today = dayKey();
  const usageRef = db.collection("_private_ai_usage").doc(`${uid}_${today}`);
  let sessionData = null;
  await db.runTransaction(async (tx) => {
    const [sessionSnap, usageSnap] = await Promise.all([tx.get(sessionRef), tx.get(usageRef)]);
    if (!sessionSnap.exists || sessionSnap.data()?.uid !== uid) {
      throw new HttpsError("permission-denied", "Séance d’entraînement invalide.", {reason: "invalid_session"});
    }
    const session = sessionSnap.data();
    if (timestampMillis(session.expiresAt) <= Date.now()) {
      throw trainingError("session_expired", "Cette séance est terminée. Lance un nouvel entraînement.");
    }
    if (examMode === true && session.type !== "exam") {
      throw new HttpsError("permission-denied", "Cette séance ne donne pas accès à l’examen blanc.", {reason: "exam_session_required"});
    }
    const maximum = kind === "roleplay" || kind === "audio" ? Number(session.maxTurns) || 0 :
      kind === "feedback" ? Number(session.maxFeedback) || 0 :
        kind === "writing" ? Number(session.maxWriting) || 0 : Number(session.maxSpeech) || 0;
    const current = Math.max(0, Number(session[kind]) || 0);
    if (current >= maximum) {
      const message = kind === "roleplay" || kind === "audio" ?
        "La mise en situation est complète. Termine maintenant pour recevoir ou relire ton bilan." :
        "Le bilan prévu pour cette séance est déjà disponible. Utilise-le pour préparer ton prochain essai.";
      throw trainingError("session_complete", message, {maximum, kind});
    }
    const usage = usageSnap.data() ?? {};
    tx.set(sessionRef, {[kind]: current + 1, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
    tx.set(usageRef, {
      uid,
      day: today,
      [kind]: Math.max(0, Number(usage[kind]) || 0) + 1,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    sessionData = {...session, id: sessionSnap.id};
  });
  return sessionData;
}

async function refundSessionQuota(uid, sessionId, kind) {
  const sessionRef = db.collection("_private_ai_sessions").doc(sessionId);
  const today = dayKey();
  const usageRef = db.collection("_private_ai_usage").doc(`${uid}_${today}`);
  await db.runTransaction(async (tx) => {
    const [sessionSnap, usageSnap] = await Promise.all([tx.get(sessionRef), tx.get(usageRef)]);
    if (!sessionSnap.exists || sessionSnap.data()?.uid !== uid) return;
    const sessionCurrent = Math.max(0, Number(sessionSnap.data()?.[kind]) || 0);
    const usageCurrent = Math.max(0, Number(usageSnap.data()?.[kind]) || 0);
    tx.set(sessionRef, {[kind]: Math.max(0, sessionCurrent - 1), updatedAt: FieldValue.serverTimestamp()}, {merge: true});
    tx.set(usageRef, {[kind]: Math.max(0, usageCurrent - 1), updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  });
}

async function withAiAccess(uid, kind, ent, data, action) {
  const sessionId = asText(data.sessionId, 160);
  if (!sessionId) {
    requirePremiumExam({data}, ent);
    return withQuota(uid, kind, ent, () => action(null));
  }
  const session = await useSessionQuota(uid, sessionId, kind, data.examMode === true);
  try {
    return await action(session);
  } catch (error) {
    try {
      await refundSessionQuota(uid, sessionId, kind);
    } catch (refundError) {
      console.error("AI session quota refund failed", uid, kind, refundError);
    }
    throw error;
  }
}

function scenarioParts(data) {
  const scenario = asObject(data.scenarioData);
  const briefing = asObject(scenario.briefing);
  const track = asText(scenario.track || data.track || "cip", 60).toLowerCase();
  const locale = asText(data.locale || scenario.locale || "fr", 10).toLowerCase() === "en" ? "en" : "fr";
  const isNtc = track === "ntc" || asText(scenario.rncpReference, 40) === "RNCP39063";
  const isAgent = track === "agent";
  const profile = isNtc
    ? {
        track: "ntc",
        diplomaTitle: locale === "en" ? "Technical Sales Representative" : "Négociateur technico-commercial",
        rncpReference: "RNCP39063",
      }
    : isAgent
      ? {
          track: "agent",
          diplomaTitle: locale === "en" ? "Rental Desk Agent" : "Agent de comptoir en location de véhicules",
          rncpReference: "",
        }
      : {
          track: "cip",
          diplomaTitle: locale === "en" ? "Employment Integration Advisor" : "Conseiller en insertion professionnelle",
          rncpReference: "RNCP37274",
        };
  return {
    title: asText(scenario.title || data.scenarioTitle, 300),
    actor: asText(scenario.actor || data.persona?.actor || "bénéficiaire", 100),
    track: profile.track,
    diplomaTitle: profile.diplomaTitle,
    rncpReference: profile.rncpReference,
    locale,
    objectives: asStringList(scenario.objectives || briefing.objectives),
    plan: asStringList(scenario.plan || briefing.plan),
    pitfalls: asStringList(scenario.pitfalls || briefing.pitfalls),
    notExpected: asStringList(scenario.notExpected || briefing.notExpected),
    rubric: asObject(scenario.rubric || scenario["rubric "] || briefing.rubric),
  };
}

exports.aiRoleplay = onCall({region: REGION, secrets: [OPENAI_API_KEY], timeoutSeconds: 60}, async (request) => {
  const uid = requireUid(request);
  const ent = await entitlement(uid);
  const data = asObject(request.data);
  return withAiAccess(uid, "roleplay", ent, data, async () => {
    const scenario = scenarioParts(data);
    const persona = asObject(data.persona);
    const languageRule = scenario.locale === "en"
      ? "Speak and respond only in natural English."
      : "Parle et réponds uniquement en français naturel.";
    const instructions = `Tu joues ${scenario.actor} dans une simulation de préparation au titre professionnel ${scenario.diplomaTitle} ${scenario.rncpReference}.
${languageRule}
Reste réaliste, naturel et bref. Ne fais pas de cours et ne donne pas la réponse attendue au candidat.
Révèle les informations progressivement uniquement si les questions sont pertinentes.
Objectifs: ${scenario.objectives.join(" | ") || "non fournis"}
Plan: ${scenario.plan.join(" | ") || "non fourni"}
Pièges: ${scenario.pitfalls.join(" | ") || "non fournis"}
Hors périmètre: ${scenario.notExpected.join(" | ") || "non fourni"}
Scénario: ${scenario.title || asText(data.scenarioId, 200)}
Persona: ${JSON.stringify(persona).slice(0, 5000)}`;
    const recentHistory = safeHistory(data.history, 8, 1200);
    const userMessage = asText(data.userMessage, 1600);
    if (recentHistory.at(-1)?.role === "user" && recentHistory.at(-1)?.content === userMessage) {
      recentHistory.pop();
    }
    const response = await openAiJson("responses", {
      model: "gpt-4.1-mini",
      instructions,
      input: [...recentHistory, {role: "user", content: userMessage}],
      temperature: 0.75,
      max_output_tokens: 200,
      store: false,
    });
    const text = extractOutputText(response).trim();
    if (!text) throw new HttpsError("internal", "Réponse IA vide.");
    return {text};
  });
});

const coachSchema = {
  type: "object", additionalProperties: false,
  properties: {
    score: {type: "integer", minimum: 0, maximum: 100},
    strengths: {type: "array", items: {type: "string"}, maxItems: 8},
    improvements: {type: "array", items: {type: "string"}, maxItems: 8},
    missingQuestions: {type: "array", items: {type: "string"}, maxItems: 10},
    competencyScores: {type: "array", items: {type: "object", additionalProperties: false, properties: {
      competency: {type: "string"}, score: {type: "integer", minimum: 0, maximum: 100}, evidence: {type: "string"},
    }, required: ["competency", "score", "evidence"]}, maxItems: 8},
    nextLesson: {type: "string"},
  },
  required: ["score", "strengths", "improvements", "missingQuestions", "competencyScores", "nextLesson"],
};

exports.aiCoachFeedback = onCall({region: REGION, secrets: [OPENAI_API_KEY], timeoutSeconds: 60}, async (request) => {
  const uid = requireUid(request);
  const ent = await entitlement(uid);
  const data = asObject(request.data);
  return withAiAccess(uid, "feedback", ent, data, async (session) => {
    const scenario = scenarioParts(data);
    const concise = !ent.premium && session?.type !== "exam";
    const instructions = `Tu es jury et coach du titre professionnel ${scenario.diplomaTitle} ${scenario.rncpReference}.
${scenario.locale === "en" ? "Write every user-facing JSON value in English." : "Rédige toutes les valeurs JSON destinées à l'utilisateur en français."}
Évalue uniquement les éléments observables dans la transcription et les objectifs du scénario.
Ne valorise jamais une information inventée. Explique les écarts de manière concrète et bienveillante.
Objectifs: ${scenario.objectives.join(" | ") || "non fournis"}
Plan attendu: ${scenario.plan.join(" | ") || "non fourni"}
Grille spécifique: ${JSON.stringify(scenario.rubric).slice(0, 5000)}
${concise ? "Version gratuite: limite chaque liste à 3 éléments et propose un seul prochain apprentissage." : "Version Premium: feedback détaillé, preuves et axes de progression."}
Retourne uniquement le JSON conforme au schéma.`;
    const response = await openAiJson("responses", {
      model: "gpt-4.1-mini",
      instructions,
      input: [{role: "user", content: `TRANSCRIPTION:\n${JSON.stringify(safeHistory(data.transcript, 24, 1600))}`}],
      temperature: 0.15,
      max_output_tokens: concise ? 550 : 900,
      store: false,
      text: {format: {type: "json_schema", name: "training_feedback", strict: true, schema: coachSchema}},
    });
    const raw = extractOutputText(response).trim();
    try { return {feedback: JSON.parse(raw), premium: ent.premium}; } catch (_) {
      throw new HttpsError("internal", "Le compte rendu n'a pas pu être généré.");
    }
  });
});

const writingSchema = {
  type: "object", additionalProperties: false,
  properties: {
    note: {type: "integer", minimum: 0, maximum: 100},
    ok: {type: "array", items: {type: "string"}, maxItems: 8},
    a_corriger: {type: "array", items: {type: "string"}, maxItems: 8},
    proposition: {type: "string"},
  }, required: ["note", "ok", "a_corriger", "proposition"],
};

exports.aiCorrectWriting = onCall({region: REGION, secrets: [OPENAI_API_KEY], timeoutSeconds: 60}, async (request) => {
  const uid = requireUid(request);
  const ent = await entitlement(uid);
  const data = asObject(request.data);
  return withAiAccess(uid, "writing", ent, data, async () => {
    const writingKinds = {
      analysis: "analyse de pratique",
      synthesis: "synthèse d'entretien",
      sales_report: "compte rendu commercial",
      dashboard: "analyse de tableau de bord commercial",
      action_plan: "plan d'actions commerciales",
      commercial_proposal: "proposition technique et commerciale",
      commercial_case: "étude de cas commerciale avec tableau de bord, plan d'actions et proposition",
      swot: "analyse SWOT argumentée",
    };
    const kindKey = asText(data.kind, 60);
    const kind = writingKinds[kindKey] || "production professionnelle";
    const scenario = scenarioParts(data);
    const response = await openAiJson("responses", {
      model: "gpt-4.1-mini",
      instructions: `Tu corriges une ${kind} pour le titre professionnel ${scenario.diplomaTitle} ${scenario.rncpReference}. Vérifie la structure, les faits, les calculs ou indicateurs cités, la cohérence commerciale, la faisabilité, la rentabilité, la qualité de l'argumentation et les pistes d'amélioration adaptées à cette production. N'invente aucune donnée absente. Objectifs du scénario: ${scenario.objectives.join(" | ")}. ${scenario.locale === "en" ? "Write every user-facing JSON value in English." : "Rédige toutes les valeurs JSON destinées à l'utilisateur en français."} Retourne uniquement le JSON demandé.`,
      input: [{role: "user", content: `TRANSCRIPTION:\n${JSON.stringify(safeHistory(data.transcript, 16, 1400))}\n\nTEXTE:\n${asText(data.text, 9000)}`}],
      temperature: 0.15,
      max_output_tokens: 850,
      store: false,
      text: {format: {type: "json_schema", name: "professional_writing", strict: true, schema: writingSchema}},
    });
    try { return {result: JSON.parse(extractOutputText(response).trim())}; } catch (_) {
      throw new HttpsError("internal", "La correction n'a pas pu être générée.");
    }
  });
});

exports.aiTranscribe = onCall({region: REGION, secrets: [OPENAI_API_KEY], timeoutSeconds: 90, memory: "512MiB"}, async (request) => {
  const uid = requireUid(request);
  const ent = await entitlement(uid);
  const data = asObject(request.data);
  return withAiAccess(uid, "audio", ent, data, async () => {
    const base64 = asText(data.audioBase64, 14000000);
    if (!base64) throw new HttpsError("invalid-argument", "Audio manquant.");
    const bytes = Buffer.from(base64, "base64");
    if (bytes.length > 8 * 1024 * 1024) throw new HttpsError("invalid-argument", "Audio trop volumineux.");
    const form = new FormData();
    form.append("file", new Blob([bytes], {type: asText(request.data?.mimeType, 100) || "audio/mp4"}), "speech.m4a");
    form.append("model", "gpt-4o-mini-transcribe");
    form.append("language", asText(data.locale, 10).toLowerCase() === "en" ? "en" : "fr");
    let response;
    try {
      response = await fetch("https://api.openai.com/v1/audio/transcriptions", {
        method: "POST", headers: {Authorization: `Bearer ${OPENAI_API_KEY.value()}`}, body: form,
      });
    } catch (error) {
      console.error("OpenAI transcription network error", error);
      recordAiHealth({ok: false, reason: "network", message: "Transcription OpenAI injoignable."});
      throw new HttpsError("unavailable", "Impossible de joindre la transcription IA. Réessaie.");
    }
    const raw = await response.text();
    if (!response.ok) throw openAiFailure(response.status, raw, "Transcription indisponible.");
    let payload = {};
    try { payload = JSON.parse(raw); } catch (_) {
      throw new HttpsError("internal", "Réponse de transcription invalide.");
    }
    recordAiHealth({ok: true});
    return {text: asText(payload.text, 12000)};
  });
});

exports.aiSpeech = onCall({region: REGION, secrets: [OPENAI_API_KEY], timeoutSeconds: 60}, async (request) => {
  const uid = requireUid(request);
  const ent = await entitlement(uid);
  const data = asObject(request.data);
  return withAiAccess(uid, "speech", ent, data, async () => {
    let response;
    try {
      response = await fetch("https://api.openai.com/v1/audio/speech", {
        method: "POST",
        headers: {Authorization: `Bearer ${OPENAI_API_KEY.value()}`, "Content-Type": "application/json"},
        body: JSON.stringify({
          model: "gpt-4o-mini-tts",
          voice: asText(request.data?.voice, 40) || "alloy",
          speed: Math.min(4, Math.max(0.25, Number(request.data?.speed) || 1)),
          input: asText(request.data?.text, 2000),
          response_format: "mp3",
        }),
      });
    } catch (error) {
      console.error("OpenAI speech network error", error);
      recordAiHealth({ok: false, reason: "network", message: "Lecture audio OpenAI injoignable."});
      throw new HttpsError("unavailable", "Impossible de joindre la lecture audio. Réessaie.");
    }
    if (!response.ok) {
      const raw = await response.text();
      throw openAiFailure(response.status, raw, "Lecture audio indisponible.");
    }
    const bytes = Buffer.from(await response.arrayBuffer());
    recordAiHealth({ok: true});
    return {audioBase64: bytes.toString("base64")};
  });
});

function purchaseToken(value) {
  const raw = asText(value, 12000);
  if (!raw) return "";
  try {
    const parsed = JSON.parse(raw);
    return asText(parsed.purchaseToken || parsed.token, 5000);
  } catch (_) {
    return raw;
  }
}

async function playGet(path) {
  const auth = new GoogleAuth({scopes: ["https://www.googleapis.com/auth/androidpublisher"]});
  const client = await auth.getClient();
  const headers = await client.getRequestHeaders();
  const response = await fetch(`https://androidpublisher.googleapis.com/androidpublisher/v3/${path}`, {headers});
  const payload = await response.json();
  if (!response.ok) {
    console.error("Google Play verification failed", response.status, JSON.stringify(payload).slice(0, 500));
    throw new HttpsError("failed-precondition", "La vérification Google Play a échoué.");
  }
  return payload;
}

function playSubscriptionDetails(payload, fallbackProductId = "") {
  const lineItems = Array.isArray(payload?.lineItems) ? payload.lineItems : [];
  const expiries = lineItems
    .map((item) => Date.parse(item?.expiryTime || ""))
    .filter((value) => Number.isFinite(value));
  const expiresMs = expiries.length ? Math.max(...expiries) : 0;
  const productId = asText(lineItems.find((item) => item?.productId)?.productId || fallbackProductId, 100);
  const status = asText(payload?.subscriptionState, 120);
  const entitledStates = new Set([
    "SUBSCRIPTION_STATE_ACTIVE",
    "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
    "SUBSCRIPTION_STATE_CANCELED",
  ]);
  const active = entitledStates.has(status) && (!expiresMs || expiresMs > Date.now());
  const autoRenewing = lineItems.some((item) => item?.autoRenewingPlan?.autoRenewEnabled === true);
  const startedMs = Date.parse(payload?.startTime || "");
  return {
    productId,
    active,
    status,
    autoRenewing,
    startedAt: Number.isFinite(startedMs) ? Timestamp.fromMillis(startedMs) : null,
    expiresAt: expiresMs ? Timestamp.fromMillis(expiresMs) : null,
    latestOrderId: asText(payload?.latestOrderId, 200),
    regionCode: asText(payload?.regionCode, 20),
  };
}

async function saveSubscriptionState({uid, tokenHash, fallbackProductId, payload}) {
  const details = playSubscriptionDetails(payload, fallbackProductId);
  const receiptRef = db.collection("_private_purchase_receipts").doc(tokenHash);
  const userRef = db.collection("users").doc(uid);
  await db.runTransaction(async (tx) => {
    const [receipt, user] = await Promise.all([tx.get(receiptRef), tx.get(userRef)]);
    if (receipt.exists && receipt.data()?.uid !== uid) {
      throw new HttpsError("already-exists", "Achat déjà associé.");
    }
    tx.set(receiptRef, {
      uid,
      productId: details.productId || fallbackProductId,
      kind: "subscription",
      active: details.active,
      subscriptionStatus: details.status,
      autoRenewing: details.autoRenewing,
      subscriptionStartedAt: details.startedAt,
      subscriptionExpiresAt: details.expiresAt,
      latestOrderId: details.latestOrderId,
      verifiedAt: FieldValue.serverTimestamp(),
    }, {merge: true});

    const currentHash = asText(user.data()?.entitlements?.purchaseTokenHash, 100);
    const shouldUpdateUser = details.active || !currentHash || currentHash === tokenHash;
    if (shouldUpdateUser) {
      tx.set(userRef, {entitlements: {
        isPremium: details.active,
        activePlan: details.productId === "premium_yearly" ? "PREMIUM_YEARLY" : "PREMIUM_MONTHLY",
        productId: details.productId || fallbackProductId,
        verifiedBy: "google_play",
        subscriptionStatus: details.status,
        autoRenewing: details.autoRenewing,
        subscriptionStartedAt: details.startedAt,
        subscriptionExpiresAt: details.expiresAt,
        latestOrderId: details.latestOrderId,
        regionCode: details.regionCode,
        purchaseTokenHash: tokenHash,
        lastVerifiedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }}, {merge: true});
    }
  });
  return details;
}

exports.verifyAndroidPurchase = onCall({region: REGION, timeoutSeconds: 60}, async (request) => {
  const uid = requireUid(request);
  const productId = asText(request.data?.productId, 100);
  const token = purchaseToken(request.data?.verificationData);
  if (!SUBSCRIPTIONS.has(productId) && !CREDIT_PACKS.has(productId) &&
      !INTENSIVE_EXAM_PRODUCTS.has(productId)) {
    throw new HttpsError("invalid-argument", "Produit inconnu.");
  }
  if (!token) throw new HttpsError("invalid-argument", "Jeton d'achat manquant.");
  const tokenHash = crypto.createHash("sha256").update(token).digest("hex");
  const receiptRef = db.collection("_private_purchase_receipts").doc(tokenHash);
  const userRef = db.collection("users").doc(uid);
  if (SUBSCRIPTIONS.has(productId)) {
    const payload = await playGet(`applications/${PACKAGE_NAME}/purchases/subscriptionsv2/tokens/${encodeURIComponent(token)}`);
    const details = await saveSubscriptionState({uid, tokenHash, fallbackProductId: productId, payload});
    if (!details.active) throw new HttpsError("failed-precondition", "Abonnement non actif.");
    return {verified: true, premium: true, activePlan: productId};
  }
  const payload = await playGet(`applications/${PACKAGE_NAME}/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(token)}`);
  if (Number(payload.purchaseState) !== 0) throw new HttpsError("failed-precondition", "Achat non valide.");
  let delivered = false;
  let grantedPasses = 0;
  await db.runTransaction(async (tx) => {
    const receipt = await tx.get(receiptRef);
    if (receipt.exists) {
      if (receipt.data()?.uid !== uid) throw new HttpsError("already-exists", "Achat déjà associé.");
      return;
    }
    const user = await tx.get(userRef);
    const isIntensivePass = INTENSIVE_EXAM_PRODUCTS.has(productId);
    const amount = isIntensivePass ? INTENSIVE_EXAM_PRODUCTS.get(productId) : CREDIT_PACKS.get(productId);
    const entitlementField = isIntensivePass ? "intensiveExamPasses" : "simCredits";
    const current = Math.max(0, Number(user.data()?.entitlements?.[entitlementField]) || 0);
    tx.create(receiptRef, {
      uid,
      productId,
      kind: isIntensivePass ? "intensive_exam_pass" : "simulation_credits",
      quantity: amount,
      deliveredAt: FieldValue.serverTimestamp(),
    });
    tx.set(userRef, {entitlements: {
      [entitlementField]: current + amount,
      updatedAt: FieldValue.serverTimestamp(),
    }}, {merge: true});
    if (isIntensivePass) {
      const commerceRef = db.collection("_private_commerce_daily").doc(dayKey());
      tx.set(commerceRef, {
        day: dayKey(),
        intensiveExamPassesSold: FieldValue.increment(amount),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      grantedPasses = amount;
    }
    delivered = true;
  });
  return {
    verified: true,
    delivered,
    credits: CREDIT_PACKS.get(productId) ?? 0,
    intensiveExamPasses: grantedPasses,
  };
});

exports.googlePlayRtdn = onMessagePublished({
  topic: "play-billing-rtdn",
  region: REGION,
  timeoutSeconds: 60,
}, async (event) => {
  const message = event.data?.message;
  let notification = message?.json;
  if (!notification && message?.data) {
    try {
      notification = JSON.parse(Buffer.from(message.data, "base64").toString("utf8"));
    } catch (error) {
      console.error("Invalid Google Play RTDN payload", error);
      return;
    }
  }
  const subscription = notification?.subscriptionNotification;
  const token = asText(subscription?.purchaseToken, 5000);
  if (!token) return;
  const tokenHash = crypto.createHash("sha256").update(token).digest("hex");
  const receipt = await db.collection("_private_purchase_receipts").doc(tokenHash).get();
  if (!receipt.exists || !receipt.data()?.uid) {
    console.warn("Google Play RTDN received for an unlinked purchase", tokenHash.slice(0, 12));
    return;
  }
  const payload = await playGet(`applications/${PACKAGE_NAME}/purchases/subscriptionsv2/tokens/${encodeURIComponent(token)}`);
  await saveSubscriptionState({
    uid: receipt.data().uid,
    tokenHash,
    fallbackProductId: receipt.data().productId,
    payload,
  });
});
