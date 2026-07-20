# ADR-001 — State management approach

## Status

Accepted — 2026-07-20. Supersedes nothing. Frozen for Stage 3 onward; changing it requires a new ADR.

## Context

PookieBudget's presentation layer must connect roughly 21 screens to a local database, a pure
allocation engine, and (from Stage 7) a background sync worker that mutates the database underneath
a visible screen. The choice of state management determines how testable the app is, how derived
state is expressed, and whether background mutations reach the UI without extra plumbing.

Three constraints from earlier stages shape the decision before any candidate is named:

- **The business logic is not in the state layer.** INV-08 requires the allocation engine to be a
  pure function in the domain layer with no Flutter, no I/O and no clock. Whatever is chosen, it
  orchestrates; it never computes a split. This substantially reduces how much the choice matters
  for correctness — but it raises how much it matters for *derived state*, because nearly every
  screen shows values derived from a ledger stream.
- **Background mutation is the case that actually matters.** From Stage 7, sync writes to the
  database while the dashboard is on screen. INV-06 forbids blocking the UI on the network, and
  FR-13 requires the dashboard to reflect changes without a manual refresh. A design that handles
  only user-initiated mutation is insufficient.
- **NFR-06 P-07 budgets 100 ms from keystroke to updated allocation preview at 40 categories.** The
  preview re-derives on every keystroke, so rebuild scope is a performance concern, not a style one.

### Evaluation criteria, fixed before candidates were considered

| # | Criterion | Why it matters here |
|---|---|---|
| C1 | Testability of business logic without Flutter bindings | Domain tests must run headless in CI. Partly neutralised by layering, but the *application* layer must also be testable without pumping widgets. |
| C2 | Ergonomics for reactive streams from a local database | Every money-bearing screen watches a query. Stage 4 exposes streams; the state layer must consume them naturally. |
| C3 | Expressing derived state | A balance is derived from a ledger stream (INV-04); ceiling progress is derived from a balance; an account total is derived from several balances. Chained derivation is the dominant shape in this app. |
| C4 | Boilerplate cost across ~21 screens | A solo developer maintains this. Ceremony multiplied by 21 is a real cost. |
| C5 | Maintenance signal and community size | This app is expected to live for years with infrequent maintenance. |
| C6 | Ease of injecting fakes for `Clock`, `IdGenerator` and repositories | Stage 3.8 builds these fakes; Stages 4–6 depend on substituting them cleanly. |

## Decision

**Riverpod** (3.x line), using code generation for providers.

The application layer is composed of providers that expose repository streams and use-case results.
Widgets read providers; they never construct a repository, touch the database, or call the engine
directly.

### Boundaries of the state layer

**Held in state:** the active scope (personal or business), onboarding progress, the in-flight income
draft (amount, label, date, any manual overrides), transient UI state (filters, selected period),
and the sync status surface.

**Never held in state — always re-derived from the database on demand:** every balance, every
account total, every report figure, and every ceiling progress value. INV-04 makes balances derived
values; caching them in the state layer would create a second, unverifiable copy. Where a cache is
needed for performance it lives in the data layer with the recompute-and-compare path required by
substage 2.4.5, not in a provider.

**Use cases** live in the application layer and are invoked from widgets only through providers. A
use case orchestrates — gather balances, call the engine, write atomically — and contains no
allocation arithmetic.

### How a background sync mutation reaches a visible screen

This is the case the decision turns on, so it is specified rather than assumed:

1. The sync worker writes to the database through the same repository API as any other writer.
2. The database's own change notification causes every open query stream over the affected tables to
   re-emit.
3. `StreamProvider`s wrapping those queries emit new values.
4. Widgets watching those providers rebuild.

No step involves the UI polling, subscribing manually, or being told by the sync worker that
something changed. The sync layer has **no reference to the presentation layer at all** — the
database is the only coupling. Stage 4 substage 4.4.4 requires a test that mutates through a second
code path and asserts the stream emits; Stage 6 substage 6.1.3 requires the same assertion at the
screen level.

## Alternatives considered

### Bloc (flutter_bloc 9.x) — the serious runner-up

Actively maintained, mature, with `bloc_concurrency` transformers (`droppable`, `restartable`,
`sequential`) that would suit the debounced allocation preview well. It is frequently recommended
for financial applications specifically, on the grounds that an explicit event log suits audit
requirements.

