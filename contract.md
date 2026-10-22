# The judgment contract

What the three parties to a judgment promise each other: the judging `spec-gate` (the judge), the
acceptance harness in this repository (the harness), and the product being judged. The judge
and the harness are written by different sessions (D-11); this document is all they share.
`spec-gate.toml` in this repository conforms to it.

Clarify answers are cited as C-n (epic `gate-c7r`, "## Clarify answers"); decisions as D-n
(`../spec-gate/docs/design.md` §10).

## 1. Terms

| Term | Meaning |
|---|---|
| spec checkout | The working tree of this repository the judge is given with `--spec`. |
| S | The spec commit: the tip of `refs/heads/main` in the spec checkout (C-25). |
| P | The product commit being judged. |
| feature file | A file matching `features/**/*.feature` in the tree at S (C-23). |
| scenario | A `Scenario:` block in a feature file. Its path is the feature file's path relative to the spec repository root with `/` separators; its line is the 1-based line of its `Scenario:` keyword. Path and line locate it at S (C-29). |
| tags | A scenario's own tags, in source order, each without the leading `@`. Tags on the `Feature:` line are not a scenario's tags. |
| `@id` tag | A tag that is `id` or starts with `id:`. Its value is the text after `id:`. |
| `@covers:` tag | A tag that starts with `covers:`. Its value is a criterion id. |
| scenario id | The value of a scenario's only `@id` tag, when it parses as a `hashid` id whose prefix is `[mint] prefix` (C-4, C-21). |
| excluded | A scenario with a `@covers:` value listed in `[scope] excluded_criteria` (C-1). It is not run. |
| run scenario | A scenario that is not excluded. |
| effective kind | A step's `Given`, `When` or `Then`. An `And`, `But` or `*` step takes the effective kind of the step before it; one that opens a scenario has none, so it is never a `Then`. Read from the feature file at S, never from the results file. |

## 2. Command line

```
spec-gate judge --spec <dir> --commit <rev>
spec-gate mint --spec <dir>
```

- `--spec <dir>`: the root of the spec checkout.
- `--commit <rev>`: the product revision to judge, as `git` resolves `<rev>^{commit}` in the
  `[sut] repo` repository. The verdict names the full object name it resolves to.
- `judge` writes the verdict document (§5) to stdout and nothing else; build output, harness
  output and progress go to stderr.
- `mint` takes no argument that narrows which scenarios it tags (C-33).

### Exit statuses

| Status | `judge` | `mint` | Verdict document on stdout |
|---|---|---|---|
| 0 | pass | success (C-24) | `judge`: required, `"verdict": "pass"` |
| 3 | fail | — | required, `"verdict": "fail"` |
| 4 | void | — | required, `"verdict": "void"` |
| 5 | refused (checksum, `sg-i86.1`) | — | required, `"verdict": "refused"` |
| 6 | — | mint-rejected (C-38) | none |
| 7 | not-implemented (C-5) | not-implemented (C-5) | none |

- The contract uses no status that Rust or `clap` produce by default: 1 (`main` returns `Err`),
  2 (usage error), 101 (panic), 126, 127 and 128 and above (signals). Those, and every status
  not listed for the command, are outside the contract: the CLI driver reports a `DriverError`
  (C-5, D-08), never a verdict.
- A `judge` status of 0, 3, 4 or 5 is an outcome only together with a verdict document on
  stdout whose `verdict` agrees with it. A missing or unparseable document, or one that
  disagrees, is a lie the driver detects (C-26); it is not an outcome.
- Status 7 is reserved for the scaffold stub (`gate-c7r.8`): for every invocation whose first
  argument is `judge` or `mint`, the stub exits 7, writes nothing to stdout and changes no file.
  The driver maps 7 to a typed not-implemented outcome, so the scenario's `Then` is what fails
  (C-5). No released `spec-gate` exits 7.
- `mint` exits 0 when it tagged every untagged scenario, including when there was none.

## 3. `spec-gate.toml`

Every value that decides a verdict lives here, at the spec repository root.

```toml
[sut]
name = "spec-gate"
repo = "../spec-gate"
build = ["cargo", "build", "--release", "--locked"]
artifact = "target/release/spec-gate"
channel = "cli"

[judge]
release = "v0"
sha256 = "PENDING"

[gates]
acceptance = { command = ["cargo", "test", "--locked", "--package", "acceptance"], fail_on_skipped = true }

[mint]
prefix = "sgs"

[scope]
excluded_criteria = ["sg-212.1", "sg-3zr.1", "sg-3zr.2", "sg-ubq.1", "sg-ubq.2"]
```

