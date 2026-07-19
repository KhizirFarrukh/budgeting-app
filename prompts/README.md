# PookieBudget - staged agent plan

One JSON file per stage. Each stage file contains its substages nested inside it, so a session
needs exactly **two files**: this manifest and one stage file.

## How to use it

1. Load `00_project_manifest.json` - shared context, requirement IDs, invariants, glossary, open questions
2. Load **one** stage file
3. Work its `substages` array **in order**, one substage per session

Tick substages off as you go; no approval is needed between them. The **final substage of each
stage** assembles the stage report and stops for user approval before the next stage file is opened.

## Stages

| # | Stage | Substages | File | Size |
|---|-------|-----------|------|------|
| 1 | Requirements Gathering & Documentation | 8 | `stage_01_requirements_and_prd.json` | 42KB |
| 2 | System Design & Architecture | 13 | `stage_02_system_design_and_architecture.json` | 73KB |
| 3 | Project Scaffolding | 9 | `stage_03_project_scaffolding.json` | 40KB |
| 4 | Core Data Layer Implementation | 11 | `stage_04_core_data_layer.json` | 52KB |
| 5 | Core Business Logic - Auto-Distribution Engine | 10 | `stage_05_distribution_engine.json` | 48KB |
| 6 | UI Implementation - Core Flows | 12 | `stage_06_ui_core_flows.json` | 56KB |
| 7 | Cloud Sync Implementation | 11 | `stage_07_cloud_sync.json` | 52KB |
| 8 | Reports & Insights | 8 | `stage_08_reports_and_insights.json` | 36KB |
| 9 | Testing & QA Pass | 8 | `stage_09_testing_and_qa.json` | 37KB |
| 10 | Polish & Release Prep | 8 | `stage_10_polish_and_release.json` | 39KB |

Total: 98 substages, 703 work steps, 465 acceptance criteria.

## Substage index

**Stage 1 - Requirements Gathering & Documentation** (`stage_01_requirements_and_prd.json`)

- 1.1 Intake and source reconciliation - Inventory every stated requirement from the source brief so nothing can be quietly dropped later.
- 1.2 Personas and end-to-end journeys - Describe who uses the app and the exact step-by-step paths they take, including the paths where things go wrong.
- 1.3 User stories and acceptance criteria - Convert every inventoried requirement into a user story with observable Given/When/Then criteria.
- 1.4 The money model in plain language - Define what a balance, a ceiling, a redirect and a category type mean in words a non-developer can act on.
- 1.5 Non-functional requirements with measurable targets - Give every quality attribute a number or a binary observable condition, plus the stage that verifies it.
- 1.6 Scope boundaries and the version 1 cut line - Name what is in, what is out, what is deferred, and which deferrals still need schema accommodation now.
- 1.7 Open questions and ambiguity register - Collect every ambiguity into one register, each with options, consequences and a recommended default.
- 1.8 Traceability matrix and PRD assembly - Assemble the finished PRD, build the traceability matrix, and prepare the stage gate.

**Stage 2 - System Design & Architecture** (`stage_02_system_design_and_architecture.json`)

