# ADR-002 — Cloud sync storage target

## Status

Accepted — 2026-07-20. Frozen; changing it requires a new ADR and would alter the product's central
privacy claim.

## Context

FR-09 requires sync "to the user's own Google account, **not a third-party server**, so data is not
locked to one device". INV-05 states that no financial data may be "transmitted to, stored on, or
processed by infrastructure controlled by the developer or any third party". NFR-01 makes this
measurable: zero outbound requests to any host that is not the user's storage provider.

These are not performance requirements that admit a trade-off. They are the product's central
promise, and a storage choice that violates them makes the app something other than what it claims
to be.

The original brief offered Firestore as an alternative. The manifest's own analysis note already
flags the problem; this ADR settles it on the record.

## The question that decides it

**Who controls the storage, and who is capable of reading the data?**

Not "who intends to read it", or "who is authorised to read it" — who *can*. A promise enforced by
policy can be broken by a policy change, a subpoena, a breach, or a future maintainer. A promise
enforced by architecture cannot.

### Option A — Cloud Firestore

Firestore documents live inside a **Firebase project owned by the developer**. That is the whole
model: the developer provisions the project, holds its credentials, sets its security rules, and
sees its console.

Consequences that follow directly, regardless of good intentions:

- The developer is the **data controller** for every user's financial records, in the regulatory
  sense. Not a metaphor — it is the legal position.
- The developer **can** read any user's data by opening the Firebase console. Security rules
  restrict client access; they do not restrict the project owner.
- The developer inherits breach liability, data-subject request obligations, retention duties, and
  the obligation to answer lawful demands for user data.
- A user cannot verify the promise. They must take the developer's word for it.

This **contradicts FR-09 as written** ("not a third-party server") and **violates INV-05**
("infrastructure controlled by the developer"). Calling a developer-owned Firebase project "the
user's Google account" because Firebase is a Google product is precisely the anti-pattern the Stage 2
plan names: *"Choosing Firestore for convenience and then describing it as the user's Google account."*

Firestore is genuinely better on the engineering merits — server-side queries, indexes, real-time
push, offline persistence, conflict handling. **None of that is relevant**, because it fails the
requirement the product exists to satisfy.

### Option B — Google Drive `appDataFolder` (chosen)

`appDataFolder` is a hidden, per-application folder inside **the user's own Google Drive**. Its
properties:

- The storage is the user's, on the user's quota, under the user's account.
- The developer has **no project, no console, no credentials and no path** by which to read it. There
  is nothing to log into. The absence of access is structural, not policy.
- The user can revoke access at any time from their Google account page, and can delete the app's
  data from Drive settings, without involving the app or the developer.
- Data is not locked to one device: any device signing into the same account reaches the same folder,
  which satisfies FR-09's stated purpose.

## Decision

**Google Drive `appDataFolder`, using the narrowest app-data scope.**

**No developer-operated backend, proxy, relay or metrics endpoint exists at any version** — this is
non-goal NG-08, and it is permanent rather than a v1 simplification.

### The control question, answered explicitly

> **Does the chosen option put user financial data on developer-controlled infrastructure?**
>
> **No.** Financial data exists in exactly two places: the user's device, and a hidden folder inside
> the user's own Google Drive. The developer operates no server, holds no credentials to user
> storage, and has no technical means of reading, enumerating or even counting user data. The
> developer cannot tell whether the app is being used.

Substage 7.10 proves this with a traffic capture; substage 9.7 repeats it on a release build.

## The honest costs

Accepted deliberately, each with its mitigation.

| Cost | Reality | Mitigation |
|---|---|---|
| **Consumes the user's Drive quota** | The app's data counts against the user's 15 GB free allowance | Quantified in PRD §7.4: single-digit megabytes at the Heavy five-year profile. Negligible, but compaction (§5.6 of ARCHITECTURE) bounds chunk growth regardless |
| **No server-side query, index, merge or push** | The client does **all** merging (IMP-15) — a direct consequence of NG-08, since there is nowhere else for merging to happen | The merge engine is designed for it (Stage 7), tested against an in-memory fake, and verified by property-based convergence tests over randomised interleavings |
| **No real-time push** | Devices converge on a sync cycle, not instantly | Sync is background reconciliation only (INV-06). The app never waits for it, so latency is not user-visible |
| **The user can wipe the remote data** | From Drive settings, without the app knowing | Handled as a first-class case (US-031): an empty remote is treated as *fresh*, never as deletion. Local data is never deleted in response |
| **The app-data OAuth scope is treated as sensitive** | Google verification is typically required before public release, and takes calendar time the project does not control (R-04, IMP-14) | Sync is in scope but **not release-blocking** (PRD §3.2), so verification cannot veto the release date. Verification work starts early in Stage 10 |
| **No offline persistence library to lean on** | Firestore would have provided it | The app is offline-first by its own design (NFR-02); it needs local persistence whether or not sync exists |

The scope classification and verification requirements are checked against current official
documentation at substage 7.1.2 rather than assumed here, per the manifest's knowledge-freshness
rule.

## Alternatives considered

**Cloud Firestore** — analysed above. Rejected on the control question. Better engineering
ergonomics, wrong data-controller position.

**A developer-operated server of any kind** — not evaluated. Excluded by INV-05 and NG-08 before
evaluation begins. Recorded so the absence is visibly deliberate.

**Google Drive user-visible files** (rather than `appDataFolder`) — rejected. The user would see
opaque app files cluttering their Drive, could move or rename them by accident, and the scope
required would grant the app access to their *entire* Drive rather than only its own folder. That is
strictly worse for privacy despite feeling more transparent.

**End-to-end encryption of the payload with a user passphrase** — deferred, not rejected (OQ-08,
deferral D-04). It would protect the data if the user's Google account were compromised, at the cost
of an unrecoverable failure mode if the passphrase is forgotten. **The accommodation is present from
v1.0**: the remote manifest carries an encryption-scheme field, written as `"none"`, so a later
version can adopt encryption without a rollout hazard and without a client being unable to
distinguish an unencrypted payload from a corrupt one.

## Consequences

### Positive

- The privacy claim is enforced by architecture rather than policy, and is verifiable by anyone who
  captures the app's traffic.
- No backend to operate, secure, pay for, or migrate; no breach surface belonging to the developer.
- No data-subject request obligations, because the developer holds no data.
- The user can revoke or delete unilaterally, without asking.

### Negative

- Every merge conflict must be resolved on-device with no authoritative referee, which is why the
  merge rules are specified per record class (ARCHITECTURE §6) rather than as one blanket policy.
- A user with a full Drive cannot sync. `QuotaExceeded` is a first-class error with a user-facing
  message (substage 7.3.5), not an unhandled case.
- Release timing depends partly on Google's verification queue — mitigated by making sync
  non-blocking for release.
- **No post-release telemetry of any kind.** The developer cannot observe failures in the field. This
  is the deliberate trade recorded in PRD §6.10 and planned around at substage 10.8.8.

### Neutral

- The `RemoteStore` interface (substage 7.2) contains no provider-specific type, and only
  `data/sync/adapters/drive/` may import the provider SDK (guard added at 7.2.5). If this ADR were
  ever revisited, the blast radius is one directory — though any replacement would have to satisfy
  the same control question, which excludes most alternatives by construction.

## Date

2026-07-20