| Key | Required | Meaning |
|---|---|---|
| `[sut] repo` | yes | The product's git repository, relative to the spec repository root. |
| `[sut] build` | yes | The build command as an argument vector, run without a shell, in the root of a fresh copy of P (§4, phase 4). |
| `[sut] artifact` | yes | The built artifact, relative to the root of that copy (C-9). |
| `[sut] name`, `[sut] channel` | no | Not read by the v0 judge. `channel` names the driver channel (D-07). |
| `[judge] release` | yes | The pinned judge's release name. The verdict and every ledger entry name it. |
| `[judge] sha256` | yes | The pinned judge's sha256: 64 hexadecimal digits, compared without regard to case. `PENDING` is the value before a release is pinned; it is not 64 hexadecimal digits, so the judge refuses (C-42). |
| `[gates] acceptance.command` | yes | The harness command as an argument vector, run without a shell, in the spec checkout root (§4, phase 5). |
| `[gates] acceptance.fail_on_skipped` | no | Not read by the judge, which treats `skipped` and `undefined` alike (§6.3). See open question Q-2. |
| `[mint] prefix` | yes | The scenario-id prefix (C-4); a valid `hashid` prefix. This repository uses `sgs`. |
| `[scope] excluded_criteria` | yes | Criterion ids whose scenarios are not run in v0 (C-1); an array, possibly empty. |

The judge ignores keys and tables it does not name here. A command vector is non-empty and
holds only strings. A `spec-gate.toml` that does not parse gives refused, because the pin cannot
be read (C-42). One that parses but lacks a required key or has a value of the wrong shape
gives void, `config-invalid`.

## 4. A judgment

The judge works in phases. Each phase records every cause it finds, and the verdict names every
cause recorded (C-29). A refused cause in phase 1 ends the judgment after phase 1. Phase 2 ends
it when S cannot be found (`spec-not-a-repository`, `spec-main-missing`). Otherwise phases 2 and
3 both run, so a void verdict names the scenarios at S (C-1), and a void cause from either ends
the judgment after phase 3. A void cause in phase 4 or 5 ends it after that phase.

1. **Pin** (C-40, `gate-c7r.11`). Before any other action, read `[judge] sha256` from
   `<spec>/spec-gate.toml` in the working tree, and compute the sha256 of the running binary.
   Refused if the file or the key is missing (`pin-missing`), the file does not parse
   (`pin-unreadable`), the value is not 64 hexadecimal digits (`pin-malformed`), or it differs
   from the running binary's (`pin-mismatch`, naming both).
2. **Spec checkout.** Void if `<spec>` is not the root of a git working tree
   (`spec-not-a-repository`); if `refs/heads/main` does not name a commit
   (`spec-main-missing`); if HEAD is not the symbolic ref `refs/heads/main` (C-25,
   `spec-not-on-main`); or, when S was found, if any tracked file differs from S or any
   untracked file is not ignored (C-11, `spec-dirty`, naming the paths). No remote is consulted.
3. **Spec at S.** Everything except the pin is read from the git objects of the tree at S,
   never from the working tree, which may differ from S when phase 2 recorded a cause.
   - `spec-gate.toml` (§3): void, `config-invalid`, naming the problem.
   - The ledger (§7): void, `ledger-invalid`, naming the file, line and problem (C-42).
   - Feature files: void, naming the file, if one does not parse as Gherkin with the parser
     `cucumber` 0.23 uses (`feature-unparseable`), or uses a construct v0 refuses
     (`construct-refused`): a `Scenario Outline:` or `Scenario Template:`, or any scenario
     with an `Examples:` block (`scenario-outline`, C-13, C-22); a `Background:`
     (`background`); a `Rule:` (`rule`); an `@id` or `@covers:` tag on a `Feature:` line
     (`tag-on-feature`) or on a `Rule:` line (`tag-on-rule`) (C-28).
   - Identity (C-21, C-41), recorded as scenario reasons (§5.1), not as judgment causes. Over
     every scenario, excluded ones included: more than one `@id` tag (`multiple-ids`); one
     `@id` tag whose value does not parse (`unparseable-id`); a scenario id shared with another
     scenario (`duplicate-id`, on each). Over run scenarios only: no `@id` tag
     (`missing-id`). A reason that needs `[mint] prefix` or `[scope] excluded_criteria` is not
     recorded when `config-invalid` left that key unread.
4. **Product.** Resolve `--commit` in `[sut] repo` (void, `product-commit-unknown`). Write
   `git archive` of P into a fresh temporary directory outside both repositories; never touch
   the `[sut]` repository's working tree or `.git` (C-10). Run `[sut] build` there with the
   judge's environment. A non-zero exit status is void, `build-failed`; so is termination by a
   signal. If `[sut] artifact` is then not a regular file, void, `artifact-missing`. No timeout
   applies (C-35).
5. **Harness.** Create a fresh temporary directory outside the spec checkout, and choose a
   results path in it that does not exist (C-8). Run `[gates] acceptance.command` in the spec
   checkout root with the judge's environment plus the two variables of §6.1. Its exit status
   is ignored (C-8). Then read the results file (§6): void if it is missing
   (`results-missing`) or malformed (`results-malformed`), if it disagrees with the run
   scenarios at S (`results-disagree`, C-19, C-29), or if it holds an excluded scenario
   (`excluded-in-results`, C-18).
