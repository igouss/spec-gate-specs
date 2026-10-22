---
prefix: sg
---

# spec-gate — requirements

The requirements of `spec-gate`, written in `req`'s format so every acceptance criterion has an
address a scenario can cite with `@covers:`. Each requirement carries a witness (a run the gate
must accept) and a near-miss (the closest run it must reject); the near-miss is the case the
scenario must be seen failing on before it counts.

## `sg-dop` The gate shall judge a product commit against the spec repository's main branch

The spec version is chosen by the spec repository, never by the product repository. A product
commit that names a spec ref has no effect on which specs run.

Witness: product commit `P`, spec `main` at `S`; the verdict names `P` and `S`.
Near-miss: product commit `P` carries a file pinning spec ref `S-1`; the verdict still names `S`.

### Acceptance

- `sg-dop.1` The verdict names the product commit and the spec commit it was judged against.
- `sg-dop.2` A spec ref named inside the product repository does not change the spec commit used.

## `sg-397` The gate shall reject a scenario whose first recorded result is a pass

A scenario counts only after the ledger holds a failing run of it against some product commit,
recorded before its first passing run.

Witness: ledger holds red at `P1`, then green at `P2`; the scenario counts.
Near-miss: ledger holds green at `P1` and nothing earlier; the scenario is rejected.

### Acceptance

- `sg-397.1` A scenario with a recorded failure before its first pass counts toward the verdict.
- `sg-397.2` A scenario whose first recorded result is a pass fails the gate, naming the scenario.
- `sg-397.3` A scenario with no ledger entry fails the gate, naming the scenario.

## `sg-zf8` The gate shall fail a run in which any step is skipped or undefined

Witness: every step of every scenario matches a definition and runs.
Near-miss: one step text has no matching definition; the run fails, naming the step.

### Acceptance

- `sg-zf8.1` A step with no matching definition fails the run, naming the step and its scenario.
- `sg-zf8.2` A run with zero scenarios fails.

## `sg-3zr` The gate shall fail a scenario that cites no acceptance criterion or a criterion that does not exist

Witness: a scenario tagged `@covers:` with a criterion id present in the requirements projection.
Near-miss: the same scenario tagged with a criterion id one digit off; the gate fails naming it.

### Acceptance

- `sg-3zr.1` A scenario with no `@covers:` tag fails the gate, naming the scenario.
- `sg-3zr.2` A `@covers:` tag naming an absent criterion fails the gate, naming the tag.

## `sg-ubq` A local run shall leave the ledger and the commit status untouched

A local run gives feedback; only the authoritative runner records evidence.

Witness: `spec-gate run` against a working tree reports results; ledger bytes are unchanged.
Near-miss: the same run with the runner credential absent attempts a status post; it is refused.

### Acceptance

- `sg-ubq.1` After a local run the ledger is byte-identical to before the run.
- `sg-ubq.2` A local run posts no commit status.

## `sg-i86` The gate shall judge with a released build, never with the commit under test

When the product is `spec-gate` itself, the binary that judges commit `P` is a released build
whose checksum the spec repository pins.

Witness: pinned checksum matches the judging binary; the run proceeds.
Near-miss: the judging binary is built from `P`; its checksum differs from the pin and the run
refuses.

### Acceptance

- `sg-i86.1` A judging binary whose checksum differs from the pinned checksum refuses to run, naming both.

## `sg-212` The report shall name, for each failure, the scenario, the step, the expected and actual values, and the driver trace

The report is what an agent reads to make the next change; a bare "failed" gives it nothing to
act on.

Witness: a failing assertion reports scenario, step, expected `18.00`, actual `20.00`, and the
driver's request and response.
Near-miss: a failure reported with the scenario name only; the report check fails.

### Acceptance

- `sg-212.1` Each failure in the JSON report carries scenario, step, expected, actual and driver trace.
