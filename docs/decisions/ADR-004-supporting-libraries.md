# ADR-004 — Supporting libraries

## Status

Accepted — 2026-07-20. Individually revisable without a new ADR **except** where marked frozen.

## Context

Substage 2.12.2 groups the lower-risk dependency choices into one ADR rather than writing eight.
The high-consequence choices have their own: state management (ADR-001), sync target (ADR-002),
database (ADR-003).

**Every dependency is a long-term liability.** This project is maintained infrequently over years by
one person, so the default answer to "should we add a package?" is no, and three candidates below
are rejected in favour of writing the code.

### Binding constraints on every entry

| # | Constraint |
|---|---|
| L1 | **No analytics, crash reporting, advertising or telemetry package, at any stage** — NG-04, NG-08, NFR-01. Checked **transitively**, not only among direct dependencies (guard G6) |
| L2 | Licence must be permissive — MIT, BSD or Apache-2.0. **A copyleft licence on any dependency is a blocker** requiring a new ADR. Verified per package at substage 3.3.6 |
| L3 | **No version is pinned in this document.** Versions are resolved from pub.dev at Stage 3 and recorded in `DEPENDENCIES.md` (substage 2.12.5) |
| L4 | Every entry states a purpose, a maintenance signal and an exit plan |

## Decisions

### Adopted

| Purpose | Package | Maintenance signal | Exit plan |
|---|---|---|---|
| **State management + DI** | `riverpod` / `flutter_riverpod` with `riverpod_generator` | Stable 3.x line, actively maintained (checked 2026-07-20) | ADR-001. Blast radius is application + presentation only |
| **Database** | `drift` with `drift_dev` | Actively maintained (checked 2026-07-20) | ADR-003 — sqflite against the same SQLite file, no data migration |
| **Google sign-in** | `google_sign_in` | Official Flutter team package | The `RemoteStore` boundary (substage 7.2) keeps auth confined to `lib/data/auth/` |
| **Drive client** | `googleapis` (Drive v3) + `googleapis_auth` | Official Google-maintained Dart clients | Only `data/sync/adapters/drive/` may import it (guard added at 7.2.5). Swapping providers means rewriting one directory |
| **UUID generation** | `uuid` | Long-established, widely depended on | Trivial to replace; v4 and v7 are short, well-specified algorithms |
| **Connectivity detection** | `connectivity_plus` | Flutter Community maintained | Used only to *trigger* a sync attempt, never to gate one. If it were removed, sync falls back to foreground and manual triggers with no correctness impact |
| **File paths** | `path_provider` | Official Flutter team package | No realistic alternative needed; official |
| **Share sheet for exports** | `share_plus` | Flutter Community maintained | Export could fall back to a save-to-location flow |
| **Background scheduling** | `workmanager` | Flutter Community maintained, actively used | **See "Verify at Stage 3" below** |
| **Mocking in tests** | `mocktail` | Actively maintained; no code generation, unlike `mockito` | Test-only. Hand-written fakes already cover `Clock`, `IdGenerator` and `RemoteStore` (substage 3.8), so the exposure is small |
| **Charting** | `fl_chart` | Widely used, actively maintained | Presentation-only. Substage 8.4.3 requires an accessible **tabular equivalent for every chart** regardless — so if the library were dropped, the data is already presentable without it |

### Rejected in favour of writing the code

| Candidate | Rejected because |
|---|---|
| **A CSV package** | RFC 4180 escaping is roughly thirty lines. Substage 8.5 makes specific demands a general library would fight: amounts must be written from integer minor units with **no floating-point intermediate** (INV-01), the byte-order-mark decision must be deliberate and documented, and escaping must round-trip a category name containing a comma, a quote **and** a newline. Writing it means those decisions are explicit and tested rather than inherited |
| **A separate DI container** (`get_it`, `injectable`) | Riverpod already provides dependency injection with override-based substitution, which is exactly what ADR-001's criterion C6 selected it for. A second mechanism would mean two ways to obtain a dependency and no rule about which to use |
| **A JSON serialisation generator** (`json_serializable`) | The only serialised structures are the backup export (SCHEMA §7) and the sync payload (SCHEMA §8). Both have **hand-specified formats with rules a generator would not honour** — nulls explicit rather than omitted, unknown fields preserved rather than dropped, integers never rendered as decimals. Hand-written serialisation for a dozen record types, with round-trip tests, is the safer trade |

