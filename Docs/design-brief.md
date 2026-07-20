# Design Brief — Wematch

> Generated: 2026-07-19
> Status: **Validated** (Rémy, 2026-07-19) — all six arbitrations settled, see
> § Decisions (settled). ONE divergence from the consultant's recommendation:
> **Dark Cosmic is a v1 selectable theme** (not v2) — § Mode reflects this.
> Plan reference: `Docs/plans/plan-20260715-reboot.md` step 2.1 → feeds 2.2 (Figma library + 6 core screens).
> Audit reference: `Docs/AUDIT-20260715.md` (findings A7, G1–G5 are directly addressed here).

---

## Identity

**Wematch is a scientific instrument for human connection, dressed as a joyful toy.**

The product's core is a rigorous data visualization: each participant's heart is a point on a
2D phase plot (X = previous HR, Y = current HR, 40–200 BPM), and "sync" is a measured event
(Euclidean distance < 5 BPM, cliques found by Bron-Kerbosch). Wrapped around that scientific
core is a warm, luminous, *rainbow-unicorn* skin built on Apple's **Liquid Glass** (iOS 26).

The whole design lives in the tension between those two things — **precision and play** — and
the brief's job is to keep them in balance: the plot must always read as *data you can trust*,
while everything around it should feel *delightful, alive, and a little magical*. The moment two
hearts lock together is the product's climax and gets the design budget to match.

**Aesthetic name:** Rainbow Unicorn × Liquid Glass.
**One-liner for the team:** *"Serious heart-rate science that feels like sparkles."*

### Design precedents referenced
- **Apple Liquid Glass (iOS 26)** — the substrate: translucency, depth, vibrancy, dynamic
  light. We are HIG-compliant Liquid Glass first, and add brand flavor *on top*, not against it.
- **Not Boring apps (Andy Allen)** — tactile, physics-y delight and playful color used with
  restraint over a functional core. Model for "joyful, never garish."
- **Gentler Streak / Gentler Mania (Filip Vabroušek)** — health/heart data rendered warmly and
  humanely, not clinically. Model for the tone around biometrics.
- **Shirley Wu / editorial data-viz** — the discipline that a beautiful chart is still a *chart*:
  every mark is legible and meaningful. Model for the plot itself.
- **Oak / Calm (breathing, sync-of-two)** — the intimate "two things coming into phase" moment.
  Model for the emotional register of the sync climax.

---

## Design Principles

1. **Data first, delight second.** The plot always reads as data. Effects (stars, halos, blooms)
   enhance the sync moment but never occlude the markers or the axes. If a decoration hurts
   legibility, it loses.
2. **Joyful, never garish.** Pastel and sparkle are the vocabulary, but the resting state is
   calm. Saturation and motion are *spent* on meaningful events, not sprayed everywhere.
3. **The sync moment is sacred.** It is the product's climax; it earns the richest motion,
   color, and haptics in the app.
4. **Alive, not busy.** Motion is organic (breathing, floating, heartbeat), spring-driven, and
   subtle at rest. Nothing loops forever just to look active.
5. **Accessible by construction.** Contrast, Reduce Motion, Reduce Transparency, Dynamic Type
   and VoiceOver are token- and component-level requirements — not a retrofit. This principle
   exists because the audit found the opposite (G1–G3); the design system must make the
   accessible path the default path.
6. **Watch is a glance; phone is the canvas.** The Watch shows a distilled, high-contrast,
   glanceable version and leans on haptics; the iPhone carries the full experience.
7. **Honest states.** Loading, empty, and error states are designed for every data surface —
   mirroring the code's "no silent failure" philosophy (a genuinely-empty room and a
   permission-denied room must look different).

---

## Project Overview

Wematch is an iOS 26+ / watchOS 26+ app for real-time heart-rate synchronization between people
in a shared "room." Each participant appears as an animated heart marker on a shared 2D plot;
when two or more hearts come within 5 BPM (Euclidean distance in plot space), visual and haptic
"sync" effects fire — a shared colored circle, a star burst, a heartbeat haptic on both iPhone
and Watch. Around this live experience sit lightweight social features: Groups, Friends, an
Inbox for invites/requests, and Settings.

