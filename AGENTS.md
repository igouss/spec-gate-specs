# AGENTS.md — spec-gate-specs (spec repository)

The executable specification of `spec-gate` (`../spec-gate`). This repository is the
measurement: requirements, scenarios, DSL, drivers, ledger and judge pin.

## The invariant

Agents draft here; only the operator merges to `main` (D-09, D-14, D-15).

- Never commit to `main`. Deliver every change on a branch named after its bead.
- Never write to `../spec-gate`. Read it; the product is implemented by a different session
  (D-11).
- Never write ledger entries, the judge pin, or ids by hand.

## Read first

1. `../spec-gate/docs/design.md`: the system and decisions D-01 to D-25 (§10).
2. The epic you are working: `br show <epic>`, run in `../spec-gate`. Its **Operator
   decision** section is your only source of authority for anything not in §10.
3. `README.md` here, and `spec-gate.req.md`.
4. `~/kbe/guides/writing-specifications.md`.
5. `~/.claude/CLAUDE.md`: house rules, cited by id (`cm-*`).

## Beads

Beads live in `../spec-gate/.beads/`; run `br` there. Your beads are labelled `side:spec`. Work
them one at a time.

1. `br show <id>`; confirm the status is `open` before claiming (cm-2tb); `br update <id> --claim`.
2. Work on branch `<id>` in this repository.
3. When done, leave the bead `in_progress` with a note: the branch, what was proven red and green
   and how, and what awaits the operator. It closes after the operator merges.
4. A policy choice not covered by §10 or the epic's Operator decision: stop and ask (cm-vph).

## Writing specs

- Requirements go in `spec-gate.req.md`. Run `~/code/tools/req/target/debug/req mint`, then
  `req generate --out requirements.toon`; `req check --out requirements.toon` must be clean.
- Every criterion has exactly one scenario tagged `@covers:<criterion-id>`.
- Every requirement has a witness and a near-miss; the zero, one and many cases (cm-srn).
- Scenarios state what, never how: domain words, no protocol details.

## Code

- Layers: `acceptance → dsl → driver-port ← driver-<channel>`, held by `hex-lint` roles.
- The DSL has its own vocabulary and depends on no `spec-gate` crate (D-02).
- Each step definition is a single line that hands off to the DSL.
- No code comments (cm-k7c).
- Every new check is seen red once on a planted violation, then green (cm-yzv).

Every cargo call gets a 900000 ms timeout (cm-lpb). Only one agent on this machine runs cargo
at a time (cm-e51).

## Report

Per bead:
- branch and commits;
- checks run, with exit codes;
- the red-then-green evidence;
- open questions.
