# `presentation` — Flutter only

**May import:** `application`, `domain` types **for display only**, Flutter.

## What belongs here

Screens and widgets, theme and design tokens, the business-scope visual treatment, the locale-aware
money formatter, and the router.

## What must never appear here

| Forbidden | Why |
|---|---|
| Imports from `data/` | No widget touches the database, a repository, sync or the network. Guard **G5** |
| Calling a domain validator or the engine directly | Reached through use cases, so the preview and the confirmed write cannot diverge |
| Any allocation arithmetic | Substage 6.4.6 asserts the preview performs none of its own |
| A colour, spacing or font literal outside `theme/` | Substage 3.6's acceptance criterion, re-checked at 10.1.3 |
| Hardcoded two decimal places | Currency exponent varies — 0 for JPY, 2 for USD/PKR, 3 for KWD |
| A hardcoded user-facing string inside widget logic | Substage 6.11.6 — strings live in one place, ready for localisation |

`domain` may be imported so a widget can hold a `Money` or a `Category` for rendering. That is the
only reason.

## Money has two representations

| Purpose | Where | Produces |
|---|---|---|
| **Serialisation** — CSV, JSON backup | `domain/money/money.dart`, a pure `toDecimalString()` | Exact decimal string from integer minor units. No locale, no separators, no symbol |
| **Display** | `formatting/money_formatter.dart` | Locale-aware, with grouping separators and the currency symbol |

The display formatter is **built on** the serialisation function and never re-derives decimal
placement. Neither path may involve a floating-point value at any point, including intermediates
(ARCHITECTURE §8.5).

## Every screen has three states

Empty, loading and error — all 22 screens, defined in `docs/NAVIGATION.md` §7. **A screen without
all three is not finished.** Substage 6.11.1 walks the inventory and ticks each; substage 9.1 tests
them.

Specification: `docs/NAVIGATION.md`.
