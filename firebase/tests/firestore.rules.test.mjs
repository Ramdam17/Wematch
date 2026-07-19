// Firestore security-rules tests (plan 1.2d) — run inside `firebase emulators:exec`.
import { test, before, after, beforeEach } from "node:test";
import { readFileSync } from "node:fs";
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc, updateDoc, deleteDoc } from "firebase/firestore";

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "wematch-rules-test",
    firestore: {
      rules: readFileSync(new URL("../firestore.rules", import.meta.url), "utf8"),
    },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

const db = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

// Seed data bypassing rules.
const seed = (fn) => env.withSecurityRulesDisabled((ctx) => fn(ctx.firestore()));

// ── Profiles & usernames ─────────────────────────────────────────────────

test("profiles: signed-in users read, only the owner writes", async () => {
  await seed((f) => setDoc(doc(f, "users/uidA"), { username: "cosmic_panda0042" }));
  await assertFails(getDoc(doc(anon(), "users/uidA")));
  await assertSucceeds(getDoc(doc(db("uidB"), "users/uidA")));
  await assertFails(updateDoc(doc(db("uidB"), "users/uidA"), { username: "hack" }));
  await assertSucceeds(updateDoc(doc(db("uidA"), "users/uidA"), { username: "new_name0001" }));
});

test("usernames: cannot steal a foreign reservation", async () => {
  await seed((f) => setDoc(doc(f, "usernames/cosmic_panda0042"), { uid: "uidA" }));
  await assertFails(setDoc(doc(db("uidB"), "usernames/cosmic_panda0042"), { uid: "uidB" }));
  await assertSucceeds(setDoc(doc(db("uidB"), "usernames/brave_otter0007"), { uid: "uidB" }));
});

// ── Inbox: the recipient-semantics core ──────────────────────────────────

const message = (senderID) => ({
  type: "friendRequest",
  senderID,
  payload: { requestID: "r1" },
  isRead: false,
  createdAt: new Date(),
});

test("inbox: any signed-in user can deliver, only recipient reads", async () => {
  await assertSucceeds(
    setDoc(doc(db("uidA"), "inbox/uidB/messages/m1"), message("uidA"))
  );
  await assertSucceeds(getDoc(doc(db("uidB"), "inbox/uidB/messages/m1")));
  await assertFails(getDoc(doc(db("uidA"), "inbox/uidB/messages/m1")));
});

test("inbox: senderID cannot be spoofed", async () => {
  await assertFails(
    setDoc(doc(db("uidA"), "inbox/uidB/messages/m1"), message("someone_else"))
  );
});

test("inbox: recipient may only toggle isRead", async () => {
  await seed((f) => setDoc(doc(f, "inbox/uidB/messages/m1"), message("uidA")));
  await assertSucceeds(updateDoc(doc(db("uidB"), "inbox/uidB/messages/m1"), { isRead: true }));
  await assertFails(updateDoc(doc(db("uidB"), "inbox/uidB/messages/m1"), { type: "groupDeleted" }));
  await assertSucceeds(deleteDoc(doc(db("uidB"), "inbox/uidB/messages/m1")));
});

// ── Friend requests ──────────────────────────────────────────────────────

const request = { senderID: "uidA", receiverID: "uidB", status: "pending" };

test("friendRequests: only sender/receiver can read; third parties cannot", async () => {
  await seed((f) => setDoc(doc(f, "friendRequests/r1"), request));
  await assertSucceeds(getDoc(doc(db("uidA"), "friendRequests/r1")));
  await assertSucceeds(getDoc(doc(db("uidB"), "friendRequests/r1")));
  await assertFails(getDoc(doc(db("uidC"), "friendRequests/r1")));
});

test("friendRequests: only the receiver can change status", async () => {
  await seed((f) => setDoc(doc(f, "friendRequests/r1"), request));
  await assertSucceeds(updateDoc(doc(db("uidB"), "friendRequests/r1"), { status: "accepted" }));
  await assertFails(updateDoc(doc(db("uidA"), "friendRequests/r1"), { status: "accepted" }));
});

// ── Groups ───────────────────────────────────────────────────────────────

const group = { name: "PPSP", code: "ABC123", adminID: "uidA", memberIDs: ["uidB"] };

test("groups: members may only touch memberIDs; admin may touch anything", async () => {
  await seed((f) => setDoc(doc(f, "groups/g1"), group));
  await assertSucceeds(updateDoc(doc(db("uidB"), "groups/g1"), { memberIDs: [] }));
  await assertFails(updateDoc(doc(db("uidB"), "groups/g1"), { name: "hacked" }));
  await assertSucceeds(updateDoc(doc(db("uidA"), "groups/g1"), { name: "PPSP lab" }));
});

test("groups: non-members cannot update, only admin deletes", async () => {
  await seed((f) => setDoc(doc(f, "groups/g1"), group));
  await assertFails(updateDoc(doc(db("uidC"), "groups/g1"), { memberIDs: ["uidC"] }));
  await assertFails(deleteDoc(doc(db("uidB"), "groups/g1")));
  await assertSucceeds(deleteDoc(doc(db("uidA"), "groups/g1")));
});
