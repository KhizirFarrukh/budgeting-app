# PookieBudget

An Android app that automatically splits every incoming payment across user-defined personal and
business money buckets, with per-bucket ceilings, overflow redirection, and optional sync to the
user's own Google account.

> **Status: Stage 3 of 10 — project scaffolding.**
> No features are implemented yet. This README is a placeholder; substage 10.7.1 writes the real
> one, including setup from a clean machine, how to run the checks, and the docs index.

## Documentation

The design is complete and precedes the code. Read in this order:

| Document | What it covers |
|---|---|
| [docs/PRD.md](docs/PRD.md) | Requirements: personas, journeys, scope, the money model, 37 user stories, measurable NFRs |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Layers, the dependency rule, the six guards, directory tree, sync design, performance design |
| [docs/SCHEMA.md](docs/SCHEMA.md) | Thirteen tables, constraints, indexes, validation rules, the remote payload format |
| [docs/ALLOCATION_ALGORITHM.md](docs/ALLOCATION_ALGORITHM.md) | The engine — contracts, phase A and B, overrides, error taxonomy, fifteen golden vectors |
| [docs/NAVIGATION.md](docs/NAVIGATION.md) | 22 screens, the navigation graph, back behaviour, per-screen states |
| [docs/decisions/](docs/decisions/) | ADR-001 state management · ADR-002 sync target · ADR-003 database · ADR-004 libraries |
| [docs/TRACEABILITY.md](docs/TRACEABILITY.md) | Every requirement to its design artefact and verifying test |
| [docs/OPEN_QUESTIONS.md](docs/OPEN_QUESTIONS.md) · [docs/ASSUMPTIONS.md](docs/ASSUMPTIONS.md) | What is undecided, and what is assumed with its impact if wrong |

## The rules that matter

Twelve invariants govern this codebase; [CONTRIBUTING.md](CONTRIBUTING.md) will state them in full
at substage 10.7.5. The four that break the product if violated:

- **All money is int64 in the currency's minor unit.** No `double`, `float` or `num` anywhere on the
  money path — including intermediates, test fixtures and export files.
- **The ledger is append-only.** Corrections are compensating entries. Nothing is ever edited or
  deleted.
- **Balances are derived**, never authoritative. Any cache must be reproducible by full recomputation.
- **Allocation is pure and deterministic.** The engine performs no I/O and never reads a clock.

## Build

Requires the Flutter SDK and the Android SDK. Exact versions in
[docs/ENVIRONMENT.md](docs/ENVIRONMENT.md).

```
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```