- 2.1 State management decision - Choose the Flutter state management approach against explicit criteria and record ADR-001.
- 2.2 Layering, dependency rule and directory structure - Define four layers, the dependency rule, the enforcement mechanism and the exact directory tree Stage 3 will create.
- 2.3 Data model: entities, tables and columns - Define every table, column, type and enumeration needed by the approved user stories.
- 2.4 Data model: constraints, indexes, balances and migrations - Specify integrity constraints, the indexes the real queries need, the balance derivation policy and the migration strategy.
- 2.5 Allocation algorithm: contracts and phase A base split - Define the engine's input and output contracts and specify the integer-only percentage split with largest-remainder rounding.
- 2.6 Allocation algorithm: phase B ceilings, redirects and termination - Specify headroom by category type, the worklist that resolves capacity, redirect chaining, cycle defence and the terminal sink.
- 2.7 Allocation algorithm: overrides, reversals and the error taxonomy - Specify manual override semantics, reversal generation, and every typed failure the engine can return.
- 2.8 Allocation algorithm: pseudocode, worked examples and the test vector table - Write the complete language-agnostic pseudocode and the vector table Stage 5 implements verbatim.
- 2.9 Cloud sync data model and merge strategy - Choose the storage target against the privacy constraint, design the remote format, and define merge semantics per record class.
- 2.10 Validation and configuration integrity rules - Enumerate every configuration validation, where it is enforced, and what happens when it fails.
- 2.11 Navigation, screen inventory and per-screen states - Define every screen, the navigation graph, Android back behaviour, and the empty, loading and error state of each screen.
- 2.12 Technology decision set - Choose the database and the remaining libraries with criteria, runner-ups and exit plans, recorded as ADRs.
- 2.13 Design review, assembly and gate preparation - Read the whole design as one document, check it against the PRD and the invariants, and prepare the gate.

**Stage 3 - Project Scaffolding** (`stage_03_project_scaffolding.json`)

- 3.1 Project initialisation and Android configuration - Create the Flutter project with final identifiers and correct SDK levels, and prove it builds and launches.
- 3.2 Directory structure and layer boundaries - Create the exact tree from ARCHITECTURE.md and make each layer's rules visible in the filesystem.
- 3.3 Dependencies and the code generation toolchain - Add every dependency chosen in Stage 2, resolve current versions, and prove code generation runs end to end.
- 3.4 Linting, formatting and invariant guard checks - Make the manifest invariants mechanically enforceable, and prove each guard fails on a deliberate violation.
- 3.5 Continuous integration pipeline - Automate the full check sequence so every later stage is verified on every push.
- 3.6 Theme, design tokens and the money formatter - Define light and dark themes, spacing and typography tokens, the business scope treatment, and a correct currency formatter.
- 3.7 Router and stub screens - Implement the navigation graph from NAVIGATION.md with one placeholder screen per route.
- 3.8 Test harness, fakes and fixtures - Build the testing foundations Stages 4 and 5 depend on, and prove they work.
- 3.9 Scaffold verification and gate preparation - Prove the scaffold matches the design, capture the evidence, and prepare the stage gate.

**Stage 4 - Core Data Layer Implementation** (`stage_04_core_data_layer.json`)

- 4.1 The Money type and core value types - Implement a money value type that makes floating point arithmetic impossible by construction.
- 4.2 Domain entities, enums and invalid-state prevention - Implement every entity as an immutable type that cannot be constructed in an invalid state.
- 4.3 Database schema definition and code generation - Transcribe SCHEMA.md into table definitions exactly, and prove the transcription is faithful.
- 4.4 Repository interfaces and CRUD implementation - Implement repository interfaces in the domain and their database-backed implementations in the data layer.
- 4.5 Append-only ledger and transactional writes - Make INV-03 impossible to violate through the repository API, and make multi-row writes atomic.
- 4.6 Balance derivation and cache verification - Implement balances as derived values with a recompute-and-compare verifier.
- 4.7 Seed data, suggested categories and the sink - Ship the suggested categories as editable proposals, create the mandatory sink, and make seeding idempotent and non-destructive.
- 4.8 Configuration validators and cycle detection - Implement every validation rule from the design and wire it into the write path so invalid state cannot be persisted.
- 4.9 Migrations, export and backup - Build the migration framework and its fixture testing, plus a full export and import that round-trips exactly.
- 4.10 Data layer test suite and performance smoke test - Complete the test suite to the coverage target and prove the layer performs at realistic volume.
- 4.11 Data layer documentation and gate preparation - Document the implemented layer, prove it matches the design, and prepare the stage gate.

**Stage 5 - Core Business Logic - Auto-Distribution Engine** (`stage_05_distribution_engine.json`)

