# PookieBudget — architecture

| | |
|---|---|
| **Status** | In progress — Stage 2 |
| **Derived from** | `docs/PRD.md` (approved Stage 1), `00_project_manifest.json` |
| **Sections assembled** | 3 (substage 2.1) |
| **Sections pending** | 1, 2, 4, 8, 10 (2.2); 5, 6 (2.9); 7, 9 (2.12) |

Companion documents: `SCHEMA.md` (data design), `ALLOCATION_ALGORITHM.md` (the engine),
`NAVIGATION.md` (screens and flow), `decisions/ADR-*.md`.

**Vocabulary.** This document and every later design document use the glossary terms of PRD §9.
Product language (PRD §9.1's left column — "goal", "target", "room", "catch-all") is for the user
interface and must not appear here.

---

## 3. State management

Decided in substage 2.1. Full reasoning, alternatives and consequences: **ADR-001**.

### 3.1 The decision

**Riverpod (3.x line), with code generation for providers.**

The application layer is composed of providers exposing repository streams and use-case results.
Widgets read providers. No widget constructs a repository, opens the database, or calls the
allocation engine directly.

### 3.2 What is held in state, and what is not

| Held in the state layer | Never held — re-derived on demand |
|---|---|
| Active scope (personal / business) | Every category balance |
| Onboarding progress | Every account total |
| The in-flight income draft: amount, label, date, manual overrides | Every report figure |
| Transient UI state: filters, selected period, sort order | Every ceiling progress value |
| Sync status | Anything else derived from ledger entries |

INV-04 makes a balance a derived value. Caching one in a provider would create a second copy that no
recompute-and-compare path verifies. Where a cache is required for performance — and PRD §7.4 shows
it is, at the Heavy profile — it lives in the data layer with the verification path specified in
substage 2.4.5, never in the state layer.

### 3.3 Where use cases live and how they are invoked

Use cases live in the **application** layer. Each orchestrates a sequence — gather balances, call the
engine, write atomically — and returns a typed result the UI maps to a message. A use case contains
no allocation arithmetic; the engine is the only thing that computes a split.

Invocation path, with no step skippable:

```
Widget → (reads) Provider → (invokes) Use case → Repository interface  → Data layer
                                              ↘ Allocation engine (pure, domain)
```

Repository providers are declared private to the application layer. Presentation reaches them only
through use-case providers, so a widget cannot acquire a repository even accidentally.

### 3.4 How a background sync mutation reaches a visible screen

The case the decision turned on. From Stage 7, the sync worker writes to the database while a screen
is visible; INV-06 forbids blocking the UI and FR-13 requires the change to appear without a manual
refresh.

```mermaid
sequenceDiagram
    participant Sync as Sync worker (data)
    participant Repo as Repository (data)
    participant DB as Database
    participant SP as StreamProvider (application)
    participant UI as Dashboard (presentation)

    Note over Sync,UI: The sync layer holds no reference to the UI at all.
    Sync->>Repo: apply merged records
    Repo->>DB: write (transaction)
    DB-->>Repo: change notification on affected tables
    Repo-->>SP: query stream re-emits
    SP-->>UI: providers emit; watching widgets rebuild
```

**The database is the only coupling.** The sync worker does not know the presentation layer exists,
does not publish an event to it, and cannot block it. Any writer — user action, sync merge, restore
from backup, migration repair — propagates identically, because they all write through the same
repository API.

Verification obligations this creates:

| Stage | Obligation |
|---|---|
| S04.4.4 | A test that mutates through a second code path and asserts the stream emits |
| S06.1.3 | The same assertion at screen level: a non-UI mutation updates a visible screen |
| S06.8.5 | Every dashboard figure driven by a reactive query, including for future sync writes |

### 3.5 Enforcement

The layering guard (substage 3.4.4) checks imports, which catches a widget importing the data layer
but **not** a widget reading an application-layer provider it should not. That gap is closed
separately:

| Rule | Enforced by |
|---|---|
| `domain` imports no Flutter, no `dart:io`, no other layer | CI layering guard, S03.4.4 — demonstrated failing on a deliberate violation |
| No widget constructs a repository or touches the database | S06.1.1 check; repository providers private to the application layer |
| No allocation arithmetic outside the engine | S06.4.6 test asserting the preview equals engine output exactly |
| No Riverpod persistence feature is used at any stage | ADR-001 prohibition; the app has its own persistence and sync |

### 3.6 Constraints this places on later stages

1. The engine imports nothing from this layer. If ADR-001 were ever reversed, the domain layer, the
   data layer and their tests are unaffected — the blast radius is application plus presentation.
2. The allocation preview watches **one** provider carrying the whole engine result, not one per
   category, and is debounced (S06.4.2). NFR-06 P-07 budgets 100 ms from keystroke at 40 categories.
3. Flow and journey tests override only the outermost boundaries — clock, id generator, remote store
   — never repositories or use cases, so the graph under test resembles production.
