# Handoff — START HERE

If you are a fresh agent or developer picking this project up with no prior conversation, **read
this file first, then the four files it points at, in order.** Together they are designed to replace
a lost chat history entirely.

---

## The 60-second version

**PookieBudget** is a Flutter/Android personal-and-business budgeting app. Money arriving is split
automatically across user-defined buckets by percentage, with per-bucket ceilings, overflow
redirection, and sync only to the user's own Google account.

It is being built through a **staged agent plan** in `prompts/` — 10 stages, 98 substages, worked
strictly in order, one substage per working session.

| | |
|---|---|
| **Current position** | Stage 4 (Core Data Layer), substage **4.8 complete** |
| **Next action** | Substage **4.9** — Migrations, export and backup |
| **Branch** | `v1.0` (this is also the main branch — the project commits substages directly to it) |
| **Blocking problem** | **No Dart/Flutter SDK on this machine.** Substages 4.4–4.8 are written but have never been compiled or run. See [`ENVIRONMENT_BLOCKER.md`](ENVIRONMENT_BLOCKER.md) |

---

## Read these, in this order

| # | File | What it answers |
|---|---|---|
| 1 | [`ENVIRONMENT_BLOCKER.md`](ENVIRONMENT_BLOCKER.md) | Why nothing has been verified, and exactly what to run once a toolchain exists. **Read before writing any code.** |
| 2 | [`PROJECT_STATE.md`](PROJECT_STATE.md) | Every stage and substage, its status, and what was built |
| 3 | [`WORKING_AGREEMENT.md`](WORKING_AGREEMENT.md) | How this project is worked: the prompt files, the substage loop, commit convention, code style, the user's stated preferences |
| 4 | [`TODO.md`](TODO.md) | Every outstanding obligation, with the stage that owns it |
| 5 | [`SESSION_LOG.md`](SESSION_LOG.md) | What happened in the sessions that produced 4.4–4.8, and why each significant decision went the way it did |

---

## The one thing most likely to mislead you

Substages 4.4 through 4.8 are marked **🟡 amber**, not ✅ green, in
`docs/reports/STAGE_4_WORKLOG.md`. That is deliberate and it is not pedantry.

The code is complete and carefully written, but **no part of it has been compiled, analysed,
formatted or tested** — the machine it was written on has no Dart SDK. Every acceptance criterion in
those substages is recorded as *"not run"* rather than ticked.

Do not treat those substages as done. Do not build a sixth unverified substage on top of five
others without saying so. The honest next move is to run the verification sequence in
[`ENVIRONMENT_BLOCKER.md`](ENVIRONMENT_BLOCKER.md) on a machine that has the SDK, fix what it
reports, and only then continue to 4.9.

---

## Where the real documents live

This handoff pack is a **map, not a source of truth**. The authoritative documents are:

| Document | Authority over |
|---|---|
| `prompts/00_project_manifest.json` | Requirement IDs (FR/NFR/INV/OQ/R), personas, glossary, the predefined categories |
| `prompts/stage_NN_*.json` | The work itself — each stage's substages, steps, acceptance criteria, `must_not`, pitfalls |
| `docs/PRD.md` | Requirements, user stories, NFR budgets, volume profiles |
| `docs/ARCHITECTURE.md` | Layering, the dependency rule, the six guards, directory tree |
| `docs/SCHEMA.md` | Every table, column, constraint, index, validation rule, the balance policy |
| `docs/ALLOCATION_ALGORITHM.md` | The engine: contracts, phases, redirects, reversals, error taxonomy, 19 golden vectors |
| `docs/decisions/ADR-*.md` | Decisions that amend any of the above |
| `docs/reports/STAGE_N_WORKLOG.md` | Evidence log, one entry per substage — **the detailed record** |

When this pack and one of those disagree, **the document above wins** and this pack is stale. Fix it.
