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

## Post-release / nice-to-have (tracked, not scheduled)

Carried over from the archived roadmap's Phase 3.

- Real WidgetKit extension (current `Zeez/Widgets/` is in-app cards only; naming misleads).
- Apply for the critical-alerts entitlement (defensible for an alarm app); until granted,
  keep the graceful `checkCriticalAlertsEnabled` degradation.
- Heart-rate downsampling on HealthKit import (a full night = thousands of `HeartRateData`
  managed objects; store growth).
- Duration-weighted stage-distribution scoring in
  `Zeez/Sleep/Quality/SleepQualityCalculator.swift` (currently counts stages, which skews
  with variable-length HealthKit stages); derive `confidenceScore` instead of the
  hardcoded `85.0` in `SleepAnalyzer`.
- Import UX: completion signal for the fire-and-forget HR/respiratory sub-imports; partial
  failure reporting.
- Alarm health indicator in `AlarmSettingsView` ("N notifications scheduled; next fires
  at…").
- `NavigationView` → `NavigationStack` migration (start with `MainView` — remove the
  NavigationView wrapping the TabView; give each tab its own NavigationStack).
- Singleton graph → protocol injection, incrementally, following the
  `SleepAnalyzer.analyzeSleepSession(objectID:container:)` pattern.
- First-run empty-dashboard state that routes to HealthKit import.
- Environmental noise units fiction (flagged during 2.9, pre-existing): `EnvironmentalMonitor`
  stores a normalized 0–100 of `averagePower`, but the UI labels it "dB" and mock data
  generates real 20–55 dB values — pick one unit story and align monitor, UI, and mocks.

## Sleep product roadmap (dormant)

`Archive/SLEEP_REFACTORING_PLAN.md` (2026-05-26) still holds unexecuted Phases 3–6
(source-aware metrics engine, watch payload conformance, quality-score gating, owned-sensor
staging research). If that work is ever revived, its claims rules remain binding:
`SLEEP_METRICS_CLAIMS_AND_VALIDATION.md` at the repo root is the **live** claims/labeling
contract for all sleep metrics — it is deliberately not archived.