It is a **playful, social experience for a research lab** — not a medical device and not a
clinical tool. First audience: Rémy's colleagues at CHU Sainte-Justine (PPSP lab). That framing
matters: the app can be warm, whimsical, and a little irreverent, while still being trustworthy
about the numbers it shows.

---

## Target Users

- **Primary:** Rémy's neuroscience-lab colleagues — technically literate, curious, comfortable
  with data, using the app socially/for fun and to feel the novelty of "cardiac connection."
- **Secondary (v-next):** friends-of-colleagues and small social groups the primary users invite;
  same device profile (iPhone + Apple Watch owners).
- **Usage context:** short, co-located, social sessions — two or more people in the same room
  (a lab, an office, a café) glancing between their phone/Watch and each other, often standing
  or moving. Sessions are minutes long, sometimes with a Watch on the wrist and the phone in the
  other hand. Not sustained desk use; not solo deep-focus.

---

## Target Platforms

| Platform | Priority | Notes |
|----------|----------|-------|
| iPhone (iOS 26+) | **Primary** | Portrait only. The full experience and the design canvas. All 6 core screens designed here first. |
| Apple Watch (watchOS 26+) | **Secondary** | Passive display of the same plot + HUD; primary channel for the sync *haptic*. Distilled, high-contrast, glanceable. Keep the "Watch = dumb display, iPhone computes" architecture. |
| iPad | **Out of scope (v1)** | Recommend `TARGETED_DEVICE_FAMILY = 1` (iPhone only). Zero adaptive code exists today (audit G5); shipping an unadapted iPad build risks a poor first impression / review friction. Revisit in v2 with a purpose-designed large-canvas plot. |
| Mac / Vision Pro | Out of scope | Not planned. |

---

## Design Philosophy

- **Tone:** Warm, playful, luminous — with quiet scientific credibility underneath. "Sparkles
  that respect the data."
- **Density:** Deliberately mixed. The social surfaces (Groups, Friends, Inbox, Settings) are
  **calm and minimal** — one clear thing per row, generous whitespace, glass cards. The Room is
  **information-rich** — a live scientific plot with a compact stats HUD. This split is
  intentional; the tension is resolved by *context* (chrome is minimal so the data can be dense).
- **Motion:** Expressive but earned. Organic, spring-based, breathing motion; calm at rest;
  the sync moment is the one place motion is allowed to be exuberant. Full Reduce-Motion path.
- **Personality:** A precise instrument that feels alive. The UI is mostly an invisible, HIG-
  correct tool — except the Room, which is a distinctive, characterful *experience*.

---

## Visual Identity

### Base identity
Custom identity ("Rainbow Unicorn") layered on Apple's **Liquid Glass**, *not* the beautiful-viz
default (no violet/amber/emerald dark dashboard). Everything must be expressible as Liquid Glass
components in SwiftUI (the `apple-liquid-glass` skill governs implementation).

### Mode — DECIDED 2026-07-19: Dark Cosmic is a v1 SELECTABLE theme
- **Pastel Light remains the canonical/default theme**; all 6 core screens are composed in
  Pastel Light first.
