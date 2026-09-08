const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { buildSeedDocuments, verifyFirestore, REVIEW_ACCOUNTS, questionMap } = require("../release3_review_accounts.cjs");

class Timestamp {
  constructor(value) { this.value = value; }
  toMillis() { return this.value; }
  static now() { return new Timestamp(1234567890000); }
  static fromMillis(value) { return new Timestamp(value); }
}
const spec = JSON.parse(fs.readFileSync(path.join(__dirname, "../../docs/app-store-release/store-4/review-seed-spec.json"), "utf8"));
const questions = questionMap(spec);
function fixture() {
  const users = Object.fromEntries(Object.entries(REVIEW_ACCOUNTS).map(([role, account]) => [role, { ...account, uid: `fake-${role}`, disabled: false, emailVerified: true }]));
  const documents = buildSeedDocuments(users, spec, questions, Timestamp);
  const db = {
    doc: (documentPath) => ({ path: documentPath }),
    getAll: async (...refs) => refs.map((ref) => ({ ref, exists: documents.has(ref.path), data: () => documents.get(ref.path) })),
  };
  return { users, documents, db, verify: () => verifyFirestore(db, users, spec, questions, Timestamp) };
}

test("complete synthetic seed verifies without Firebase SDK, credentials, or network", async () => {
  const h = fixture();
  assert.ok(h.documents.size > 30);
  await h.verify();
});
for (const role of ["student", "teacher", "volunteer"]) {
  test(`${role} disabled Auth user fails`, async () => {
    const h = fixture(); h.users[role].disabled = true;
    await assert.rejects(h.verify(), /must be enabled/);
  });
  test(`${role} unverified email fails`, async () => {
    const h = fixture(); h.users[role].emailVerified = false;
    await assert.rejects(h.verify(), /email verified/);
  });
  test(`${role} inactive profile fails`, async () => {
    const h = fixture(); h.documents.get(`users/fake-${role}`).accountStatus = "suspended";
    await assert.rejects(h.verify(), /accountStatus/);
  });
}
test("every generated fixture document is required, including progress and replies", async () => {
  const paths = [...fixture().documents.keys()];
  for (const documentPath of paths) {
    const h = fixture(); h.documents.delete(documentPath);
    await assert.rejects(h.verify(), /Missing review seed document/, documentPath);
  }
});
test("existing empty and wrong-owner documents cannot pass readiness", async () => {
  const h = fixture();
  h.documents.set(`classes/${spec.scope.classId}/students/fake-student/skillMastery/APP-REVIEW-MASTERY-01`, {});
  await assert.rejects(h.verify(), /Seed field mismatch/);
  const other = fixture();
  other.documents.get(`classes/${spec.scope.classId}`).ownerTeacherUid = "other";
  await assert.rejects(other.verify(), /ownerTeacherUid/);
});