- 5.1 Engine contracts and the purity harness - Implement the request and result types, the failure taxonomy, and a static check proving the engine is pure.
- 5.2 Phase A: base split and largest-remainder rounding - Implement the integer-only percentage split with deterministic largest-remainder rounding.
- 5.3 Headroom computation by category type - Implement how much each category can accept, including the within-run accepted tracker.
- 5.4 Phase B: worklist, redirects and termination - Implement capacity resolution with chained redirects, cycle defence, hop limit and the terminal sink.
- 5.5 Fixed-recurring period logic - Implement period boundaries and per-period capping for fixed-recurring categories.
- 5.6 Manual override handling - Implement per-event overrides with proportional redistribution and exact-total enforcement.
- 5.7 Reversal generation - Implement compensating entries that exactly undo a previous income event without touching history.
- 5.8 Golden test vectors - Implement all fifteen vectors from the design as JSON fixtures with an automatic loader.
- 5.9 Property-based tests - Verify the seven required properties over thousands of randomly generated configurations.
- 5.10 Benchmarks, engine notes and gate preparation - Measure engine performance, document the implementation, and prepare the stage gate.

**Stage 6 - UI Implementation - Core Flows** (`stage_06_ui_core_flows.json`)

- 6.1 App shell, state wiring and scope switching - Connect the presentation layer to use cases and repositories, and implement the personal and business scope switch.
- 6.2 Onboarding part one: currency, scope and top-level split - Build the first three onboarding steps with an exact-100-percent constraint that cannot be violated.
- 6.3 Onboarding part two: categories, percentages, ceilings and accounts - Build the remaining onboarding steps so a first-time user leaves with a valid, personal configuration.
- 6.4 Add income form and live allocation preview - Build the income entry form with a live, explained allocation preview computed by the engine.
- 6.5 Manual override, confirmation and undo - Let the user adjust a single income event, confirm it atomically, and undo it cleanly.
- 6.6 Category management - Give the user full control over categories, types, percentages, ceilings and redirect targets, without ever permitting an invalid configuration.
- 6.7 Account management - Let the user record which real-world account holds which categories, without implying bank connectivity.
- 6.8 Dashboard - Build the screen the user opens most, with every figure derived from the ledger and updating reactively.
- 6.9 Spending log and transaction history - Let money leave categories, and make every past movement inspectable and correctable.
- 6.10 Business scope separation - Make business money impossible to confuse with household money, everywhere in the app.
- 6.11 Cross-cutting UI quality: states, inputs and accessibility - Give every screen its three states, a safe money input, and accessibility built in rather than retrofitted.
- 6.12 Widget tests, flow tests and offline verification - Test every screen and every core journey, and prove the whole app works with no network.

**Stage 7 - Cloud Sync Implementation** (`stage_07_cloud_sync.json`)

- 7.1 Google Sign-In and account lifecycle - Implement optional authentication, including account switching and consent revocation, without making it a prerequisite for anything.
- 7.2 RemoteStore interface and the in-memory fake - Define the storage abstraction and build the fake that every merge test runs against.
- 7.3 Cloud adapter and remote file layout - Implement the real adapter for the chosen provider and the remote file structure from the design.
- 7.4 Hybrid logical clock - Implement causal ordering that survives device clock skew.
- 7.5 Merge engine: union, last-write-wins and tombstones - Implement per-record-class merge semantics so no device's offline work is ever discarded.
- 7.6 Post-merge validation and deterministic repair - Guarantee that a merged state is always valid, and that any repair is deterministic and visible.
- 7.7 Outbox and the sync worker - Queue every local change durably and drain it in the background, never blocking the user.
- 7.8 Compaction and new-device bootstrap - Keep the remote store bounded, and get a fresh device to converged state safely.
- 7.9 Sync state machine and its user-visible surface - Implement the sync states and show them honestly, without ever blocking the app.
- 7.10 Privacy verification - Prove, with evidence, that no financial data reaches anywhere except the user's own Google account.
- 7.11 Sync test suite, documentation and gate preparation - Prove convergence across adversarial scenarios, document the design as built, and prepare the gate.

