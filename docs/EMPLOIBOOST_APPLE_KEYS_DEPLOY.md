# EmploiBoost iOS — Secure Apple purchase setup (NO Codemagic build)

This branch is **not production**. Do not merge or deploy until the checks below are complete.

## Known app identity

- Firebase project: `emploiboost`
- Bundle ID: `com.emploiboost.emploiboost`
- App Store Connect Apple ID: `6811853468`
- Cloud Functions region: `europe-west1`
- Backend sources: `functions/index.js`, `functions/apple_iap.js`
- iOS app source patch: `usasin/emploiboost-ios` draft PR #1

## Step 1 — App Store Connect

In App Store Connect, open **Users and Access > Integrations > In-App Purchase**.
Create an **App Store Server API In-App Purchase key** and note its Key ID and Issuer ID. Keep the downloaded `.p8` **offline and private**. Do **not** paste/upload its contents to a chat, GitHub, or Codemagic.

This key is **different** from the Apple Sign in private key and the Codemagic App Store Connect upload key.

In **Monetization > Subscriptions**, create a subscription group with:
- `emploiboost_premium_monthly`, auto-renewable, 1 month.
- `emploiboost_premium_yearly`, auto-renewable, 1 year.

In **In-App Purchases**, create `emploiboost_intensive_exam_pass` as a **consumable** if the paid intensive exam is enabled in the iOS UI.
These Apple IDs are intentionally different from the existing Android IDs `premium_monthly`, `premium_yearly` and `intensive_exam_pass`. Product identifiers already assigned in Apple cannot be reused. Supply language metadata, prices, review notes and review screenshots. Submit the first products **with the same first app-version submission**.

Confirm paid-app agreement/banking/tax information is active and Apple Sign In is configured for `com.emploiboost.emploiboost` in the Apple Developer portal and Firebase Authentication for project `emploiboost`.

## Step 2 — Firebase secrets (private account owner/administrator action)

Only in a trusted local terminal or Google Cloud Shell, with the Firebase CLI authenticated as the owner:

```sh
firebase use emploiboost
firebase functions:secrets:set APPLE_IAP_PRIVATE_KEY --data-file "/PRIVATE/LOCATION/SubscriptionKey_KEYID.p8" --project emploiboost
firebase functions:secrets:set APPLE_IAP_KEY_ID --project emploiboost
firebase functions:secrets:set APPLE_IAP_ISSUER_ID --project emploiboost
```

Replace the example `.p8` pathname with the **actual local private filepath**; never put this key in the repository or command-line arguments. The last two commands should prompt interactively for values.

## Step 3 — server code review, lockfile and isolated deploy

GitHub Actions on the branch runs:
- `npm install --package-lock-only --ignore-scripts` to synchronize the Apple SDK dependency lock.
- `npm ci --ignore-scripts`, `npm run lint`, `npm run test:apple`.
- Writes the lockfile back only to the **draft branch** when it changes.

After code review and Sandbox setup, merge the server PR. Then from the actual checked-out backend, **deploy ONLY** the two new callable functions:

```sh
cd functions
npm ci
cd ..
firebase deploy --only "functions:getApplePurchaseAccount,functions:verifyApplePurchase" --project emploiboost
```

This does NOT start Codemagic and does not redeploy all Cloud Functions. Verify IAM and secret bindings are effective.

## Step 4 — preflight before one iOS build

- Firebase Apple sign-in provider works with Hide My Email on a real iOS device.
- Apple provisioning profile contains `com.apple.developer.applesignin`.
- `verifyApplePurchase` and `getApplePurchaseAccount` are deployed in `europe-west1`.
- StoreKit products resolve correctly for a Sandbox tester.
- Archive-source patch executes on the restored EmploiBoost source; Flutter analyzer and tests pass; signed IPA entitlement checker passes.
- Validate monthly/yearly purchase, one-time pass, restore, renewal, expiry, refund/revocation and cross-account replay.
- Do not grant Premium based on unverified client receipts.

**Only then** launch one carefully validated iOS Codemagic release build.
Do not present mocked GitHub Actions unit tests as proof that real App Store Sandbox billing works.

## Further production billing task

Configure and validate App Store Server Notifications V2 or periodic revalidation so expiration, refunds, and renewal changes are reflected even when a user does not open the paywall.
