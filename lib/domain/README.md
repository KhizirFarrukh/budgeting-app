# `domain` — pure Dart

**Depends on nothing.** Dart core libraries only.

## What belongs here

Value types (`Money`, `Currency`, `BasisPoints`), entities, enumerations, the allocation engine,
configuration validators, repository **interfaces**, the `Result` type, and the `Clock` /
`IdGenerator` **interfaces**.

## What must never appear here

| Forbidden | Why |
|---|---|
| `package:flutter/*`, `dart:ui` | The engine must be unit-testable with no Flutter binding |
| `dart:io`, HTTP, the database package | No I/O at all (INV-08) |
| Imports from `data/`, `application/`, `presentation/` | Dependencies point inward only |
| `double`, `float`, `num` on the money path | INV-01 — integer minor units everywhere |
| `DateTime.now()` | Time arrives injected via `Clock`, or as a parameter |

Guards **G1**, **G2**, **G3** and **G4** enforce these mechanically (ARCHITECTURE §2.3), and each is
demonstrated failing on a deliberate violation in substage 3.4.6.

## `allocation/` is stricter still

Guard **G2** additionally forbids `async`, `await`, `Future`, `Stream` and `DateTime.now` anywhere
under `domain/allocation/`. The engine is a synchronous pure function whose entire world arrives in
its request object — it holds no repository and no clock, unlike the rest of this layer, which may
hold injected interfaces.

Specification: `docs/ALLOCATION_ALGORITHM.md`. Stage 5 transcribes it; it does not reinvent it.

## Dependency direction

```
domain  ←  data  ←  application  ←  presentation
```

Nothing here imports anything to its right.