- **Dark Cosmic ships in v1 as a user-selectable theme** (Rémy's call, overriding the
  consultant's v2 recommendation): deep-space backgrounds, vivid neons, white text —
  the v1 spec's original vision.
- Consequences for plan 2.2 (accepted scope increase):
  - every token is a **light+dark pair from birth**, verified AA in BOTH themes;
  - the 6 core screens get a Dark Cosmic variant pass after the Pastel Light comps
    are validated (light first, dark second — not in parallel);
  - a theme toggle lands in Settings (persisted; follows-system as third option);
  - visual QA (plan 2.3 definition of done) covers both themes.

### Color system (with accessibility commitments)

**Accessibility rule (non-negotiable, applies to every token below):**
- Body/label text and essential icons: **WCAG AA ≥ 4.5:1** against their background.
- Large text (≥ 24pt, or ≥ 19pt bold) and meaningful graphical boundaries (heart markers vs
  background, plot gridlines, badge outlines): **≥ 3:1**.
- Every semantic color is defined as a **tint pair** `(fill, onFill)` where `onFill` is chosen
  to pass the rule against `fill`. Contrast is fixed by choosing the *text/icon* color, so the
  pastel fills stay soft — we do **not** sacrifice pastel fidelity to fix contrast.
- Ratios below are design targets; each must be verified with a contrast plugin at Figma token
  creation (this is the plan 2.2 acceptance gate for G2).

**Brand / background (Pastel Light | Dark placeholder):**

| Token | Light | Dark (v2 placeholder) | Role |
|-------|-------|------------------------|------|
| `bg/0` | `#FDF2F8` | `#1A0B20` | Background gradient stop 1 |
| `bg/1` | `#F3E8FF` | `#16102C` | Background gradient stop 2 |
| `bg/2` | `#EDE9FE` | `#12102A` | Background gradient stop 3 |
| `text/primary` | `#1F1F1F` | `#F5F5F5` | Primary text (AA+ on all bg stops) |
| `text/secondary` | `#4B5563` | `#9CA3AF` | Secondary text — **darkened from the current `#6B7280`** to guarantee ≥4.5:1 on pastel bg |
| `glass/border` | `white @ 60%` | `white @ 15%` | Glass card edge |

**Decorative brand gradient (NOT for use behind small text):**
- `brand/gradient` = `#FF6B9D → #C084FC → #67E8F9` (pink → purple → cyan).
- **Usage:** backgrounds, the hero wordmark, the sync bloom, decorative strokes — **never** as a
  fill behind body-size text. (The cyan stop fails contrast with both white and dark text.)

**Primary action (the fix for buttons):**
- `action/primary/fill` = a **deepened** gradient, e.g. candidate `#DB2777 → #7C3AED`
  (deep pink → violet), `action/primary/on` = `#FFFFFF`, deepened until white text ≥ 4.5:1
  (verify at token creation). The bright `brand/gradient` is reserved for decoration; tappable
  primary buttons use the deep gradient so their label passes AA. This resolves the current
  white-on-bright-gradient contrast failure at the token level.
- `action/secondary` = glass/tinted capsule with `text/primary` label.

**Semantic tint pairs (badges, states — replaces the failing white-on-pastel `StatusBadge`):**

| Semantic | `fill` (soft) | `onFill` (saturated/dark) | Target | Replaces |
|----------|---------------|----------------------------|--------|----------|
| Pending / warning | `#FEF3C7` | `#92400E` | ~7:1 | orange pill, white text (~1.5:1) |
| Friends / info | `#CFFAFE` | `#155E75` | ~5:1 | cyan pill, white text |
| Admin / accent | `#F3E8FF` | `#6B21A8` | ~7:1 | purple pill, white text |
| Member / success | `#DCFCE7` | `#166534` | ~6:1 | green pill, white text |
| Error / destructive | `#FEE2E2` | `#991B1B` | ~7:1 | (new) |

> **This is the single most important accessibility change in the system.** The current
> `StatusBadge` (`.foregroundStyle(.white)` on a saturated pastel fill) fails AA at ~1.5:1 across
> 7 sites (G2). The tint-pair pattern keeps the joyful soft pill *and* passes AA by darkening the
> text, not the fill. `Increase Contrast` accessibility setting → bump `onFill` one step darker.

**Heart palette (data encoding):** keep the 20-color rainbow palette
(`#FF6B9D, #C084FC, #67E8F9, #F472B6, …`) as **categorical identity colors** for participants.
Requirements: (1) each heart marker must clear **≥ 3:1** against the pastel background as a
graphical object (add a subtle darker outline/glow to the lighter hues so pale yellows/mints
don't vanish); (2) color is *never* the only channel — pair with the participant's animal
label/initial for VoiceOver and color-blind users; (3) the shared sync circle uses the members'
shared hue but must remain distinguishable via its stroke style (solid = hard clique, dashed =
soft cluster — already the pattern).

### Typography
- **Display / headings:** SF Rounded (`Font.system(design: .rounded)`), bold/semibold — the
  playful, friendly voice. Keep the existing `WematchTypography` scale (largeTitle → caption2).
- **Body / labels:** SF Pro (system default), regular/medium — neutral and legible.
- **Numeric data (BPM, chain length, synced count):** system font with **tabular / monospaced
  digits** so live-updating numbers don't jitter. This is a data-viz requirement, not a style.
- **Dynamic Type:** supported everywhere via `@ScaledMetric` / text styles. **Exception:** the
  plot and Room HUD use intentionally fixed sizes (data viz, not chrome) — these must carry
  explicit accessibility elements/values, generalizing the exemplary `RoomView` HUD a11y pattern
  (the audit's designated template) to the Watch and to any other fixed-size surface.
- No custom/brand typeface in v1 (out of scope).

### Shape & elevation
- **Corner radius:** rounded and friendly — `sm 8 / md 16 / lg 24` (keep current tokens).
- **Shadow / elevation:** soft, diffuse glass glow (low-opacity, large-blur, brand-tinted where
  appropriate) — never hard drop shadows. Under Reduce Transparency, glass surfaces become solid
  tinted fills using the same token colors, elevation conveyed by a 1px border + subtle shadow.

---

## Motion Language

**Personality:** organic and spring-driven — *breathing, floating, heartbeat*, never mechanical
or linear. Calm at rest; exuberant only at the sync climax.

**Standard (motion enabled):**
- Background: slow gradient "breathing" crossfade (~6s) + sparse floating particles (already
  built; must respect scenePhase — no work when inactive/background, per F3).
- Heart markers: travel between plot positions along **cubic Bézier curves** (the scientific
  animation core), spring-eased.
- Transitions: spring, medium stiffness; sheets and navigation use system defaults.
- Sync formation (per new edge only, not continuously): shared color **halo bloom** + short
  **star burst** + a brief saturation lift that settles back within ~1s.

**The sync moment — recommended emotional register:** *delighted recognition, a warm crescendo —
not a slot-machine jackpot.* Anticipation as two hearts approach → at lock, a shared halo blooms
outward from the midpoint, a soft star burst, and a **double-tap "heartbeat" haptic** on both
iPhone and Watch → then the effect settles into a calm shared circle that persists while synced.
The feeling target is the small joy of unexpected connection with another person. Constraint from
Principle 1: the bloom must not hide the two markers or the axes — you should always be able to
*see why* they synced (their proximity on the plot).

**Reduce Motion strategy (currently zero support — audit G3, this is a hard requirement):**
Provide a complete alternate path keyed on `accessibilityReduceMotion`:

| Element | Standard | Reduce Motion |
|---------|----------|---------------|
| Background gradient | breathing crossfade loop | static gradient (no loop) |
| Floating particles | continuous spawn/float | hidden (or a single, static, very-low-opacity sparkle field) |
| Heart position update | Bézier travel animation | **snap to new position** with a short opacity crossfade (position is data — it must still update, just without travel) |
| Sync formation | halo bloom + star burst | a **static halo/ring that fades once** (no burst, no drift) |
| Star lifecycle | drift + `repeatForever` blur | no drifting stars |
| Any `repeatForever` | allowed | **forbidden** |
| Haptics | on | **retained** (haptics are not "motion" and remain the accessible climax channel) |

**Reduce Transparency:** glass/material surfaces → solid tinted surfaces (same token colors),
elevation via border + subtle shadow. **Bold Text / Increase Contrast:** honor system settings;
Increase Contrast bumps semantic `onFill` and secondary text one step darker.

---

## Component Inventory (Figma library — plan 2.2)

Build the library **from the existing code components first**, tokenizing and fixing contrast at
the token level, then compose the screens.

**Foundations (tokens):**
- Color tokens: brand/background, `action/*`, semantic tint pairs, heart palette — each with
  Light + Dark pairs and documented contrast ratios.
- Typography styles (map 1:1 to `WematchTypography`), incl. a tabular-digit numeric style.
- Spacing (8/16/24), radius (8/16/24), elevation/glow tokens, glass material + its
  Reduce-Transparency solid fallback.

**Existing code components to tokenize (source of truth = code today):**
- `GlassCard` — frosted card + border glow (+ solid Reduce-Transparency variant).
- `GradientButton` — primary/secondary; **re-tokenized to the deep `action/primary` gradient**.
- `StatusBadge` — **re-tokenized to semantic tint pairs** (fixes G2).
- `HeartIcon` — glass 3D heart with inner sparkle (brand motif).
- `AnimatedBackground` — gradient + particles (+ Reduce-Motion static variant).
- `EmptyStateView` — icon + title + optional subtitle (already accessible; keep as template).

**New components to add for a complete library:**
- Tab bar (Rooms / Groups / Friends / Inbox / Settings) — Liquid Glass tab bar.
- Nav bar / large title treatment.
- List rows: participant row, group row, friend row, inbox/request row (each with avatar, label,
  trailing badge/action).
- Avatar / animal token (emoji or symbol + color chip; doubles as the color-blind-safe label).
- Text field, segmented control, toggle/settings row.
- **Confirmation dialog / destructive-action sheet** (fixes G4 — destructive actions without
  confirmation).
- Loading / skeleton state (fixes "no initial loading state on list views", G4).
- Inline error / toast (surfaces boundary errors — no silent failure).
- **Sign in with Apple button** — native `SignInWithAppleButton`, fully VoiceOver-reachable
  (fixes G1: the current transparent-overlay tap target is a VoiceOver dead end).
- Plot atoms: heart marker (color + animal label + outline), plot grid, axis labels, cluster
  circle (solid/dashed), sync star, sync halo/bloom, stats HUD pill (BPM / max chain / synced).
- Watch variants: Watch plot, Watch HUD, Watch heart marker (distilled, high-contrast).

---

## Navigation Architecture

- **iPhone:** Liquid Glass **TabView with 5 tabs** — Rooms, Groups, Friends, Inbox, Settings —
  each wrapping its own `NavigationStack`. Room detail and Group detail push within their tab.
  Dashboard is reached via a `NavigationLink` from Settings (not a tab).
  - *Structural debt to fix in design:* the app needs a single source of truth for entering a
    Room (today a room can be entered from 4 tabs with racey `navigationDestination(isPresented:)`
    — audit E2/G6). Design a single "enter room" affordance/flow and note the need for a nav
    coordinator so the visual design doesn't bake in the ambiguity.
- **Apple Watch:** single-view passive display (plot + HUD); no tab chrome, no perpetual
  background — legibility and battery first.

---

## Key Screens (the 6 core screens for Figma, in priority order)

1. **Sign In / Onboarding.** The app's only entry point. Native, VoiceOver-reachable
   `SignInWithAppleButton` (fixes G1). Hero wordmark on `brand/gradient`, calm glass card,
   HealthKit rationale copy. Minimal — get to the experience fast.
2. **Rooms (list).** Active rooms = group rooms + temporary 1:1 rooms. Must show the three
   honest states: **loading** (skeleton), **empty** (`EmptyStateView` with a clear "start a
   room" CTA), and **populated**. Each row: room name, member count/avatars, live/idle badge
   (tint pair). Single clear affordance to enter a room.
3. **Room — the live 2D plot (HERO / climax).** The scientific plot (X = previous HR, Y =
   current HR, 40–200, Y flipped) with animated heart markers, cluster circles, sync stars, the
   sync bloom, and the compact bottom HUD (own BPM, max chain, synced count, participant count,
   Leave). This screen carries the sync-moment design and the a11y template: fixed data-viz
   sizes *plus* an explicit VoiceOver layer that summarizes who is synced with whom and the chain
   length (fixes G3's "plot hides all sync data from VoiceOver"). Design the Reduce-Motion
   variant alongside the standard one.
4. **Group Detail.** Members with role badges (Admin/Member tint pairs), pending requests,
   join-with-code / browse. All destructive actions (leave group, remove member) gated by the
   confirmation-dialog component (fixes G4). Loading + empty states.
5. **Friends & Inbox.** Friends list + friend-request / invite flow. These are tightly coupled
   (an accepted inbox request mutates the friend graph), so design them together. Request rows
   use action buttons (accept/decline) + status tint pairs. Remove-friend gated by confirmation.
6. **Settings.** Account, sign out, **delete account** (multi-step, confirmed), HealthKit
   permission row with a working **"Open Settings"** action on denial (fixes G4's dead-end),
   Dashboard entry, and a theme placeholder (light now; dark = v2). Notifications/feature-flag
   surfaces as available.

> **Watch (designed after the 6, but specced here):** one glanceable screen — simplified plot
> (sparse grid: 40/120/200 labels), smaller high-contrast markers (own 16pt / other 12pt, no
> username labels), the 3-stat HUD, and the sync haptic as the primary climax channel. VoiceOver
> parity with the iPhone HUD is a v1 requirement (fixes G3's ~0% Watch coverage). No perpetual
> particle background on Watch.

---

## Platform Guidelines

- **Apple platforms:** Full HIG / **Liquid Glass** compliance is the baseline; brand flavor is
  layered on top (color, sparkle, the heart motif, the Room), never against the platform. Use
  native controls (tab bar, nav, sheets, Sign in with Apple) unless there's a documented reason.
- **Intentional deviations from defaults:**
  - The Room is a custom, characterful data-viz canvas rather than a stock layout.
  - Fixed (non-Dynamic-Type) font sizes inside the plot/HUD — justified as data viz, and always
    paired with explicit accessibility elements.
  - Decorative brand gradient behind large/hero type only (never small text) — a self-imposed
    constraint, not a platform one.
- **Cross-platform consistency:** shared design *language* (color, motif, tone) across iPhone
  and Watch, but platform-appropriate density — the Watch is a distilled subset, not a shrink.

---

## Constraints & Non-Negotiables

- **WCAG AA everywhere:** ≥ 4.5:1 text/essential icons, ≥ 3:1 large text and meaningful
  graphics. The `StatusBadge` tint-pair fix (G2) is a gate on the Figma library (plan 2.2).
- **Reduce Motion** has a complete, designed alternate path (per the motion table). No
  `repeatForever` survives Reduce Motion.
- **Reduce Transparency** has solid-surface fallbacks for all glass.
- **VoiceOver:** accessible Sign in with Apple (G1); a plot summary layer (G3); Watch parity
  with the iPhone HUD (G3). Color is never the sole information channel (animal label always present).
- **Dynamic Type** everywhere except the justified fixed data-viz sizes (which stay accessible).
- **Honest states:** every data surface designs loading / empty / error; a permission-denied
  room must look different from an empty one (mirrors D1/D2 in the code).
- **Destructive actions** are always confirmed (G4).
- **Performance:** design must not require perpetual full-screen GPU work; motion respects
  `scenePhase` (F3). 60 fps target at ~20 participants on iPhone; 30 fps min on Watch.
- **Everything must be expressible as SwiftUI Liquid Glass** (`apple-liquid-glass` skill).

---

## Out of Scope (v1)

- iPad, Mac, Vision Pro (iPad revisited in v2 with a purpose-built large-canvas plot).
- Custom/brand typeface (system fonts only in v1).
- Real dashboards (stubs only in v1).
- Localization (FR) — v2 (code/UI stays English per project convention).
- Onboarding tutorial beyond the sign-in screen.
- Marketing / App Store store-listing assets.
- Third-party Bluetooth HR monitors; expanded animal list.

---

## Decisions (settled 2026-07-19, Rémy)

1. **iPad:** CONFIRMED — dropped for v1 (`TARGETED_DEVICE_FAMILY = 1`), revisit v2.
2. **Dark Cosmic:** **REDIRECTED — v1 selectable theme** (see § Mode for the accepted
   scope consequences). The consultant's light-only recommendation was declined.
3. **Contrast vs pastel:** CONFIRMED — tint pairs; pastel fills stay, `onFill` carries AA;
   deepened primary-button gradient.
4. **Sync-moment register:** CONFIRMED — delighted recognition / warm crescendo; effects
   never occlude the markers.
5. **Motion personality:** default accepted (organic/spring, exuberant only at sync, full
   Reduce-Motion path) — adjustable during Room-screen design if the resting state feels
   too quiet/busy in Figma.
6. **Watch ambition:** default accepted (passive display, VoiceOver parity, Reduce-Motion
   variant, complications v2).

## Open Questions (need data or a later decision)
- Exact deep-gradient hexes for `action/primary` — pin down in Figma once verified ≥ 4.5:1.
- Whether the Room needs an explicit "approaching sync" anticipation state or only the lock
  event (decide during Room-screen design / first field test, plan 2.4).
- Watch complication / Smart Stack presence (parked to v2).
- Single "enter room" source-of-truth flow — resolve visually alongside the nav-coordinator work
  (E2/G6) so the design doesn't encode the current 4-entry-point ambiguity.
