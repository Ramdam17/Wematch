# 0003 — Interactive surfaces use action/primary, never the brand gradient

**Date:** 2026-07-27 · **Plan step:** 2.2 (G2) · **Status:** accepted

## Context

The v1 UI put white labels on the brand pink gradient for every button and selected state,
because it is the app's signature colour.

## Decision

Interactive surfaces use `action/primary/*` (`WematchTheme.actionGradient`). The brand hues
are for hero art and empty states only.

## Why

White on the brand gradient measures **1.45:1** — a label you cannot read is not a brand.
Splitting the token families means the brand can stay bright without every control
inheriting its contrast problem.

## Evidence

Contrast measured per token pair during the backport (`8fe20d2`). The theme picker's
selected segment is the same argument at a smaller scale: `glass/fill` over the `bg/1` track
measures **1.07:1** in light and **1.55:1** in dark, against the 3:1 a state indicator needs
(SC 1.4.11) — so the selected segment is filled with `actionGradient` instead, departing
from the comp.

## Consequences

Tint fills separate from the lavender background by **hue**, not luminance — all five sit at
1.00–1.12:1 against it. Only `tint/accent` (purple on purple) has no hue to spend and takes
a luminance step. That asymmetry is deliberate.
