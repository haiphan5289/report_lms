// One-time migration: run BEFORE deploying firestore.rules.
//
// Every inspection and every existing Firebase Auth user currently has no `companyId`.
// Once firestore.rules is deployed, any document missing `companyId` becomes invisible
// to everyone (the security rules require an exact companyId match). This script backfills
// a single "default company" — representing the business's own existing data — onto:
//   1. A new `companies/{id}` doc + matching `joinCodes/{code}` doc.
//   2. Every existing Firebase Auth user -> `users/{uid}` profile pointing at that company.
//   3. Every `inspections/{id}` document missing `companyId`.
//
// Usage:
//   1. Download a service account key: Firebase Console -> Project Settings ->
//      Service Accounts -> Generate new private key. Save it as serviceAccountKey.json
//      next to this script (functions/scripts/) — DO NOT commit this file.
//   2. cd functions/scripts && node migrate-add-default-company.js "Ten Cong Ty Cua Ban"
//
// Safe to re-run: inspections that already have a companyId are left untouched, and the
// script exits early if a company with the exact given name already exists.

const admin = require("firebase-admin");
const path = require("path");

const companyName = process.argv[2];
if (!companyName) {
  console.error("Usage: node migrate-add-default-company.js \"<Ten Cong Ty>\"");
  process.exit(1);
}

const serviceAccount = require(path.join(__dirname, "serviceAccountKey.json"));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();
const auth = admin.auth();

function generateJoinCode() {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let code = "";
  for (let i = 0; i < 6; i++) {
    code += alphabet[Math.floor(Math.random() * alphabet.length)];
  }
  return code;
}

async function main() {
  const existing = await db.collection("companies").where("name", "==", companyName).limit(1).get();
  let companyId;
  if (!existing.empty) {
    companyId = existing.docs[0].id;
    console.log(`Company "${companyName}" already exists (${companyId}), reusing it.`);
  } else {
    const joinCode = generateJoinCode();
    const companyRef = db.collection("companies").doc();
    companyId = companyRef.id;
    await companyRef.set({
      id: companyId,
      name: companyName,
      joinCode,
      ownerId: "migration",
      createdAt: new Date().toISOString(),
    });
    await db.collection("joinCodes").doc(joinCode).set({ companyId });
    console.log(`Created company "${companyName}" (${companyId}), join code: ${joinCode}`);
  }

  // 2. Backfill every existing Firebase Auth user's profile
  let usersUpdated = 0;
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    for (const user of page.users) {
      const profileRef = db.collection("users").doc(user.uid);
      const profileDoc = await profileRef.get();
      if (profileDoc.exists) continue;
      await profileRef.set({
        id: user.uid,
        companyId,
        role: "member",
        displayName: user.displayName || user.email || "",
      });
      usersUpdated++;
    }
    pageToken = page.pageToken;
  } while (pageToken);
  console.log(`Backfilled ${usersUpdated} user profile(s).`);

  // 3. Backfill every inspection missing companyId
  const snapshot = await db.collection("inspections").get();
  let batch = db.batch();
  let batchCount = 0;
  let inspectionsUpdated = 0;
  for (const doc of snapshot.docs) {
    if (doc.data().companyId) continue;
    batch.update(doc.ref, { companyId });
    batchCount++;
    inspectionsUpdated++;
    if (batchCount === 400) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }
  if (batchCount > 0) await batch.commit();
  console.log(`Backfilled ${inspectionsUpdated} inspection(s).`);

  console.log("\nDone. Next steps:");
  console.log("1. Verify the data in Firebase Console.");
  console.log("2. firebase deploy --only firestore:indexes  (wait for the index to finish building)");
  console.log("3. firebase deploy --only firestore:rules");
}

main().then(() => process.exit(0)).catch((err) => {
  console.error(err);
  process.exit(1);
});