**Why not, specifically:**

1. **The audit argument does not apply here.** The reason Bloc is recommended for financial apps is
   that its event stream forms an audit trail. This app's audit trail is the append-only ledger
   (INV-03) — a durable, queryable, user-visible record that survives process death. A Bloc event
   log is in-memory and dies with the process. Adopting Bloc for auditability would buy a second,
   weaker audit mechanism that duplicates one the design already mandates.
2. **Derived state is the dominant shape, and it is where Bloc costs most.** The allocation preview
   is a pure function of (amount, configuration, balances). In Bloc that becomes an event class, a
   state class, and a transition, for what is fundamentally a computed value. Multiplied across ~21
   screens where most values are derived rather than event-driven, the ceremony is significant for a
   solo maintainer (C3, C4).
3. **Chained database streams need manual lifecycle management.** Watching a ledger stream inside a
   Bloc means holding a `StreamSubscription`, forwarding events, and cancelling in `close()` — per
   Bloc, for every screen that watches a query. A missed cancellation is a leak that NFR-06 P-14
   would eventually catch, but only after it shipped. Riverpod's stream providers dispose by
   construction (C2).
4. **Fake injection is coarser.** Bloc composes dependencies through constructors, so substituting
   a fake `Clock` for one test means constructing the whole bloc graph. Riverpod's provider
   overrides substitute one node of the graph without touching the rest (C6).

Bloc's advantages — strict discipline across a large team, explicit concurrency transformers — are
real but address problems this project does not have. There is one developer, and the one place
concurrency control genuinely matters (debouncing the preview) is solvable directly.

### Provider (the predecessor package)

Rejected. It solves dependency injection but not derived state: chained derivation requires manual
`ChangeNotifier` composition, and there is no compile-time guarantee that a widget reads a provider
that exists. Riverpod exists because of these limitations, and the migration path from Provider to
Riverpod is the one this project would eventually have to walk anyway.

### signals / other reactive primitives

Considered and rejected on C5. Smaller ecosystem and a shorter track record than either finalist.
For an app expected to receive infrequent maintenance over years, the maintenance signal outweighs
ergonomic novelty.

## Consequences

### Positive

- Derived state — the dominant shape in this app — is expressed directly, and chained derivation
  (ledger → balance → ceiling progress → dashboard row) composes without manual plumbing.
- Background sync mutations reach the UI through the database alone; the sync layer never references
  the presentation layer.
- Fakes for `Clock`, `IdGenerator` and each repository are substituted per-test by overriding one
  provider, which is what Stage 3.8's harness is built around.
- Application-layer logic is testable in a `ProviderContainer` with no widget pumping and no Flutter
  binding.

### Negative, and what is done about each

| Consequence | Mitigation |
|---|---|
| The provider graph is implicit. A widget can read a provider it has no business reading, and the layering guard (which checks *imports*) will not catch it, because everything is in the application layer. | Substage 6.1.1 requires a check that no widget constructs a repository or touches the database directly. Repository providers are declared private to the application layer and exposed only through use-case providers. |
| `ref.watch` at the wrong granularity causes rebuild storms. The allocation preview at 40 categories on every keystroke is exactly where this bites the P-07 budget. | The preview watches a single provider carrying the whole engine result, not one per category. Substage 6.4.2 requires debouncing; substage 9.6 measures P-07 on device. |
| Riverpod 3's offline persistence is experimental. | **Forbidden.** This app has its own persistence (Stage 4) and its own sync (Stage 7). No Riverpod persistence feature may be used at any stage. |
| Code generation adds a build step and a failure mode. | Substage 3.3.3 proves the generator runs end to end against a placeholder before any real code depends on it. |
| Provider overrides make it easy to write a test whose graph does not resemble production. | Flow tests (6.12) and journey tests (9.2) override only the outermost boundaries — the clock, ids, and the remote store — never repositories or use cases. |

### Neutral

- The choice does not affect the allocation engine, which is pure domain code and imports nothing
  from this layer. If this ADR were ever reversed, the engine, the data layer and the tests for both
  would be unaffected — the blast radius is the application and presentation layers only.

## Date

2026-07-20
