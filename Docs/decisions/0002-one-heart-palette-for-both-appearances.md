# 0002 — One heart palette for both appearances, with the outline carrying the contrast

**Date:** 2026-07-27 · **Plan step:** 2.2 (G2) · **Status:** accepted

## Context

Twenty participant colours must stay distinguishable from each other *and* keep a visible
boundary against the plot background, in Pastel Light and Dark Cosmic both. Pastel fills
are, by construction, close in luminance to a pale background.

## Decision

One palette serves both appearances. The 3:1 boundary required of a graphical object
(WCAG SC 1.4.11) is carried by `plotMarkerOutline` at **70 % black**, not by darkening the
fills.

## Why

The obvious alternative — a darkened palette for light mode — was built and rejected. It
forces the yellow and orange slots to olive and brown, unavoidably: yellow has intrinsically
high luminance, so lowering it far enough to pass changes its hue identity.

## Evidence

- 70 % is a threshold, not a taste: it reaches **7.87:1** against the backgrounds and is the
  lowest value that keeps all twenty fills at **1.5:1** against the outline itself. At 35 %
  the outline manages **2.42:1** and ten of twenty hearts lose their boundary.
- The twenty hues are derived, not picked: an even 18° hue grid anchored on the brand pink,
  with lightness and saturation searched to maximise the minimum CIEDE2000 distance —
  **dE 11.8**, up from 3.7 for the hand-picked set.
- Darkened pastels saturate near **dE 7.5** whatever the slot count (7.6 at 14, 7.5 at 20).
- `HeartPaletteSeparabilityTests` asserts the properties, not the hex values.

## Consequences

Do not "tidy" the outline percentage or re-pick hues by eye — both are load-bearing.
Unconstrained max-separation optimisation produces neon and near-blacks; the aesthetic box
(hue drift and lightness limits) is part of the method.
