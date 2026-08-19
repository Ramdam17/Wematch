# Decision Log

Plan step 2.5. One file per methodological choice — a choice where a reasonable engineer
could have gone the other way, and where the reason is not visible in the code that came
out of it.

## Why

The reasoning behind Phase 2 lived in three places that do not survive: commit bodies
nobody re-reads, Figma component notes, and a scratchpad directory that was deleted with
its temp dir. The code shows *what* was decided. These files show *why*, and — for the ones
settled by measurement — *what was measured*, so the next person does not re-open a
question that already has a number attached to it.

## What earns a file

- A methodological choice: a metric, an algorithm, a threshold, a data model.
- A decision taken against the obvious option, or against a design comp.
- Anything settled by a measurement — record the measurement, not just the verdict.

Not: naming, formatting, or anything the code states plainly by itself.

## Convention

`NNNN-kebab-case-title.md`, numbered in order taken. Never renumber; supersede instead —
a decision that is overturned gets a **Superseded by** line and stays.

Copy `template.md`. Keep it short: context, decision, why, evidence, consequences. If it
runs past a screen, the decision is probably two decisions.