6. **Verdict.** Classify each run scenario (§6.3); derive each scenario's evidence from the
   ledger at S plus this judgment's entry (§7.2); give the verdict (§5.2). On pass or fail,
   append this judgment's entries to the ledger in the working tree (§7.1), for the operator to
   commit (C-11). Void and refused append nothing (C-8, C-22, C-28, C-42). Write the verdict
   document; exit with its status.

Judging the same (P, S) pair again is a new judgment and appends again (C-7).

## 5. The verdict document

JSON on stdout, UTF-8, one object followed by a newline.

### 5.1 Fields

| Field | Value |
|---|---|
| `format` | `"spec-gate.verdict/1"`. |
| `verdict` | `"pass"`, `"fail"`, `"void"` or `"refused"`. |
| `product` | P's full object name; `null` before phase 4 resolved it. |
| `spec` | S's full object name; `null` when the judgment was refused or phase 2 found no S. |
| `judge` | `{"release": …, "sha256": …}`: `[judge] release` (`null` if unread) and the sha256 of the running binary. |
| `causes` | Judgment-level causes, in phase order. |
| `scenarios` | One entry per scenario at S, excluded ones included, ordered by path (byte order) then line; `[]` when the judgment was refused or phase 2 found no S. |

A cause is `{"verdict": <"refused"|"void"|"fail">, "kind": …, "message": …}` plus the fields
its kind names:

| `verdict` | `kind` | Fields |
|---|---|---|
| refused | `pin-missing`, `pin-unreadable` | `file` |
| refused | `pin-malformed` | `file`, `value` |
| refused | `pin-mismatch` | `pinned`, `actual` |
| void | `spec-not-a-repository` | `path` |
| void | `spec-main-missing` | — |
| void | `spec-not-on-main` | `head` (the ref HEAD names, or `null` when detached) |
| void | `spec-dirty` | `paths` |
| void | `config-invalid` | `file`, `problem` |
| void | `ledger-invalid` | `file`, `line` (`null` for a file-level problem), `problem` |
| void | `feature-unparseable` | `file`, `problem` |
| void | `construct-refused` | `file`, `line`, `construct` |
| void | `product-commit-unknown` | `commit` (as given) |
| void | `build-failed` | `command`, `status` (`null` when killed by a signal) |
| void | `artifact-missing` | `path` |
| void | `results-missing` | `path` |
| void | `results-malformed` | `problem` |
| void | `results-disagree` | `missing`, `extra`, `duplicate` (each a list of `{"feature", "line"}`), `tags` (list of `{"feature", "line", "expected", "actual"}`), `steps` (list of `{"feature", "line", "step_line"}`) |
| void | `excluded-in-results` | `scenarios` (list of `{"feature", "line"}`) |
| fail | `no-scenarios-run` | — (`sg-zf8.2`) |

A scenario entry:

| Field | Value |
|---|---|
| `id` | The scenario id, or `null`. |
| `feature`, `line`, `name` | Where it is at S, and its name. |
| `covers` | Its `@covers:` values, in tag order. |
| `result` | `"green"`, `"red"` or `"broken"` (§6.3); `"excluded"`; or `"not-judged"` when the judgment was void or refused. |
| `first_non_passing` | For `red` and `broken`: what stopped the scenario (§6.3); otherwise `null`. |
| `evidence` | After this judgment's entry: `"none"`, `"seen-red"`, `"counted"` or `"rejected"` (§7.2); `null` when the scenario gets no ledger entry or the judgment is void or refused. |
| `reasons` | Why this scenario fails the judgment; `[]` when it does not. |

`first_non_passing` is one of:

- `{"kind": "step", "line", "keyword", "text", "status", "message"}`: the first listed step
  whose status is not `passed`. `keyword` is the step's keyword at S without trailing space;
  `message` is the results file's `error_message`, or `null`.
- `{"kind": "missing-step", "line", "keyword", "text"}`: every listed step passed, and this is
  the first step at S the results do not list.
- `{"kind": "before-hook" | "after-hook", "status", "message"}`: a failed hook.

Scenario reasons:

| Reason | When |
|---|---|
| `not-passed` | The result is `red` or `broken`. `first_non_passing` names the step, including an `undefined` or `skipped` one (`sg-zf8.1`). |
| `never-seen-red` | Evidence is `rejected`: no red precedes the scenario's first green (`sg-397.2`, `sg-397.3`). |
| `seen-red-only-at-first-green-commit` | Evidence is `rejected`: every red before the first green is at the first green's product commit (C-37). |
| `missing-id`, `multiple-ids`, `unparseable-id`, `duplicate-id` | Phase 3, identity (C-21, C-41). |

The document is open: a reader ignores fields it does not know, and a later judge adds fields
(`sg-212.1` adds expected, actual and the driver trace) without changing `format`. A change to
the meaning of an existing field changes `format`.

