# 0005 — Destructive confirmations use the native dialog

**Date:** 2026-07-27 · **Plan step:** 2.2 (G4) · **Status:** accepted

## Context

The design system has a glass surface for everything else, so a matching custom
confirmation sheet was the expected build.

## Decision

`destructiveConfirmation` wraps SwiftUI's native `confirmationDialog`. No custom glass
dialog exists.

## Why

The Figma component master's own note prescribes the native control: a destructive
confirmation is the one moment where matching the platform beats matching the brand — users
must recognise it instantly, and it inherits VoiceOver, Dynamic Type and the destructive
role for free.

## Evidence

`65447d5`, applied on six destructive paths.

## Consequences

Inbox swipe-to-delete is deliberately left unconfirmed: the rule adopted is that destroying
**shared** state asks first, and dismissing one's own inbox item destroys nothing anyone
else can see. Read the Figma master's `.doc` note before building any component — it is
what revealed this.
