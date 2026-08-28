# Working agreement — how this project is built

Everything here is either the user's stated preference or a convention already established across
28 commits. Follow it; do not re-derive it.

---

## 1. The method

The project is built from a **staged agent plan** in `prompts/`. A working session needs exactly
**two files**:

1. `prompts/00_project_manifest.json` — shared context. Requirement IDs (`FR-xx`, `NFR-xx`,
   `INV-xx`, `OQ-xx`, `R-xx`), personas, glossary, engineering conventions, predefined categories.
   **Load this first, every time.**
2. `prompts/stage_NN_<name>.json` — exactly one stage file.

Then work its `substages` array **strictly in order, one substage per session**. Do not parallelise,
do not skip ahead, do not start a substage whose predecessor is not ticked off.

### Each substage carries

| Field | Meaning |
|---|---|
| `goal`, `why_it_matters` | What and why |
| `entry_criteria` | Must hold before starting |
| `work` | Numbered steps, each with sub-details |
| `acceptance_criteria` | **What you must demonstrably meet** |
| `must_not` | Hard prohibitions |
| `common_pitfalls` | Real failure modes — treat as a checklist, they are specific and they bite |
| `traceability` | Which FR/NFR/INV this covers |
| `checkpoint` | What to do at the end, and what to escalate |

### The substage loop

1. Read the manifest and the stage file's substage.
2. Read the design documents it references (`SCHEMA.md`, `ARCHITECTURE.md`,
   `ALLOCATION_ALGORITHM.md`, `PRD.md`) — **the actual sections**, not from memory.
3. Implement.
4. Run `pwsh tool/check.ps1` (see [`ENVIRONMENT_BLOCKER.md`](ENVIRONMENT_BLOCKER.md) — currently
   impossible).
5. Append an evidence entry to `docs/reports/STAGE_N_WORKLOG.md`, with an
   acceptance-criteria table.
6. Tick the substage off in the worklog's status table.
7. **Commit.**
8. Continue to the next substage. No user approval needed between substages.

**The final substage of each stage** assembles the stage report and **stops for user approval**
before the next stage file is opened.

### Escalate immediately if

- An open question (`OQ-xx`) blocks the work in front of you.
- A global invariant (`INV-xx`) cannot be satisfied as designed.
- **The substage reveals that an earlier approved stage is wrong.**

That third one has fired twice in Stage 4 (ADR-006, ADR-007). The correct response is in §4 below.

---

## 2. The user's stated preferences

> **"also commit after each stage"**

One commit per substage, on branch `v1.0`. `v1.0` is also the main branch — this project commits
substages directly to it rather than branching per substage. Push when asked.

> **"read, analyze and understand the code first, then go through the prompts, then see which
> stages have been completed, then start working on it stage by stage continuing from last
> completed stage."**

Orient before acting. Git history is a reliable index of completed substages; the worklog is the
detailed record.

Other expectations, inferred from how the project is written and confirmed across the session:

- **Be honest about what is unverified.** The user has accepted four amber substages on the explicit
  condition that they are labelled as such. Do not quietly upgrade them.
- **Flag deviations, do not bury them.** Every departure from an approved document is recorded in
  the worklog and, where it amends a document, in an ADR.

---

## 3. Commit convention

Conventional Commits. Scope reflects the layer.

```
feat(data): repository interfaces, CRUD and row mappers (substage 4.4)

<body: what changed and, more importantly, WHY each non-obvious decision
went that way. Multi-paragraph is normal and expected in this repo.>

<any honest caveat, e.g. NOT VERIFIED and why>

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

Established scopes: `docs(prd)`, `design(architecture)`, `design(schema)`, `design(engine)`,
`design(sync)`, `design(navigation)`, `design(tech)`, `feat(scaffold)`, `feat(domain)`,
`feat(data)`, `fix(schema)`, `chore`.

Tag at each approved gate: `v0.<stage>.0`.

---

## 4. When a design document is wrong

The manifest's `sdlc_discipline` is explicit:

> do not silently patch forward: raise it, amend the earlier document, and note the amendment in the
> decision log.

So the procedure is:

1. **Write an ADR** in `docs/decisions/ADR-NNN-<slug>.md`. Follow the shape of ADR-005 or ADR-007:
   Status · Context · Decision · Alternatives considered · Consequences (positive/negative/neutral) ·
   Date. State plainly what the alternatives were and why each was rejected.
2. **Amend the source document**, with a pointer to the ADR at the point of change.
3. **Record it in the worklog**, in the substage that found it.
4. Note any downstream artefact that must be regenerated (e.g. ADR-007 invalidates
   `STAGE_4_SCHEMA_COMPARISON.md`, which 4.11 must rebuild).

Next free ADR number: **ADR-008**.

---

## 5. Code conventions

Enforced by `analysis_options.yaml` and the six guards. The ones that surprise people:

- **Explicit types on locals.** `final String trimmed = ...`, not `final trimmed = ...`. The repo is
  uniform about this; `omit_local_variable_types` is off deliberately because explicit types read
  better in money code.
- **Explicit generic arguments on literals.** `<String>[...]`, `<String, int>{...}`.
- **`package:` imports for library code**, relative imports for test helpers (matches
  `test/support/harness_test.dart`).
- **Single quotes.** `directives_ordering` alphabetical.
- **80-column code.** `dart format` enforces it and CI fails on any difference
  (`--set-exit-if-changed`). String literals are exempt because the formatter cannot split them.
- `unused_import` is promoted to an **error**.
- `strict-casts`, `strict-inference`, `strict-raw-types` are all on.

### The house style for comments

This codebase comments **why**, at length, and it is worth matching. Look at any file in
`lib/domain/entities/` or `lib/data/repositories/`. The pattern:

- Every non-obvious decision names the alternative it rejected and the failure that alternative
  would cause.
- Rule identifiers are cited inline — `INV-03`, `V-20`, `C-15`, `U-04`, `Q7`, `IX-01` — so a reader
  can trace any line back to the document that required it.
- Comments explain consequences in terms of user-visible harm, not mechanics: *"a dashboard that
  dropped it would silently hide a bucket the user created and has not funded yet."*

Test names shout the load-bearing ones in caps: `THE ROW SURVIVES, CARRYING A TOMBSTONE`.

---

## 6. Testing conventions

- **In-memory database** for every data-layer test: `openTestDatabase()` in
  `test/support/test_database.dart`. It forces the connection open so `beforeOpen` runs and
  `PRAGMA foreign_keys = ON` actually applies.
- **Never read the system clock.** Use `FakeClock`. Use `FakeIdGenerator` for deterministic ids.
- **Builders, not literals.** `test/support/builders/config_builders.dart` and
  `movement_builders.dart`. They unwrap `Result` and throw on failure, so an invalid default is a
  loud failure in the builder rather than a quiet one in an assertion.
- **Read past the repository when testing the repository.** `rawRow` / `rawCount` bypass every
  filter — a hard delete and a correctly filtered soft delete look identical through the API.
- **Reactive-stream tests must drain the event queue** between subscribing and writing.
  `stream.take(2).toList()` races and hangs; see the `_Recorder` helper in
  `test/data/repositories/category_repository_test.dart`.
- **A guard that has never failed has never been tested.** Where a test is itself a guard (the
  interface-purity scan, the append-only design test), include a self-test proving it catches a
  deliberate violation.