### 5.2 The verdict

- **refused** if any cause has `"verdict": "refused"`;
- else **void** if any cause has `"verdict": "void"`;
- else **fail** if any cause remains, or any scenario's `reasons` is not empty;
- else **pass**.

So refused outranks void and void outranks fail (C-29). Phase 6 adds `no-scenarios-run` when
no run scenario exists. Pass therefore holds if and only if at least one scenario ran, every
scenario run is counted, none had a skipped or undefined step, and every one was green in this
judgment (C-6).

A refused document has `"product": null`, `"spec": null` and `"scenarios": []`: the judge reads
nothing past the pin. A void document whose phase 2 found S lists every scenario at S, with
`result` `"excluded"` or `"not-judged"`, `evidence` `null`, and the identity reasons phase 3
found; that includes `spec-dirty` and `spec-not-on-main`. Two inputs bound that list: a feature
file that does not parse contributes no scenario, and when `[scope] excluded_criteria` at S
cannot be read (`config-invalid`), no scenario is `"excluded"` and every listed one is
`"not-judged"`. A void document whose phase 2 found no S has `"spec": null` and
`"scenarios": []`. See A-4.

### 5.3 Examples

These continue the worked example of §6.4: `features/example.feature` at S, the results file
shown there, and the ledger of §7.3.

Fail:

```json
{
  "format": "spec-gate.verdict/1",
  "verdict": "fail",
  "product": "5e0c2a9f4b7d1e3a6c8f0b2d4e6a8c0e2f4b6d8a",
  "spec": "c4d1f7a2e9b3c5d7f1a3e5b7d9f1a3c5e7b9d1f3",
  "judge": { "release": "v0", "sha256": "7d865e959b2466918c9863afca942d0fb89d7c9ac0c99bafc3749504ded97730" },
  "causes": [],
  "scenarios": [
    {
      "id": "sgs-8cda", "feature": "features/example.feature", "line": 4,
      "name": "Every step passes", "covers": ["sg-397.1"],
      "result": "green", "first_non_passing": null, "evidence": "counted", "reasons": []
    },
    {
      "id": "sgs-k3f2", "feature": "features/example.feature", "line": 11,
      "name": "A step has no definition", "covers": ["sg-zf8.1"],
      "result": "broken",
      "first_non_passing": {
        "kind": "step", "line": 13, "keyword": "When", "text": "nobody defined this step",
        "status": "undefined", "message": "Step doesn't match any function"
      },
      "evidence": "none", "reasons": ["not-passed"]
    },
    {
      "id": "sgs-q9wz", "feature": "features/example.feature", "line": 17,
      "name": "The Then fails", "covers": ["sg-397.2"],
      "result": "red",
      "first_non_passing": {
        "kind": "step", "line": 20, "keyword": "Then", "text": "it fails",
        "status": "failed", "message": "Matched: tests/acceptance.rs:15:1\nStep panicked. Captured output: expected pass, got fail"
      },
      "evidence": "rejected", "reasons": ["not-passed", "never-seen-red"]
    },
    {
      "id": "sgs-2b7m", "feature": "features/example.feature", "line": 24,
      "name": "Out of scope in v0", "covers": ["sg-3zr.1"],
      "result": "excluded", "first_non_passing": null, "evidence": null, "reasons": []
    }
  ]
}
```

Void: the same judgment, had the results file omitted line 11 and held the excluded scenario
at line 24.

```json
{
  "format": "spec-gate.verdict/1",
  "verdict": "void",
  "product": "5e0c2a9f4b7d1e3a6c8f0b2d4e6a8c0e2f4b6d8a",
  "spec": "c4d1f7a2e9b3c5d7f1a3e5b7d9f1a3c5e7b9d1f3",
  "judge": { "release": "v0", "sha256": "7d865e959b2466918c9863afca942d0fb89d7c9ac0c99bafc3749504ded97730" },
  "causes": [
    {
      "verdict": "void", "kind": "results-disagree",
      "message": "features/example.feature:11 is missing from the results",
      "missing": [{ "feature": "features/example.feature", "line": 11 }],
      "extra": [], "duplicate": [], "tags": [], "steps": []
    },
    {
      "verdict": "void", "kind": "excluded-in-results",
      "message": "features/example.feature:24 covers an excluded criterion but is in the results",
      "scenarios": [{ "feature": "features/example.feature", "line": 24 }]
    }
  ],
  "scenarios": [
    {
      "id": "sgs-8cda", "feature": "features/example.feature", "line": 4,
      "name": "Every step passes", "covers": ["sg-397.1"],
      "result": "not-judged", "first_non_passing": null, "evidence": null, "reasons": []
    },
    {
      "id": "sgs-k3f2", "feature": "features/example.feature", "line": 11,
      "name": "A step has no definition", "covers": ["sg-zf8.1"],
      "result": "not-judged", "first_non_passing": null, "evidence": null, "reasons": []
    },
    {
      "id": "sgs-q9wz", "feature": "features/example.feature", "line": 17,
      "name": "The Then fails", "covers": ["sg-397.2"],
      "result": "not-judged", "first_non_passing": null, "evidence": null, "reasons": []
    },
    {
      "id": "sgs-2b7m", "feature": "features/example.feature", "line": 24,
      "name": "Out of scope in v0", "covers": ["sg-3zr.1"],
      "result": "excluded", "first_non_passing": null, "evidence": null, "reasons": []
    }
  ]
}
```

