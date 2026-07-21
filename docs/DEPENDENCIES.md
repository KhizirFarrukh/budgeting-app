# Dependencies

Recorded in substage 3.3.6. **Every version below was resolved from pub.dev on 2026-07-21**, not
pasted from memory (substage 2.12.5 and the manifest's knowledge-freshness rule).

`ADR-004` constraint **L2** requires a permissive licence — MIT, BSD or Apache-2.0. A copyleft
licence on any dependency is a blocker requiring a new ADR.

**149 packages resolve in total.** The direct dependencies are below; the rest are transitive.

---

## 1. Runtime dependencies

| Package | Version | Purpose | ADR | Exit plan |
|---|---|---|---|---|
| `flutter_riverpod` | 3.3.2 | State management and DI | ADR-001 | Blast radius is application + presentation only; domain and data are untouched |
| `riverpod_annotation` | 4.0.3 | Provider code generation annotations | ADR-001 | Hand-write providers instead |
| `drift` | 2.34.2 | Local database, type-safe queries, reactive streams | ADR-003 | sqflite against **the same SQLite file** — same SQL, same constraints, **no data migration** |
| `drift_flutter` | 0.3.1 | Flutter path handling for Drift | ADR-003 | Resolve the database path with `path_provider` directly |
| `path_provider` | 2.1.6 | Platform directories | ADR-004 | Official Flutter package; no realistic need |
| `path` | 1.9.1 | Path manipulation | ADR-004 | Dart team package |
| `uuid` | 4.6.0 | Client-generated identifiers, **v4 and v7** | ADR-004 | Short, well-specified algorithms; trivial to inline |
| `go_router` | 17.3.0 | Declarative routing | NAVIGATION §3 | Navigator 2.0 directly, at the cost of hand-written redirect logic |
| `intl` | 0.20.3 | Locale-aware number and date formatting | ADR-004 | Presentation only. Money **serialisation** does not use it (ARCHITECTURE §8.5) |
| `google_sign_in` | latest | Optional authentication | ADR-004 | Confined to `lib/data/auth/` |
| `googleapis` | latest | Drive v3 client | ADR-002 | Only `data/sync/adapters/drive/` may import it |
| `googleapis_auth` | latest | OAuth token handling | ADR-002 | As above |
| `connectivity_plus` | latest | Detects reconnection to **trigger** a sync | ADR-004 | Sync falls back to foreground and manual triggers, with no correctness impact |
| `share_plus` | latest | Export via the system share sheet | ADR-004 | Save-to-location flow instead |
| `workmanager` | 0.9.x | Periodic background sync | ADR-004 | **Fallback pre-decided** — drop the periodic trigger; no correctness property depends on sync frequency |
| `fl_chart` | latest | Report charts | ADR-004 | Presentation only. Substage 8.4.3 requires an accessible **tabular equivalent for every chart** regardless, so the data is already presentable without it |
| `cupertino_icons` | 1.0.8 | Icon font (Flutter default) | — | Removable |

## 2. Development dependencies

| Package | Version | Purpose | Exit plan |
|---|---|---|---|
| `build_runner` | latest | Code generation driver | Required by Drift and Riverpod generators |
| `drift_dev` | latest | Drift code generator | Hand-write the database classes |
| `riverpod_generator` | latest | Riverpod provider generator | Hand-write providers |
| `mocktail` | latest | Mocking, **no code generation** | Hand-written fakes already cover `Clock`, `IdGenerator` and `RemoteStore` (substage 3.8), so exposure is small |
| `flutter_lints` | 6.0.0 | Baseline lint set | Built on by `analysis_options.yaml` |
| `flutter_test` | SDK | Test framework | — |

## 3. Deliberately **not** added

| Candidate | Why not |
|---|---|
| **A CSV package** | ADR-004. Substage 8.5 demands amounts written from integer minor units with no floating-point intermediate, a deliberate byte-order-mark decision, and escaping that round-trips a category name containing a comma, a quote **and** a newline. RFC 4180 escaping is ~30 lines; writing it makes those decisions explicit and tested |
| **A DI container** (`get_it`, `injectable`) | ADR-004. Riverpod already provides override-based injection — the reason ADR-001 chose it (criterion C6). A second mechanism means two ways to obtain a dependency and no rule about which |
| **A JSON generator** (`json_serializable`) | ADR-004. The backup and sync formats have hand-specified rules a generator would not honour: nulls explicit rather than omitted, unknown fields preserved rather than dropped, integers never rendered as decimals |

---

## 4. Findings — three dependencies rejected or dropped during resolution

Substage 3.3.6 requires flagging any dependency that is unmaintained or discontinued, and either
replacing it or recording why it is acceptable. Three came up.

### 4.1 `sqlite3_flutter_libs` — discontinued, removed

Added initially, then **removed**. pub.dev resolved it as `0.6.0+eol`, and the `+eol` suffix is the
signal: **from version 0.6.0 the package does nothing at all.** It exists only so that libraries
depending on it can move to `package:sqlite3` 3.x without breaking.

From Drift 2.32.0 onward — this project resolves **2.34.2** — an up-to-date SQLite is bundled
automatically and the dependency is unnecessary. Removed.

### 4.2 `glados` — the ADR-004 fallback fired

Property-based testing. **Version solving failed:** it transitively requires `uuid ^3.0.6` and
declares a pre-null-safety SDK bound (`>=1.8.0 <2.0.0 or >=2.0.0 <3.0.0`), which is incompatible
with the current Riverpod stack and with `uuid` 4.x.

ADR-004 anticipated exactly this and pre-decided the fallback, so no decision was needed
mid-implementation:

> *"Fallback, if it proves unmaintained: hand-rolled generators with a seeded PRNG. This is not a
> downgrade. Substage 5.9.1 already demands very specific generators — adversarial redirect graphs
> with deliberate cycles, already-over-ceiling balances, valid basis-point splits totalling exactly
> 10000 at both levels — which no general library would supply."*

**Only automatic shrinking is lost**, and it can be done manually for the handful of failures
expected. **Properties P1–P7 are defined in `ALLOCATION_ALGORITHM.md` §9.2 independently of any
library**, so this changes *how* they are verified, never *what*.

### 4.3 `riverpod_lint` + `custom_lint` — dropped, and why the trade went that way

Both fail version solving against `uuid ^4.6.0`: `riverpod_lint` requires `analyzer ^12.0.0` and
`analyzer_plugin ^0.14.0`, and the resulting chain forces `uuid ^3.0.6`.

**The conflict is a genuine design trade, not a nuisance.** `uuid` 4.x is what provides **UUID v7**,
and ARCHITECTURE §8.6 assigns v7 to ledger entries and income events specifically for index
locality — PRD §7.2 shows those are **80–89% of all rows** at the Heavy profile. Downgrading `uuid`
to satisfy a lint plugin would mean giving up a decision made on measured grounds.

**The lint plugins lose.** They provide Riverpod-specific advice; they enforce none of the twelve
invariants. Those are enforced by guards G1–G6 (substage 3.4), which are this project's own and do
not depend on the analyzer plugin ecosystem.

Verified after the decision: `uuid` 4.6.0 does export v7 (`data.dart`, `uuid.dart`,
`uuid_value.dart`). **Re-check at Stage 6** — if the plugins become compatible, adding them is free.

---

## 5. No telemetry — verified, not assumed

ADR-004 constraint **L1**, checked over the **resolved** tree rather than direct dependencies
(substage 3.3.7):

```
scanned 149 resolved packages for:
  firebase_analytics, firebase_crashlytics, sentry, sentry_flutter, amplitude,
  mixpanel, appsflyer, google_mobile_ads, facebook_app_events, datadog,
  bugsnag, posthog, segment

result: clean — no analytics, crash reporting or advertising package present
```

Guard **G6** (substage 3.4.5) makes this a build failure rather than a periodic check, and 3.4.6
requires it demonstrated failing on a deliberate addition. Re-verified at 7.10.3 and 9.7.2.

## 6. Generated code is not committed

Decision recorded in substage 3.3.4; rules in `.gitignore`.

`*.g.dart`, `*.freezed.dart` and `*.mocks.dart` are **gitignored**. Generated files in a diff obscure
the real change, and regenerating in CI verifies that generation still *works* on every push —
strictly stronger than trusting a committed artefact that may no longer match its source.

The cost is that `flutter pub run build_runner build` must run before analyze or test on a fresh
clone. The CI pipeline does this, and `docs/DEVELOPMENT.md` documents it locally.

## 7. `minSdk` re-checked with plugins present

Substage 3.3.2's whole purpose, and the pitfall it names: *"Discovering in Stage 7 that the Google
client raised minSdk above the level already advertised."*

**Result: `minSdk` remains 24.** No plugin raised the floor — including `google_sign_in`, the
likeliest candidate. Read from the merged manifest of a build with **all** plugins present, not
predicted.

The build additionally pulled Android SDK Platform 35 automatically, because a plugin compiles
against it. `compileSdk` and `targetSdk` remain pinned at 36.
