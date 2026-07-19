# Step 1.1 — Firebase console steps (Rémy, ~5 min)

Code-side work (FirebaseAuth product, SIWA federation, rules, emulator tests) is handled
by Claude. These console/portal steps cannot be scripted:

1. **Firebase console** → project Wematch → **Authentication → Sign-in method →
   Add new provider → Apple** → Enable. (Leave Services ID / OAuth fields empty —
   not needed for native iOS Sign in with Apple.)
2. **Authentication → Settings → User actions**: leave "Email enumeration protection"
   on (default).
3. **Realtime Database → Rules**: after Claude deploys via CLI, verify the console
   shows the versioned rules (they must match `firebase/database.rules.json`).
   Deploy command (Claude runs it, needs a one-time `npx firebase-tools login` by you):
   ```bash
   npx firebase-tools login
   npx firebase-tools deploy --only database
   ```
4. Nothing to do in the Apple Developer portal: the app already has the
   Sign in with Apple capability.

## Verification (after code + console are both done)

- Fresh install → Sign in with Apple → Firebase console shows a new user under
  Authentication with provider `apple.com`.
- `curl 'https://<db>.firebaseio.com/rooms.json'` → `"error" : "Permission denied"`.

## Rollout note

Enabling the rules **breaks all unauthenticated clients** (i.e., every existing install).
Acceptable: no external users yet (nothing was ever distributed), old RTDB data is
disposable by design (ephemeral HR). Wipe `rooms/` and `tempRooms/` at switch time.
