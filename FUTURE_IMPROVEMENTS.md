# Future improvements

Live follow-up tracker, created 2026-07-07 when `IMPROVEMENT_ROADMAP.md` was archived
(Phases 0–2 complete; see `Archive/IMPROVEMENT_ROADMAP.md` for the full audit, decisions,
and progress log).

## Open verifications needing a device / Daniel / App Store Connect

These are the only remaining open items from the 2026-07-05 audit's Phases 0–2; all code
work is complete and verified in-simulator.

- **Alarm end-to-end on a physical device (1.1):** set an alarm, force-quit the app, lock
  the phone → follow-ups fire at cadence; Stop re-arms the next chain. (Also covers the
  delegate-callback threading paths noted in the roadmap's 1.6/2.8 row.)
- **Phone↔watch message round-trip (1.5)** (no paired simulators were scriptable in the
  dev environment).
- **Notification-budget banner visual check (1.4)** with ~5 smart-wake alarms creating
  real pending-notification pressure.
- **StoreKit on device (2.1):** sandbox purchase + restore; airplane-mode launch keeps
  premium; product IDs confirmed/created in App Store Connect **exactly** as
  `com.zeez.subscription.{premium,premiumplus}.{monthly,annual}`.
- **Release checks (2.3):** Organizer archive validation (needs signing/Xcode UI); manual
  walkthrough of the delete-all-data flow; publish the real privacy-policy URL
  (placeholder `https://dcs617.github.io/zeez-privacy/` in `AppConstants.Legal`).

## Removed capabilities

Features deleted during the second audit are registered in **`PARKED_CAPABILITIES.md`** at the
repo root, with the reason, the recovery command, and what the claims contract requires before
each could ship. Deletion is not abandonment; that file is where the intent lives.

## Post-release / nice-to-have (tracked, not scheduled)

Carried over from the archived roadmap's Phase 3.

**Completed by the second audit (2026-07-09), kept here for provenance:**

- ~~Heart-rate downsampling on HealthKit import.~~ Done — second audit **B9**
  (`DataImport/HeartRateDownsampler.swift`, 60-second buckets).
- ~~Duration-weighted stage-distribution scoring; derive `confidenceScore`.~~ Done — **B8**.
  See `ZEEZ_SCORE_SPECIFICATION.md`, now a live contract.
- ~~Import UX: completion signal and partial-failure reporting.~~ Done — **B10**
  (`HealthKitImportResult` with a per-type `RelatedDataOutcome`).
- ~~First-run empty-dashboard state that routes to HealthKit import.~~ Done — **B11**
  (`Views/Dashboard/DashboardEmptyStateCard.swift`).
- ~~Environmental noise units fiction.~~ Done — **B5**. Noise is a relative index 0–100
  (`Environment/NoiseIndex.swift`), explicitly not dB SPL.

**Still open:**

- Real WidgetKit extension. The in-app `Zeez/Widgets/` tree was deleted in **B1** (it was
  unreachable and carried fabricated readings); a genuine extension target has not been built.
  Tracked as Phase **D3c**; see `PARKED_CAPABILITIES.md` §4. Its Core Data prerequisite is done:
  **D3a** moved the store into an App Group container, which had to happen before any user had data.
  ⚠️ D3a is inert until the **App Groups capability is toggled once in Xcode** — CLI `xcodebuild`
  strips profile-backed entitlements, so it cannot be done from the command line.
- Apply for the critical-alerts entitlement (defensible for an alarm app); until granted,
  keep the graceful `checkCriticalAlertsEnabled` degradation. Phase **D3b** — paperwork only, no code
  to write; file it early, Apple takes weeks.
- Alarm health indicator in `AlarmSettingsView` ("N notifications scheduled; next fires
  at…"). Second audit **C5**; explicitly deferred past Phase C.
- `NavigationView` → `NavigationStack` migration (start with `MainView` — remove the
  NavigationView wrapping the TabView; give each tab its own NavigationStack). Phase D1.
- Singleton graph → protocol injection, incrementally, following the
  `SleepAnalyzer.analyzeSleepSession(objectID:container:)` pattern. Phase D2.

## Sleep product roadmap (reconciled 2026-07-09, second-audit D3d)

`Archive/SLEEP_REFACTORING_PLAN.md` (2026-05-26) was described here as holding "unexecuted
Phases 3–6". That was wrong in both directions: phases A–C delivered most of it under different
names, and one phase diverged from the plan on purpose. Each phase in the archive now carries a
status line. In summary:

- **Phase 3 (import integrity)** — mostly delivered (B9, B10, C6). Outstanding: durable HealthKit
  sample identity and an overlapping-source merge policy.
- **Phase 4 (longitudinal review)** — mostly delivered (B4, B6, B7). Night and per-session input
  coverage landed 2026-10-20 (`SleepCoverage.swift`). Outstanding: an explicit date-range picker beyond
  the fixed Days/Week/Month ranges (Days and Week are currently the same 7-day window).
- **Phase 5 (experimental score)** — substantially delivered (B8, plus A1/A7). It **diverges** from
  the plan on purpose: the score is computed only from Zeez-inferred stages and never grades
  Apple-reported ones. The user-visible component breakdown landed 2026-10-20
  (`ZEEZ_SCORE_SPECIFICATION.md` §8), so the score now "explains itself" as the phase required.
- **Phase 6 (owned-sensor staging)** — not started, and it is a research project whose deliverable is
  a go/no-go report. Note that production **already** infers stages (`SleepStageAnalyzer`) and the
  score depends on them, with an "Experimental" label standing in for an evaluation that has never
  been run.

The residue is registered as spec stubs in `PARKED_CAPABILITIES.md` §8 and §9. Claims rules remain
binding on all of it: `SLEEP_METRICS_CLAIMS_AND_VALIDATION.md` and `ZEEZ_SCORE_SPECIFICATION.md` at
the repo root are **live** contracts and are deliberately not archived.
