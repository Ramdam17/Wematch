# 0006 — The theme preference has three options, not the comp's two

**Date:** 2026-07-27 · **Plan step:** 2.2 · **Status:** accepted

## Context

The Settings comp drew a two-way switch: Pastel or Cosmic. `Docs/design-brief.md` — the
validated decision record — says "persisted; follows-system as third option".

## Decision

`ThemePreference` is `system | pastel | cosmic`, defaulting to `system`. The Figma comp was
corrected to match, not the code.

## Why

**When the brief and a comp disagree, the brief wins.** The brief is the validated record;
a screen is one rendering of it. Dropping "System" would also mean the app ignores the
user's device-wide appearance choice, which is a decision no comp should make implicitly.

## Evidence

`01ab573`. Verified on the simulator in all three directions — the preference propagates to
the window's **trait collection**, not merely the SwiftUI environment, which is what
`UIColor(dynamicProvider:)` tokens follow. Xcode Previews cannot verify this: the preview's
Color Scheme variant is applied above the content and beats a `.preferredColorScheme()`
inside it.

## Consequences

`ThemeController` lives above the tab tree — a Settings-scoped ViewModel is rebuilt on every
appearance and cannot hold the preference. Field-test case S11 is the on-device
confirmation, which the simulator cannot give for the trait-collection question.
