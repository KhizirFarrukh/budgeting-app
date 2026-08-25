# ADR-007 — Amendment: `balance_cache.entry_count`

## Status

Accepted — 2026-08-24. **Amends `SCHEMA.md` §3.12.**

- **Raised during:** Stage 4, at the start of substage 4.6
- **Amends:** `SCHEMA.md` §3.12 (the `balance_cache` table)
- **Supersedes nothing.** Completes the policy already approved in §7.1

## Context

`SCHEMA.md` describes the same table in two places, and the two disagree.

**§7.1 — the balance policy**, written at substage 2.4, specifies a two-tier verifier and states the
incremental update as:

> The update is incremental: `balance_minor += (direction == IN ? amount : -amount)`, plus
> **`entry_count += 1`** and `last_entry_id = <new id>`.

and defines the cheap tier as:

> One grouped `COUNT(*)` per category compared against the cached **`entry_count`** · Every cold
> start

**§3.12 — the table declaration**, written one substage earlier at 2.3, lists five columns:
`category_id`, `balance_minor`, `last_entry_id`, `computed_at_ms`, `is_stale`. **There is no
`entry_count`.**

Substage 4.3 transcribed §3.12 faithfully, so the table as built has no such column, and the
comparison table in `STAGE_4_SCHEMA_COMPARISON.md` correctly reports no divergence — it compared the
transcription against the declaration, which is what it exists to do. Neither document is wrong
about itself; they are wrong about each other, and only substage 4.6 has cause to read both.

The consequence is concrete: **the cheap tier as specified cannot be implemented.** Substage 4.6.4
requires the verifier, and 4.6's `common_pitfalls` names precisely the failure the cheap tier
exists to catch — *"a cached balance updated on write but never verified, which drifts after a sync
merge and is discovered by a user."*

## Decision

**Add `entry_count` to `balance_cache`** as a sixth column: `INTEGER`, not null, default 0.

| Column | Type | Null | Meaning |
|---|---|---|---|
| `category_id` | TEXT | no | → `categories.id`, primary key |
| `balance_minor` | INTEGER | no | Cached sum of the category's ledger entries |
| **`entry_count`** | **INTEGER** | **no** | **How many entries are folded into `balance_minor`** |
| `last_entry_id` | TEXT | yes | The most recent entry folded in |
| `computed_at_ms` | INTEGER | no | |
| `is_stale` | INTEGER | no | Set on any write to that category's entries |

`SCHEMA.md` §3.12 is amended to match, with a pointer to this ADR.

### Why the column rather than a weaker cheap tier

`last_entry_id` already exists, and a cheap tier could compare it against `MAX(id)` per category
instead — ledger ids are UUID v7, so the newest entry is also the lexicographically greatest. That
would need no schema change at all, and it was the first thing considered.

It is rejected because it is **weakest exactly where the risk is highest.** A `MAX(id)` comparison
detects an entry appended *after* the cached one. It cannot detect an entry inserted with an
*earlier* id — and that is not a hypothetical: a sync merge imports entries written on another
device at earlier instants, which is the dominant path by which this cache goes wrong. §7.1 says so
outright: *"The full tier covers the paths where an amount could be wrong, which is dominated by
merges."*

A cheap tier blind to merges would run on every cold start, pass, and give a false assurance
between the full recomputes. `COUNT(*)` catches an insertion anywhere in the range.

### Why this needs no migration and no schema version bump

`balance_cache` is **device-local, derived and disposable** (§3.12). It is excluded from sync,
excluded from the export payload, and every value in it is reproducible from `ledger_entries` alone
by definition — that is what makes it a cache rather than a source of truth (INV-04).

So `kSchemaVersion` stays at **1**. No build has shipped, and even if one had, the honest recovery
for this table is not a data-preserving migration but a recompute, which the verifier already
performs. This is the same reasoning that let `repair_log` be added at ADR-005 without a version
bump.

## Alternatives considered

**Drop the cheap tier; run only the full recompute.** Honest, and it needs no schema change. Rejected
because §7.1 chose two tiers on measured grounds: a full grouped `SUM` is 40–150 ms at the Heavy and
Stress profiles, and §7.1 explicitly rejected paying that on every emit. Running it on every cold
start instead is affordable but wasteful, and the cheap tier's single indexed count is most of the
value for a fraction of the cost.

**Compare `MAX(id)` against `last_entry_id`.** Discussed above — blind to merge-inserted entries.

**Leave the documents inconsistent and implement whichever is convenient.** This is what the
manifest's `sdlc_discipline` forbids: *"do not silently patch forward: raise it, amend the earlier
document, and note the amendment in the decision log."* A reader of §7.1 in Stage 7 would otherwise
implement the merge's post-recompute against a column that does not exist.

## Consequences

### Positive

- The cheap tier becomes implementable as designed, and catches the merge case it was written for.
- `entry_count` makes one more class of discrepancy nameable: a cache whose *total* happens to match
  while its *composition* does not — two errors that cancel. The balance comparison alone would
  report that as healthy.

### Negative

- A sixth column on a table that substage 4.3 has already shipped, and a second post-Stage-2 schema
  amendment after ADR-005. Cheap here only because the table is device-local; the same change to a
  synced table would touch the sync payload, the export format and the merge.
- `STAGE_4_SCHEMA_COMPARISON.md` must be regenerated at 4.11 so it compares against the amended
  §3.12 rather than the original.

### Neutral

- No effect on the sync payload, the export format, the merge, or any user-visible behaviour. The
  column is written and read entirely within one device.

## Date

2026-08-24
