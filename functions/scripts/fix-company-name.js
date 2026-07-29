// One-time correction: renames the company created by migrate-add-default-company.js
// (which was accidentally run with the literal placeholder text as the name) to its
// real name. Only touches the `name` field on companies/{companyId} — nothing else.
//
// Usage: node fix-company-name.js <companyId> "<Real Name>"

const admin = require("firebase-admin");
const path = require("path");

const companyId = process.argv[2];
const newName = process.argv[3];
if (!companyId || !newName) {
  console.error("Usage: node fix-company-name.js <companyId> \"<Real Name>\"");
  process.exit(1);
}

const serviceAccount = require(path.join(__dirname, "serviceAccountKey.json"));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function main() {
  const ref = db.collection("companies").doc(companyId);
  const doc = await ref.get();
  if (!doc.exists) {
    console.error(`No company found with id ${companyId}`);
    process.exit(1);
  }
  console.log(`Current name: "${doc.data().name}"`);
  await ref.update({ name: newName });
  console.log(`Updated to: "${newName}"`);
}

main().then(() => process.exit(0)).catch((err) => {
  console.error(err);
  process.exit(1);
});
