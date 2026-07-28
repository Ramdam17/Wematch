// RTDB security-rules tests (plan 1.2d) — run inside `firebase emulators:exec`.
import { test, before, after } from "node:test";
import { readFileSync } from "node:fs";
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from "@firebase/rules-unit-testing";

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "wematch-rules-test",
    database: {
      rules: readFileSync(new URL("../database.rules.json", import.meta.url), "utf8"),
    },
  });
});

after(async () => {
  await env.cleanup();
});

const VALID_HR = {
  username: "cosmic_panda0042",
  currentHR: 72,
  previousHR: 70,
  colorSlot: 6,
  timestamp: 1721000000,
};

test("unauthenticated clients cannot read rooms", async () => {
  const db = env.unauthenticatedContext().database();
  await assertFails(db.ref("rooms/room1").get());
});

test("authenticated clients can read a room", async () => {
  const db = env.authenticatedContext("uidA").database();
  await assertSucceeds(db.ref("rooms/room1").get());
});

test("a user can write their own HR node with a valid payload", async () => {
  const db = env.authenticatedContext("uidA").database();
  await assertSucceeds(db.ref("rooms/room1/users/uidA").set(VALID_HR));
});

test("a user cannot write another user's HR node", async () => {
  const db = env.authenticatedContext("uidA").database();
  await assertFails(db.ref("rooms/room1/users/uidB").set(VALID_HR));
});

test("HR outside 0-250 is rejected", async () => {
  const db = env.authenticatedContext("uidA").database();
  await assertFails(
    db.ref("rooms/room1/users/uidA").set({ ...VALID_HR, currentHR: 300 })
  );
});

test("a colorSlot outside the palette range is rejected", async () => {
  const db = env.authenticatedContext("uidA").database();
  await assertFails(
    db.ref("rooms/room1/users/uidA").set({ ...VALID_HR, colorSlot: 20 })
  );
  await assertFails(
    db.ref("rooms/room1/users/uidA").set({ ...VALID_HR, colorSlot: -1 })
  );
});

test("a non-integer or non-numeric colorSlot is rejected", async () => {
  const db = env.authenticatedContext("uidA").database();
  await assertFails(
    db.ref("rooms/room1/users/uidA").set({ ...VALID_HR, colorSlot: 6.5 })
  );
  await assertFails(
    db.ref("rooms/room1/users/uidA").set({ ...VALID_HR, colorSlot: "FF6B9D" })
  );
});

test("extra fields on the HR node are rejected", async () => {
  const db = env.authenticatedContext("uidA").database();
  await assertFails(
    db.ref("rooms/room1/users/uidA").set({ ...VALID_HR, injected: "nope" })
  );
});

test("temp-room index is readable only by its owner", async () => {
  const owner = env.authenticatedContext("uidA").database();
  const other = env.authenticatedContext("uidB").database();
  await assertSucceeds(owner.ref("tempRooms/uidA").get());
  await assertFails(other.ref("tempRooms/uidA").get());
});

test("unknown top-level paths are denied even when authenticated", async () => {
  const db = env.authenticatedContext("uidA").database();
  await assertFails(db.ref("secrets/x").set({ a: 1 }));
});