Refused:

```json
{
  "format": "spec-gate.verdict/1",
  "verdict": "refused",
  "product": null,
  "spec": null,
  "judge": { "release": "v0", "sha256": "0b8f3a1c5d7e9f2a4b6c8d0e1f3a5b7c9d2e4f6a8b0c1d3e5f7a9b2c4d6e8f0a" },
  "causes": [
    {
      "verdict": "refused", "kind": "pin-mismatch",
      "message": "spec-gate.toml pins 7d865e959b2466918c9863afca942d0fb89d7c9ac0c99bafc3749504ded97730; this binary is 0b8f3a1c5d7e9f2a4b6c8d0e1f3a5b7c9d2e4f6a8b0c1d3e5f7a9b2c4d6e8f0a",
      "pinned": "7d865e959b2466918c9863afca942d0fb89d7c9ac0c99bafc3749504ded97730",
      "actual": "0b8f3a1c5d7e9f2a4b6c8d0e1f3a5b7c9d2e4f6a8b0c1d3e5f7a9b2c4d6e8f0a"
    }
  ],
  "scenarios": []
}
```

## 6. The harness

### 6.1 Invocation

The judge runs `[gates] acceptance.command` in the spec checkout root, with its own environment
plus:

| Variable | Value |
|---|---|
| `SPEC_GATE_ARTIFACT` | The absolute path of the built product artifact (C-9). |
| `SPEC_GATE_RESULTS` | The absolute path to write the results file to. It does not exist when the harness starts, its directory does, and it lies outside the spec checkout (C-8). |

The harness:

- reads `[scope] excluded_criteria` from `spec-gate.toml` and runs every scenario under
  `features/**/*.feature` except the excluded ones (C-18);
- drives the product only through `SPEC_GATE_ARTIFACT`. When that variable is unset, not
  absolute, or not a regular file, it runs no scenario, writes no results file, and exits
  non-zero;
- writes the results file to `SPEC_GATE_RESULTS` with `cucumber` 0.23's JSON writer (§6.2).
  When `SPEC_GATE_RESULTS` is unset, it writes no results file;
- runs `cucumber` with `fail_on_skipped`, so an unmatched step is reported `undefined`
  rather than `skipped` (`gate-c7r.6`);
- never retries a scenario: a retried scenario lists its steps twice, which disagrees with S
  and voids the judgment.

A direct run (`gate-c7r.3`, `gate-c7r.6`) sets `SPEC_GATE_ARTIFACT` by hand (C-9). A fixture
spec repository may give any command that writes canned results to `SPEC_GATE_RESULTS`, such as
`["sh", "-c", "cp canned.json \"$SPEC_GATE_RESULTS\""]`.

### 6.2 The results file

The output of `cucumber` 0.23's `writer::Json` (feature `output-json`): a JSON array of features,
each with an `elements` array of scenarios. The judge reads these fields and ignores the rest
(`keyword`, `id`, `name`, `duration`, `embeddings`, `hidden`, feature `tags`):

| Field | Read as |
|---|---|
| feature `uri` | The feature file's path. After the judge replaces `\` with `/` and removes leading `./`, it must equal a feature file's path relative to the spec repository root. |
| element `type` | Must be `"scenario"`. |
| element `line` | The scenario's line; with `uri` it locates the scenario (C-29). |
| element `tags[].name` | The scenario's tags, in order. |
| element `before[]`, `after[]` | Hook results; absent means none. `result.status` is `passed` or `failed`. |
| element `steps[]` | The steps that ran, in order: `line`, `name` (the step text without keyword), `result.status` (`passed`, `failed`, `skipped`, `undefined` or `ambiguous`), `result.error_message` (optional). |

`cucumber` writes `uri` with the prefix `CARGO_WORKSPACE_DIR`, else `CARGO_MANIFEST_DIR`, else
the current directory, stripped from the canonical feature path. Run from `crates/acceptance`,
that leaves an absolute path without its leading `/`. The harness must make `uri` relative to
the spec repository root, for example by setting `CARGO_WORKSPACE_DIR` to the root through
`.cargo/config.toml` (`[env] CARGO_WORKSPACE_DIR = { value = "", relative = true }`, seen to
work with `cucumber` 0.23 under `cargo test`). A `uri` the judge cannot match is an extra
scenario, so the judgment is void.

