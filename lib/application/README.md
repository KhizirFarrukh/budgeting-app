# `application` — orchestration

**May import:** `domain`, `data` (implementations, for wiring at the composition root only),
Riverpod.

## What belongs here

Use cases — complete onboarding, preview allocation, confirm income, reverse income, save category,
save account, log spending, run sync. Providers exposing repository streams and use-case results.
State notifiers for the active scope, onboarding progress, the in-flight income draft, and sync
status.

## The rule that defines this layer

**A use case orchestrates; it never computes.** It gathers balances, calls the engine, and writes
atomically. It contains no allocation arithmetic — the engine is the only thing that computes a
split, which is what makes the substage 6.4.6 assertion provable: the preview and the confirmed
write call the same function, so what is shown is exactly what is written.

## What must never appear here

| Forbidden | Why |
|---|---|
| Imports from `presentation/` | Dependencies point inward only |
| Allocation arithmetic | Belongs in `domain/allocation/` alone |
| A cached balance held in state | INV-04 — balances are derived. A cache lives in the data layer with a recompute-and-compare path, never here (ARCHITECTURE §3.2) |
| Any Riverpod persistence feature | Prohibited by ADR-001 at every stage; this app has its own persistence and sync |

## What is held in state, and what is not

| Held | Re-derived on demand |
|---|---|
| Active scope, onboarding progress | Every category balance |
| The in-flight income draft | Every account total |
| Filters, selected period, sort order | Every report figure |
| Sync status | Every ceiling progress value |

## Repository providers are private to this layer

Presentation reaches them only through use-case providers, so a widget cannot acquire a repository
even accidentally. The import guards cannot catch that — both are in permitted layers — so substage
6.1.1 adds an explicit check (ARCHITECTURE §2.3, §3.5).

Decision: **ADR-001**.