**Stage 8 - Reports & Insights** (`stage_08_reports_and_insights.json`)

- 8.1 Aggregation query layer and period boundaries - Build ledger-derived aggregation with precisely defined period boundaries and the indexes to make it fast.
- 8.2 Monthly and yearly summary reports - Build the periodic review the user actually reads, including redirect activity and rule changes.
- 8.3 Ceiling progress visualisation - Show goal progress accurately and accessibly, including the history of reaching and passing a ceiling.
- 8.4 Trend and ratio charts with accessible alternatives - Show how the spending, savings and business balance has actually shifted over time, based on real allocations.
- 8.5 CSV export format and implementation - Produce an unambiguous, correctly escaped CSV that reconciles exactly with the in-app figures.
- 8.6 Full JSON backup and restore surface - Expose the Stage 4 backup as a user-facing action and make restore safe.
- 8.7 Report test suite and reconciliation - Prove that dashboard, reports and export all agree, across every awkward scenario.
- 8.8 Reports documentation and gate preparation - Document the export format and reconciliation evidence, and prepare the stage gate.

**Stage 9 - Testing & QA Pass** (`stage_09_testing_and_qa.json`)

- 9.1 Widget and golden test coverage completion - Close every gap in screen-level testing and lock the money-critical screens with golden images.
- 9.2 End-to-end journey tests - Automate the full user journeys across layers, asserting on data as well as on screens.
- 9.3 Adversarial and edge case manual testing - Execute a written checklist of the failure modes that are hard to automate and certain to happen.
- 9.4 Money correctness audit - Independently verify that no money has been lost, invented or misplaced anywhere in the system.
- 9.5 Accessibility pass - Verify the app is usable without sight, with limited motor control, and at maximum text size.
- 9.6 Performance and resource testing - Measure every NFR-06 target on representative hardware at realistic data volume.
- 9.7 Privacy and security verification on the release build - Re-verify the privacy promise on a release-configuration build, not a development build.
- 9.8 Defect triage and the test report - Produce an honest record of what was found, what was fixed, and what remains.

**Stage 10 - Polish & Release Prep** (`stage_10_polish_and_release.json`)

- 10.1 Branding and visual identity - Produce the app icon, splash screen and finalised theming that make a finance app feel safe to use.
- 10.2 State polish and debug affordance removal - Bring every empty, error and loading state to a finished standard, and remove everything that should not ship.
- 10.3 Privacy policy drafting and publication - Turn the verified privacy behaviour into a published, accurate, plain-language policy.
- 10.4 Store compliance, data safety and OAuth verification - Prepare every artefact the store and the OAuth consent process require, matching actual behaviour.
- 10.5 Signing and build configuration - Configure release signing safely and produce the signed artefacts.
- 10.6 Code shrinking and release-build smoke test - Enable shrinking safely and prove the release build behaves identically to the debug build.
- 10.7 Documentation for future maintenance - Write the documents that let someone extend this app in six months without archaeology.
- 10.8 Release readiness review - Run the final check against the exact artefact that will be published, and decide honestly whether to ship.

## ID namespaces (defined in the manifest)

- `FR-01..FR-15` - feature requirements
- `NFR-01..NFR-08` - non-functional requirements with measurable targets
- `INV-01..INV-12` - invariants no stage may break (integer money, append-only ledger, derived balances, terminating redirects)
- `OQ-01..OQ-10` - open questions, each with a recommended default
- `R-01..R-08` - risk register
- `A-xx` - assumptions the agent records as it goes

## Substage shape

`id`, `goal`, `why_it_matters`, `entry_criteria`, `inputs`, `work` (numbered steps, each with
sub-details), `acceptance_criteria`, `outputs`, `must_not`, `common_pitfalls`, `traceability`,
`definition_of_done`, `checkpoint` (including escalation triggers).