### Verify at Stage 3, with the fallback already chosen

Two entries carry genuine uncertainty. Both are recorded here rather than discovered at
implementation time.

**Property-based testing — `glados` (candidate).** Dart's property-testing ecosystem is thin.
`glados` is the established option and provides automatic **shrinking**, which is its real value:
substage 5.9.5 requires shrinking every failure to a minimal reproduction and adding it as a
permanent vector. However, its most recent changelog entry appears to date from late 2023 — a weak
maintenance signal by L4's standard.

> **Fallback, if it proves unmaintained: hand-rolled generators with a seeded PRNG.** This is not a
> downgrade. Substage 5.9.1 already demands very specific generators — adversarial redirect graphs
> with deliberate cycles, already-over-ceiling balances, valid basis-point splits totalling exactly
> 10000 at both levels — which no general library would supply. Substage 5.9.4 requires recording
> the seed, which a hand-rolled generator gives directly. Only shrinking would be lost, and it can
> be done manually for the handful of failures expected.
>
> **The seven properties P1–P7 are defined in ALLOCATION_ALGORITHM §9.2 independently of any
> library**, so this choice cannot affect what is verified — only how.

**Background scheduling — `workmanager`.** Android-only, which suits an Android-only v1. Substage
7.7.4 wants four triggers: connectivity regained, app foregrounded, a periodic interval, and manual
pull-to-refresh. Three of those need no background execution at all.

> **Fallback: drop the periodic background trigger.** The app would sync on foreground, on
> connectivity change, and on demand. Given that this is a budgeting app opened most days, and that
> INV-06 makes sync background reconciliation the user never waits for, losing the periodic trigger
> costs very little. **No correctness property depends on it** — convergence is guaranteed by the
> merge design, not by sync frequency.

## The no-telemetry constraint, as a decision rather than an intention

**No analytics, crash reporting, advertising or telemetry dependency may be added at any stage of
this project.** Not "we do not plan to add one" — it is a design decision with a mechanical check
behind it.

- Guard **G6** fails the build if a known package of that kind appears anywhere in the **resolved**
  dependency tree, including transitively (ARCHITECTURE §2.3).
- Substage 3.3.7 inspects the resolved tree, not just direct dependencies.
- Substage 7.10.3 re-verifies and requires the guard to be **demonstrated failing** on a deliberate
  addition.
- Substage 9.7.2 repeats the check on the release build.
- Substage 10.8's `must_not` forbids adding analytics at the last minute to monitor the launch — the
  moment the temptation is strongest.

The operational consequence is accepted and recorded in PRD §6.10: **the developer has no visibility
into post-release failures.** That is the deliberate trade, and substage 10.8.8 plans around it by
making it easy to contact the developer from inside the app.

## Consequences

- **Eleven adopted dependencies, three deliberately declined.** The declined ones (CSV, DI, JSON
  codegen) are all cases where the design has specific requirements a general library would not
  honour, and where the hand-written version is small enough to test thoroughly.
- Two carry Stage 3 verification with a pre-decided fallback, so neither can become a mid-stage
  surprise.
- `DEPENDENCIES.md` (substage 3.3.6) records what was actually resolved: package, version, purpose,
  licence, the ADR that justified it, maintenance signal and exit plan.
- Substage 3.3.2 re-checks the `minSdk` floor once these plugins are present, since Google Sign-In
  is the most likely to raise it.

## Date

2026-07-20