**Malformed** (`results-malformed`, void): not UTF-8 JSON; not an array; a feature without a
string `uri` or an array `elements`; an element whose `type` is not `"scenario"`, whose `line`
is not a positive integer, or that lacks `tags` or `steps`; a step without an integer `line`, a
string `name` or a string `result.status`; a step status outside the five above, `pending`
included (`cucumber` 0.23 never writes it); a hook status other than `passed` or `failed`; a
step listed after a step whose status is not `passed` (`cucumber` 0.23 stops a scenario at its
first non-passing step). A feature file that `cucumber` failed to parse appears as an element
with `line` 0, so it is malformed too.

**Disagrees** (`results-disagree`, void, naming each; C-19, C-29), comparing elements with the
run scenarios at S by (path, line):

- `missing`: a run scenario with no element. A scenario with no steps and no hooks gets no
  element from `cucumber` 0.23, so it is reported missing.
- `extra`: an element that locates no scenario at S.
- `duplicate`: two or more elements locating one scenario.
- `tags`: an element whose tag names differ from the scenario's tags at S, as sequences.
- `steps`: an element whose listed steps are not a prefix of the scenario's steps at S, compared
  by line and text.

An element that locates an excluded scenario is `excluded-in-results` instead of `extra` (C-18).

### 6.3 A scenario's result

Classified from its element and the scenario at S, in execution order:

1. A `before` hook `failed`: **broken**.
2. The first listed step whose status is not `passed`: **red** if its status is `failed` and its
   effective kind is `Then`; otherwise **broken**, which covers a `failed` `Given` or `When` and
   every `undefined`, `ambiguous` or `skipped` step (C-2).
3. Every listed step passed but the scenario at S has more steps: **broken**, at the first
   missing step.
4. An `after` hook `failed`: **broken**.
5. Otherwise **green**: every step of the scenario at S is listed, in order, as `passed`, and
   every hook passed.

`skipped` and `undefined` are both broken, so `fail_on_skipped` cannot change a verdict. A
scenario with no `Then` can never be red, so it is never counted.

### 6.4 Worked example

`features/example.feature` at S, with `excluded_criteria` containing `sg-3zr.1`:

```gherkin
Feature: Worked example

  @id:sgs-8cda @covers:sg-397.1
  Scenario: Every step passes
    Given a thing
    When it runs
    Then it passes
    And it still passes

  @id:sgs-k3f2 @covers:sg-zf8.1
  Scenario: A step has no definition
    Given a thing
    When nobody defined this step
    Then it passes

  @id:sgs-q9wz @covers:sg-397.2
  Scenario: The Then fails
    Given a thing
    When it runs
    Then it fails
    And it passes

  @id:sgs-2b7m @covers:sg-3zr.1
  Scenario: Out of scope in v0
    Given a thing
```

The results file, as `cucumber` 0.23 wrote it with `fail_on_skipped` and
`CARGO_WORKSPACE_DIR` set to the root, step definitions for every step but line 13, the `Then`
at line 20 panicking, and the excluded scenario filtered out (pretty-printed here; the judge
accepts any JSON whitespace):

```json
[
  {
    "uri": "features/example.feature", "keyword": "Feature", "name": "Worked example", "tags": [],
    "elements": [
      {
        "keyword": "Scenario", "type": "scenario", "id": "worked-example/every-step-passes",
        "line": 4, "name": "Every step passes",
        "tags": [{ "name": "id:sgs-8cda", "line": 4 }, { "name": "covers:sg-397.1", "line": 4 }],
        "steps": [
          { "keyword": "Given ", "line": 5, "name": "a thing", "result": { "status": "passed", "duration": 311945 } },
          { "keyword": "When ", "line": 6, "name": "it runs", "result": { "status": "passed", "duration": 410324 } },
          { "keyword": "Then ", "line": 7, "name": "it passes", "result": { "status": "passed", "duration": 608639 } },
          { "keyword": "And ", "line": 8, "name": "it still passes", "result": { "status": "passed", "duration": 292206 } }
        ]
      },
      {
        "keyword": "Scenario", "type": "scenario", "id": "worked-example/a-step-has-no-definition",
        "line": 11, "name": "A step has no definition",
        "tags": [{ "name": "id:sgs-k3f2", "line": 11 }, { "name": "covers:sg-zf8.1", "line": 11 }],
        "steps": [
          { "keyword": "Given ", "line": 12, "name": "a thing", "result": { "status": "passed", "duration": 389940 } },
          { "keyword": "When ", "line": 13, "name": "nobody defined this step", "result": { "status": "undefined", "duration": 406037, "error_message": "Step doesn't match any function" } }
        ]
      },
      {
        "keyword": "Scenario", "type": "scenario", "id": "worked-example/the-then-fails",
        "line": 17, "name": "The Then fails",
        "tags": [{ "name": "id:sgs-q9wz", "line": 17 }, { "name": "covers:sg-397.2", "line": 17 }],
        "steps": [
          { "keyword": "Given ", "line": 18, "name": "a thing", "result": { "status": "passed", "duration": 454717 } },
          { "keyword": "When ", "line": 19, "name": "it runs", "result": { "status": "passed", "duration": 323293 } },
          { "keyword": "Then ", "line": 20, "name": "it fails", "result": { "status": "failed", "duration": 600124, "error_message": "Matched: tests/acceptance.rs:15:1\nStep panicked. Captured output: expected pass, got fail" } }
        ]
      }
    ]
  }
]
```

