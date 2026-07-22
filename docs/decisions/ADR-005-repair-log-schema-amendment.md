# ADR-005 — Amendment: the `repair_log` table

## Status

Accepted — 2026-07-21. **Amends `SCHEMA.md` after the Stage 2 approval gate.**

## Context

This ADR exists because of a rule and a mistake.

**The rule.** Stage 4's entry criteria require that *"SCHEMA.md is approved and unchanged since
Stage 2, **or amended with an ADR**."* SCHEMA.md was amended after the gate, so this record is
required before Stage 4 may begin. The manifest's `sdlc_discipline` says the same thing more
generally: *"do not silently patch forward: raise it, amend the earlier document, and note the
amendment in the decision log."* The amendment was raised and the document was amended, but it was
recorded only in the Stage 2 report and worklog — **not in the decision log**. This ADR closes that.

**The mistake.** Substage 2.13's consistency pass found that:

- SCHEMA §6.8 requires every post-merge repair to be *"written to a durable repair log and surfaced
  to the user in plain language"*;
- NAVIGATION's `Diagnostics` screen displays that log;
- **but no table held it.**

The Stage 2 report initially filed this as *"a Stage 4 obligation."* That triage was wrong. Stage 4
transcribes SCHEMA **exactly**, and substage 4.3.5 proves the transcription faithful with a
comparison table. A table absent from SCHEMA is a table Stage 4 does not build — so the gap would
have survived to Stage 7 substage 7.6.4, where the merge engine would have had nowhere to write its
repairs, mid-implementation.

## Decision

**Add `repair_log` to SCHEMA.md as a thirteenth table** (§3.13), device-local and append-only.

| Column | Type | Meaning |
|---|---|---|
| `id` | TEXT | UUID v7 — time-sortable, as this is an append-only log |
| `occurred_at_ms` | INTEGER | When the repair was applied |
| `merge_session_id` | TEXT | Groups every repair from one merge |
| `kind` | TEXT | `RepairKind` — one value per §6.8 repair |
| `table_name` | TEXT | Which table was repaired |
| `record_id` | TEXT | Which row. **Not a foreign key** |
| `detail_json` | TEXT | Structured context: ids and integer amounts |
| `acknowledged_at_ms` | INTEGER | Null means unread |

Wired through the table inventory (twelve → thirteen tables), the `RepairKind` enumeration, the ER
diagram, the index table (IX-12) and query table (Q15), the §6.8 repair catalogue, and §8.1's
does-not-travel list.

### Why device-local rather than synced

**This follows from a property the design already required.** §6.8 mandates that every repair be
**deterministic** — two devices performing the same merge produce identical repairs, because a
non-deterministic repair makes devices diverge permanently, which is worse than the original
invalidity.

Given determinism, each device generates the same log entries independently. Syncing the log would
duplicate every entry. The determinism requirement is therefore what makes local logging *correct*,
not a compromise.

### Why `record_id` is not a foreign key

The record a repair concerns has frequently been **deleted** — that is often precisely why the
repair was needed (a redirect target deleted on another device). A foreign key would make the log
unwritable in exactly the case it exists to record.

### Why `detail_json` holds ids rather than names

The same reasoning as the allocation engine's diagnostics (ALLOCATION_ALGORITHM §2.3): the data
layer has no locale and should not build user-facing sentences. The `Diagnostics` screen resolves
ids to current names at display time, which also means a later rename is reflected in old entries
rather than preserving a stale name.

## Alternatives considered

**Leave it to Stage 4 to notice.** The original (wrong) call. Rejected once the transcription rule
was reconsidered: Stage 4 builds what SCHEMA says and proves it matches, so a missing table stays
missing and surfaces three stages later.

**Store repairs in an existing table** — say, as `ledger_entries` rows with a new source type.
Rejected outright: `ledger_entries` is the **money** table, protected by check constraint C-15 and
the append-only guarantee. A repair is a configuration event, not a movement of money. Putting
non-money rows in the ledger would corrupt every balance derivation, which sums that table.

**Keep the log in memory and surface it only until the app closes.** Rejected: §6.8 requires the
log to be *durable*, and a user who was not looking at the app when a merge ran is exactly the user
who needs to know their configuration changed.

**Sync the log.** Rejected — see determinism above. It would duplicate every entry.

## Consequences

### Positive

- SCHEMA is now self-consistent: every requirement it states has a place to live.
- Stage 7 substage 7.6.4 has a table to write to, and 7.9.5 has one to read from.
- The `Diagnostics` screen (NAVIGATION §1.4) has its data source, which was the other half of the
  gap.

### Negative

- **SCHEMA.md changed after its approval gate.** The user approved a twelve-table design and Stage 4
  now implements thirteen. The change is additive and touches no existing table, but it is a change
  after approval and is recorded here as one.
- Stage 4 has one more table to build than the gate implied — noted in the Stage 3 report §10 as an
  obligation carried forward.

### Neutral

- Retention is bounded: entries older than 365 days **and acknowledged** may be pruned.
  Unacknowledged entries are never pruned, because a repair the user has not seen is exactly the one
  worth keeping.

## Date

2026-07-21 (amendment made) · recorded as an ADR 2026-07-22, at the Stage 4 entry check
