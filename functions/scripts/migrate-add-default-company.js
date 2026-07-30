// One-time migration: run BEFORE deploying firestore.rules.
//
// Model: one Firebase Auth account maps to exactly one company (no shared companies,
// no join codes — see firestore.rules). For every existing Firebase Auth user that has
// no `users/{uid}` profile yet, this creates a dedicated `companies/{id}` doc owned by
// that user and the matching `users/{uid}` profile pointing at it.
//
// Usage:
//   1. Download a service account key: Firebase Console -> Project Settings ->
//      Service Accounts -> Generate new private key. Save it as serviceAccountKey.json
//      next to this script (functions/scripts/) — DO NOT commit this file.
//   2. cd functions/scripts && node migrate-add-default-company.js
//
// Safe to re-run: users that already have a `users/{uid}` profile are left untouched.
//
// Note: this does NOT touch `inspections/{id}` documents. Under the old shared-company
// model, every inspection could be backfilled onto one company; under one-company-per-user
// there is no way to infer which user's company a pre-existing orphaned inspection belongs
// to, so that assignment must be done by hand (or with a separate, targeted script) if any
// orphaned inspections remain.

const admin = require("firebase-admin");
const path = require("path");

const serviceAccount = require(path.join(__dirname, "serviceAccountKey.json"));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();
const auth = admin.auth();

async function main() {
  let usersCreated = 0;
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    for (const user of page.users) {
      const profileRef = db.collection("users").doc(user.uid);
      const profileDoc = await profileRef.get();
      if (profileDoc.exists) continue;

      const companyRef = db.collection("companies").doc();
      const companyName = user.displayName || user.email || user.uid;
      await companyRef.set({
        id: companyRef.id,
        name: companyName,
        ownerId: user.uid,
        createdAt: new Date().toISOString(),
      });
      await profileRef.set({
        id: user.uid,
        companyId: companyRef.id,
        role: "owner",
        displayName: user.displayName || user.email || "",
      });
      usersCreated++;
      console.log(`Provisioned company "${companyName}" (${companyRef.id}) for user ${user.uid}.`);
    }
    pageToken = page.pageToken;
  } while (pageToken);
  console.log(`\nDone. Provisioned ${usersCreated} user/company pair(s).`);
  console.log("Next steps:");
  console.log("1. Verify the data in Firebase Console.");
  console.log("2. firebase deploy --only firestore:indexes  (wait for the index to finish building)");
  console.log("3. firebase deploy --only firestore:rules");
}

main().then(() => process.exit(0)).catch((err) => {
  console.error(err);
  process.exit(1);
});