Line 4 is green. Line 11 is broken at the `undefined` step on line 13. Line 17 is red: its
first non-passing step is the `Then` on line 20, `failed`; line 21 is not listed. Line 24 is
excluded and absent. The verdict is the fail example of §5.3.

## 7. The ledger

### 7.1 Format

The ledger records observations, never derived states. It is the directory `ledger/`: one file
`ledger/<scenario-id>.jsonl` per scenario id that has an entry, plus an optional empty
`.gitkeep`. Any other file in `ledger/` makes the ledger invalid.

An entry is one line: a JSON object with exactly these keys, written with keys in byte order,
no whitespace, and a terminating `\n`:

| Key | Value |
|---|---|
| `judge` | `[judge] release` of the judgment that wrote it. |
| `judge_sha256` | The sha256 of the judge binary that wrote it, lowercase. |
| `product` | P's full object name, lowercase hexadecimal. |
| `result` | `"green"`, `"red"` or `"broken"` (§6.3). |
| `scenario` | The scenario id; equal to the file's name without `.jsonl`. |
| `spec` | S's full object name, lowercase hexadecimal. |

A line whose bytes differ from that serialisation of the object it parses to, a file that does
not end in `\n`, an empty line, or a `scenario` that differs from the file name makes the ledger
invalid: the judgment is void, naming the file, the line and the problem (C-42), and `mint`
rejects (§8).

A pass or fail judgment appends one entry per run scenario that has a scenario id and no
identity reason (C-30), in scenario order, to the end of that scenario's file in the working
tree, creating it if absent. It never rewrites earlier bytes. An excluded scenario, a scenario
with an identity reason, and every scenario of a void or refused judgment get no entry. The
order of entries within a file is the order of judgments; entries carry no time.

### 7.2 Evidence

A scenario's evidence is derived from its entries in file order, this judgment's entry last
(`gate-c7r.7` implements it):

- No `green` entry: **seen-red** if any entry is `red`, else **none**. A `broken` entry is
  never red-first evidence (C-2).
- Let the first `green` entry be at product commit G:
  - **counted** if a `red` entry before it has a product commit other than G (C-7);
  - else **rejected** with reason `seen-red-only-at-first-green-commit` if a `red` entry
    before it exists (C-37);
  - else **rejected** with reason `never-seen-red` (`sg-397.2`, `sg-397.3`).

Entries after the first green never change counted or rejected. Rejected is permanent for that
id; the way out is a new id, seen red (D-20).

### 7.3 Example

The ledger at S of the worked example, then the bytes the fail judgment of §5.3 appended
(P0 = `1a2b…9a0b`, P1 = `5e0c…6d8a`).

`ledger/sgs-8cda.jsonl`, first line at S, second appended:

```jsonl
{"judge":"v0","judge_sha256":"7d865e959b2466918c9863afca942d0fb89d7c9ac0c99bafc3749504ded97730","product":"1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b","result":"red","scenario":"sgs-8cda","spec":"9b14a59c0d2e4f6a8b1c3d5e7f9a0b2c4d6e8f1a"}
{"judge":"v0","judge_sha256":"7d865e959b2466918c9863afca942d0fb89d7c9ac0c99bafc3749504ded97730","product":"5e0c2a9f4b7d1e3a6c8f0b2d4e6a8c0e2f4b6d8a","result":"green","scenario":"sgs-8cda","spec":"c4d1f7a2e9b3c5d7f1a3e5b7d9f1a3c5e7b9d1f3"}
```

`ledger/sgs-k3f2.jsonl`, created by the judgment:

```jsonl
{"judge":"v0","judge_sha256":"7d865e959b2466918c9863afca942d0fb89d7c9ac0c99bafc3749504ded97730","product":"5e0c2a9f4b7d1e3a6c8f0b2d4e6a8c0e2f4b6d8a","result":"broken","scenario":"sgs-k3f2","spec":"c4d1f7a2e9b3c5d7f1a3e5b7d9f1a3c5e7b9d1f3"}
```

`ledger/sgs-q9wz.jsonl`, first line at S, second appended:

```jsonl
{"judge":"v0","judge_sha256":"7d865e959b2466918c9863afca942d0fb89d7c9ac0c99bafc3749504ded97730","product":"1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b","result":"green","scenario":"sgs-q9wz","spec":"9b14a59c0d2e4f6a8b1c3d5e7f9a0b2c4d6e8f1a"}
{"judge":"v0","judge_sha256":"7d865e959b2466918c9863afca942d0fb89d7c9ac0c99bafc3749504ded97730","product":"5e0c2a9f4b7d1e3a6c8f0b2d4e6a8c0e2f4b6d8a","result":"red","scenario":"sgs-q9wz","spec":"c4d1f7a2e9b3c5d7f1a3e5b7d9f1a3c5e7b9d1f3"}
```

`sgs-8cda` is counted: red at P0, then first green at P1. `sgs-q9wz` is rejected, `never-seen-red`:
its first entry is a green; the later red does not rescue it. `sgs-2b7m` is excluded and has no
file.

## 8. Mint

`spec-gate mint --spec <dir>` works on the working tree of `<dir>` with no git access (C-39). It
reads `spec-gate.toml` (`[mint] prefix`), every `features/**/*.feature` and the ledger. It does not
check the pin (C-12).

It **rejects** (status 6), changing no file, when it finds any of: `config-invalid`
(`spec-gate.toml` does not parse, or `[mint] prefix` is missing or invalid); `ledger-invalid`
(§7.1); `feature-unparseable` or `construct-refused` (§4, phase 3; C-22, C-28); or, over every
scenario, `multiple-ids`, `unparseable-id` or `duplicate-id` (C-21). It writes every cause found
to stderr, one per line:

```
<file>[:<line>]: <kind>: <message>
```

```
features/basket.feature:12: construct-refused: scenario-outline "Totals by region" is refused in v0
```

Otherwise it **succeeds** (status 0). For each scenario without an `@id` tag, in path then line
order, it mints a new id unique against every scenario id in the feature files and every id in
`ledger/` (C-3), seeded as C-20 and C-34 fix. It inserts one line directly above the
scenario's `Scenario:` line: that line's leading whitespace, `@id:<id>`, and that line's line
ending. No other byte of any file changes (C-32). It writes one line to stdout per minted id,
giving the inserted line's number in the file after minting:

```
<file>:<line>: @id:<id>
```

```
features/red-first.feature:3: @id:sgs-4tq1
```

The driver checks the files, not this output (C-26).

## 9. Flagged and open

- **A-1. Green is strict** (clarify Q1). §6.3 counts a scenario green only when every step of
  the scenario at S is listed as passed and every hook passed; a missing step or a failed hook
  is broken. A looser rule would let a scenario whose before hook failed (`"before":
  [{"status": "failed"}]`, `"steps": []`) record its first green with no step run. If the
  operator wants a looser rule, the cost of this one is a false red, never a false green.
- **A-2. Unknown statuses are malformed** (clarify Q3). `pending`, which `cucumber` 0.23 defines
  but never writes, voids the judgment rather than counting as broken.
- **A-3. Exit statuses** (clarify Q4). The contract statuses avoid 1, 2, 101, 126, 127 and 128
  and above; a verdict document is required with every `judge` status but 7. `mint` success
  shares 0 with pass: a do-nothing binary that exits 0 is caught by the files the driver checks,
  as the clarify answer's own exception for pass is caught by the verdict document.
- **A-4. Where a verdict cannot name the excluded scenarios.** C-1 says every verdict names each
  excluded scenario. Four cases cannot, because what naming them needs does not exist or cannot
  be read: refused acts before any other read (C-40, `gate-c7r.11`), so its `scenarios` is `[]`;
  a void whose phase 2 found no S (`spec-not-a-repository`, `spec-main-missing`) has no tree to
  read, so its `scenarios` is `[]`; a `config-invalid` void whose `[scope] excluded_criteria`
  cannot be read lists every scenario as `not-judged`; a feature file that does not parse
  contributes no scenario. Every other verdict names each excluded scenario, `spec-dirty` and
  `spec-not-on-main` included, because phase 3 reads S whenever phase 2 finds it (§4).
- **A-5. `[sut] build` is an argument vector**, so both commands run without a shell and quote
  exactly. On `main` it is a shell string. The operator approved replacing only the `suite` key,
  so this change to gate config is decided at the operator's merge.
- **A-6. `[judge] release` is required.** Every ledger entry names it, so a missing value is
  void, `config-invalid`, although C-42 does not list it.
- **A-7.** A `CARGO_TARGET_DIR` in the judge's environment moves the product artifact away from
  `[sut] artifact`, so the judgment is void, `artifact-missing`.
- **A-8. The examples are not checked.** No check reads this document's example documents or
  the exit-status table yet; `gate-c7r.13` adds one.
- **Q-2. `fail_on_skipped`, for the operator** (clarify Q2). The key stays in `[gates]
  acceptance` byte for byte, and the judge does not read it. It is not inert for the harness:
  run against the worked example, `cucumber` 0.23 wrote line 13's status as `"undefined"` with
  `fail_on_skipped` and as `"skipped"` without it. The verdict is the same either way (§6.3).
  The recommendation is to remove the key and have the harness always set `fail_on_skipped`;
  removing it is a gate-config change that needs the operator's approval. Until then the
  harness sets `fail_on_skipped` (§6.1) whatever the key says.
