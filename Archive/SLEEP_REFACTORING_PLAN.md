# Zeez Sleep Product Roadmap

Status: Canonical implementation plan
Updated: 2026-05-26
Replaces: the earlier "simple movement + heart rate tracker" deletion plan

## Canonical Supporting Documents

- `SLEEP_RELIABILITY_IMPLEMENTATION_HANDOFF.md` records the latest reliability
  audit and remaining implementation evidence.
- `SLEEP_METRICS_CLAIMS_AND_VALIDATION.md` defines the required evidence,
  naming, missing-data, disclosure, and validation contract for all sleep
  outputs.
- `SLEEP_PHASE_1_CLAIMS_CONFORMANCE_CLOSEOUT.md` records the completed Phase 1
  routed-surface inventory, claims-gate corrections, and verification.
- `SLEEP_PHASE_2_DERIVED_METRICS_CLOSEOUT.md` records the completed Phase 2
  derived-metrics contract, migrated active consumers, and verification.

## Decision

Do not restart the app from scratch.

Refactor the existing application around a narrower, explicit sleep-analysis
contract. The project already has working and recently tested foundations:

- SwiftUI application navigation, Core Data entities, settings, dashboard, alarm
  system, and watch companion compilation.
- Apple Health sleep-stage import with important integrity fixes.
- Shared stage normalization and unavailable-score presentation rules.
- Source-aware sleep goal shortfall logic and focused deterministic tests.

A rewrite would discard those foundations while leaving the hard problem
unchanged: deciding what the application can accurately claim from its inputs.
The appropriate work is to stabilize, consolidate, and then extend the existing
product in phases.

## Product Goal

Zeez should become a trustworthy personal sleep review tool that:

1. Imports sleep sessions and Apple-reported sleep stages from Apple Health.
2. Explains a night clearly: sleep timing, time asleep, wake periods, stage
   composition, available biometrics, and data provenance.
3. Tracks longitudinal patterns: selected-goal shortfall, schedule consistency,
   duration trends, and stage trends when reported stages exist.
4. Offers an explicitly experimental Zeez score only when its inputs and model
   are transparent.
5. Eventually supports validated Zeez-owned inference or recommendations, but
   does not present unvalidated outputs as medical or clinical conclusions.

## Product Boundaries

### Ship-Quality Metrics Without A Zeez User Study

These metrics can be derived deterministically from imported data and a user's
chosen goal. They require engineering tests and eventual real-device import
verification, not a broad user study:

| Metric | Required Inputs | Display Contract |
| --- | --- | --- |
| Recorded session interval | Session start/end | "Recorded session" |
| Time asleep | Apple-reported asleep intervals | "Time asleep, reported by Apple Health" |
| REM/Core/Deep/Unspecified duration | Apple-reported stages | Preserve Apple meaning; do not infer unspecified as another stage |
| Wake periods during session | Reported awake intervals | "Recorded wake periods" |
| Stage distribution | Reported asleep intervals only | Exclude `inBed` from sleep-stage percentages |
| Sleep efficiency | Valid asleep and in-bed/recorded opportunity interval | Show only when inputs exist; label as estimated/derived |
| Goal shortfall | Usable duration plus user-selected goal | "Below your selected sleep goal," not biological deficit |
| Bedtime/wake-time consistency | Sufficient session history | Descriptive timing pattern only |

### Experimental Until Validated

These can be developed, but their UI must identify them as experimental and
their model/version/input coverage must be traceable:

- A Zeez sleep score.
- Zeez-inferred sleep stages from movement or heart-rate data.
- Correlations between heart rate/HRV and sleep outcomes.
- Suggestions based on trends.

### Not A Product Claim Without Clinical Validation

- Diagnosing insomnia, apnea, or another sleep disorder.
- Estimating medical sleep debt, recovery time, readiness, or health risk.
- Claiming Zeez detects REM/deep sleep with Apple-equivalent accuracy.
- Claiming a score describes the user's health or need for treatment.

## Current Reality

### Valuable Baseline To Preserve

- `DataImport/HealthKitDataImporter.swift` imports source-reported HealthKit
  stages, avoids duplicate-start grouping crashes, and saves parent sessions
  before related-data attachment.
- `Sleep/SleepSession+Extensions.swift` holds shared score-availability,
  provenance, and goal-comparison policy.
- `Sleep/Stage/SleepStageTypes.swift` normalizes imported identifiers and
  excludes `inBed` from displayable sleep-stage distributions.
- `Sleep/SleepAnalysisTypes.swift` now has a source-aware recorded goal
  shortfall summary.
- Phone/watch score presentation has been guarded so unavailable imported
  scores are not shown as real assessments.
- Regression suites exist for import grouping, imported-data preservation,
  stage normalization, score presentation, idempotency, and goal shortfall.

### Code That Requires Consolidation Or Retirement

The following is not a reason to rewrite. It is the next refactoring backlog.

| Area | Evidence | Required Decision |
| --- | --- | --- |
| Old roadmap | `SLEEP_REFACTORING_PLAN.md` previously proposed guessed movement/HR stage detection as the target | Replaced by this evidence-based roadmap |
| Experimental analyzer claims | `Sleep/Stage/SleepStageAnalyzer.swift` labels heuristic classification "accurate" and fills stages using timing assumptions | Quarantine behind experimental provenance or retire until an owned-data input path exists |
| Experimental score model | `Sleep/Quality/SleepQualityCalculator.swift` uses fixed weighted thresholds and default scores when data is missing | Replace with transparent component model; never create quality from missing evidence |
| Stub analysis types | `Sleep/SleepAnalysisTypes.swift` retains mock-returning personalization/historical types | Remove once references are proven absent, or replace only when real metrics ship |
| Information calculations | `Sleep/SleepInfoAnalyzer.swift` equates interval duration with time asleep and includes a fixed consistency score | Route screens through one derived-metrics service |
| Duplicate detail presentations | `Views/EnhancedSleepDetailsView.swift` and `Sleep/SleepDetailView.swift` overlap and contain differing claims | Choose one production detail route; retire or reduce the other |
| Recommendation system | `Sleep/SleepRecommendationSystem.swift` creates personal advice from weak/unavailable evidence | Keep unreachable or remove until a conservative insights contract exists |
| Trends/widgets | Some compiled views are not known active and still contain legacy score/debt concepts | Do not expand; audit reachability before keeping or deleting |
| Broader app size | Approximately 49,771 Swift lines across app/tests/watch, including large Learn and dormant areas | Prune by reachability and product decision, not by mass deletion |

## Target Sleep Architecture

Do not create more parallel managers. Consolidate around the following layers.

### 1. Imported Evidence

Purpose: persist what a source reported without reinterpreting it.

Owned responsibilities:

- Apple Health authorization and import.
- Source/provenance metadata.
- Import identity and idempotency.
- Raw sleep-stage intervals and available HR/HRV/respiratory samples.

Likely owners:

- `DataImport/HealthKitDataImporter.swift`
- `Sleep/SleepSession+Extensions.swift`
- Core Data sleep entities

### 2. Derived Metrics

Purpose: one pure, testable interpretation of available evidence.

Create or consolidate into a single `DerivedSleepMetrics` model and calculator
covering:

- Recorded interval and reported time asleep.
- Stage duration/percentages.
- Wake periods and optionally WASO/sleep latency when supported by input.
- Efficiency availability and value.
- Goal shortfall.
- Timing consistency across periods.
- Coverage and provenance flags for each result.

Rules:

- Metrics return unavailable when required inputs are missing.
- Metrics operate on normalized stage data.
- HealthKit `inBed` is contextual, never an asleep stage.
- All active UI consumes this layer rather than reproducing calculations.

### 3. Presentation

Purpose: expose only supported meanings.

Initial production surfaces:

- Dashboard and calendar.
- Session detail.
- Stage detail/chart.
- Goal shortfall view.
- Watch latest-session summary.
- Settings/import state.

Policy:

- Each surface must show source and availability consistently.
- Remove duplicate screens or route them through the same view model.
- Dormant trends/widgets do not become scope merely because they compile.

### 4. Experimental Analysis

Purpose: allow future development without corrupting production trust.

Requirements before showing a Zeez score or inferred stage output:

- Explicit source: `Zeez Estimate`.
- Model/calculation version.
- Enumerated inputs used and missing-input behavior.
- Deterministic tests.
- Experimental user-facing language.
- A later dataset/device-validation record before stronger claims.

## Refactor Versus Rewrite Decision Gate

Current recommendation: refactor.

Reconsider a partial rewrite only if, after Phase 1, all of the following are
true:

1. Core Data schema cannot safely represent source, metric availability, and
   calculation provenance without destructive migration.
2. Active navigation cannot be reduced to a coherent set of production screens
   without replacing most UI code.
3. Focused tests cannot isolate imported evidence and derived metrics from
   dormant systems.

Current evidence does not meet these conditions. The app builds, focused sleep
tests pass, and the reliability work already establishes useful seams for
consolidation.

## Implementation Roadmap

For every phase, active UI text, accessibility labels and values, charts,
phone/watch payload presentation, and analytical outputs must conform to
`SLEEP_METRICS_CLAIMS_AND_VALIDATION.md`. A phase may not activate a metric or
interpretation whose required evidence or validation gate is unmet.

### Phase 0: Establish A Recoverable Baseline

Purpose: stop losing track of what is real while the tree is heavily changed.

Work:

- Preserve current in-progress changes; do not clean or broadly reorganize.
- Review the pending relocation/deletion set and separate intentional feature
  organization from abandoned experiments.
- Capture one reviewed checkpoint commit once the owner approves the current
  reliability and goal-shortfall changes.
- Keep this roadmap, the reliability handoff, and
  `SLEEP_METRICS_CLAIMS_AND_VALIDATION.md` as the canonical sleep documents;
  archive obsolete audit/phase notes later.

Exit criteria:

- A buildable/tested checkpoint exists in version history.
- No unexplained file deletion or duplicate moved file is mixed into subsequent
  product work.

### Phase 1: Production Surface And Reachability Audit

Status: Complete after claims-conformance fixes on 2026-05-26. See
`SLEEP_PHASE_1_CLAIMS_CONFORMANCE_CLOSEOUT.md`.

Purpose: identify precisely what users can reach and remove unsupported claims
before extending functionality.

Work:

- Trace navigation from `RootView` through Dashboard, Settings/import, session
  lists, details, goal shortfall, and watch payloads.
- Classify every sleep/trends/widget/recommendation/environment view as:
  active, debug-only, educational-only, dormant, or candidate for retirement.
- Audit text and accessibility labels for unsupported quality, recovery,
  medical, sleep-debt, environmental, and brain-activity claims.
- Resolve duplicate session-detail destinations by selecting one production
  path.
- Hide/remove links to analyses that do not compute real user data.

Exit criteria:

- A maintained reachability inventory.
- Every active sleep output is either sourced or explicitly estimated.
- No active stub/mock personal analysis.
- Focused tests and both app builds pass.

### Phase 2: One Derived Metrics Engine

Status: Complete on 2026-05-26. See
`SLEEP_PHASE_2_DERIVED_METRICS_CLOSEOUT.md`.

Purpose: replace scattered, inconsistent calculations with one trusted layer.

Work:

- Define `DerivedSleepMetrics`, `MetricAvailability`, and provenance types.
- Migrate stage totals, asleep duration, wake metrics, efficiency, and
  goal-shortfall calculations into pure/service logic.
- Add timing-consistency metrics over a period only when coverage is adequate.
- Remove fixed fallback metrics such as default efficiency or consistency
  values from user-facing paths.
- Make Dashboard, session detail, stages, calendar, weekly progress, and watch
  summaries consume the same contracts.

Exit criteria:

- A deterministic fixture produces identical results across every surface.
- Missing/partial/in-bed-only/imported-unspecified cases are tested.
- No active UI implements its own sleep math.

### Phase 3: Import Integrity And Data Coverage

Purpose: make Apple Health import sufficient for real longitudinal use.

Work:

- Introduce durable import identity using HealthKit sample identity or stable
  import metadata rather than start-time proximity alone.
- Define overlapping-source handling and session merge policy.
- Capture imported data coverage: source stages, asleep time, in-bed context,
  HR, HRV, respiratory rate, and missing inputs.
- Add safe re-import/update behavior and import diagnostics.
- Once developer access returns, complete real Apple Health import smoke tests.

Exit criteria:

- Reimport does not duplicate, corrupt, or silently discard sessions.
- Coverage is visible to users and downstream metric logic.
- Import has deterministic regression tests plus one documented device check.

### Phase 4: Longitudinal Sleep Review

Purpose: ship usefulness before inventing a proprietary score.

Work:

- Build a focused trends screen from derived metrics:
  duration, stage availability/composition, schedule consistency, and selected
  goal shortfall.
- Add date-range and coverage reporting, for example "5 of 7 nights recorded."
- Provide neutral observations such as timing variation and duration trend.
- Keep educational explanations separate from personal conclusions.
- Decide whether widgets add value only after the active app flow is coherent.

Exit criteria:

- Trends never average unavailable scores or fabricate missing nights.
- Users can answer: what happened last night, what pattern is present, and how
  complete is the evidence?

### Phase 5: Experimental Zeez Score

Purpose: develop quality scoring without overstating accuracy.

Work:

- Define what the score measures: for example consistency with the user's goal
  and recorded disruption, not health or recovery.
- Design a component score visible to the user rather than an opaque value.
- Use imported Apple stages for inputs first; do not start with Zeez-owned
  stage inference.
- Version each calculation and store input/provenance coverage.
- Validate logic using deterministic fixtures and retrospective public-data
  analysis where sensor inputs are comparable.
- Label throughout the app and watch payload as experimental.

Exit criteria:

- Score has a written specification and test vectors.
- Score can explain itself from components.
- Missing inputs reduce availability, not silently improve/worsen a score.
- No medical or Apple-equivalent accuracy claims.

### Phase 6: Owned Sensor Analysis Research

Purpose: decide whether Zeez should infer sleep stages independently.

Work:

- Determine which raw signals Zeez can legally and practically acquire from
  iPhone/watch in background usage.
- Prototype only against datasets with comparable sensors; MESA wrist
  actigraphy can help with sleep/wake research, while PSG/EEG-only datasets do
  not validate a watch-input stage model.
- Measure against a labeled reference set and document failure cases.
- Keep inferred outputs separate from Apple-reported stages.

Exit criteria:

- A go/no-go report demonstrates whether owned inference improves the product.
- No production stage inference is enabled without a defensible evaluation.

### Phase 7: Release Hardening

Purpose: make the focused product shippable.

Work:

- Real-device HealthKit import verification.
- Paired-watch payload/update verification.
- Permission, empty-state, reimport, migration, and accessibility review.
- Privacy wording and App Store claim review.
- Performance checks with months of imported sessions.
- Delete dormant/duplicated code confirmed unnecessary after active flows have
  stabilized.

Exit criteria:

- Release checklist passes.
- Product descriptions match the evidence and validation actually completed.

## Validation Strategy Without Extensive User Studies

| Workstream | Validation Method |
| --- | --- |
| Import, storage, normalization, calculations, and UI availability | Deterministic unit/integration tests |
| Apple-reported stages shown in Zeez | Preserve provenance and rely on Apple's reported stage output; verify import on a device later |
| Goal shortfall, consistency, charts, and trends | Fixture tests plus real-device smoke test |
| Experimental score behavior | Written scoring specification, test vectors, and public dataset exploration where inputs match |
| Zeez-owned stage inference | Requires later reference-data evaluation; do not treat ordinary app usage as proof |
| Clinical/medical interpretation | Out of product scope unless pursued separately with professional validation |

## Code Pruning Policy

The app is messy, but deletion should follow evidence.

For each candidate file or subsystem:

1. Find active references and navigation entry points.
2. Classify it as production, debug/testing, educational, dormant, or obsolete.
3. For production code, consolidate behavior before removal.
4. For dormant/obsolete code, remove it in a narrow compile-tested change.
5. Do not keep a stub that returns personal-looking mock metrics merely because
   another unused file still compiles against it.

Priority pruning candidates after reachability audit:

- Duplicate sleep detail views.
- Mock/stub personalization and historical-analysis types.
- Unsupported sleep recommendation code.
- Dormant trend/widget score/debt presentation.
- Environment/position/brain-activity analysis that has no real input path.

## Suggested Execution Sequence

Phase 1 is complete and its required routed-surface inventory is recorded in
`SLEEP_PHASE_1_CLAIMS_CONFORMANCE_CLOSEOUT.md`. The next implementation pass
may begin Phase 2:

1. Define the shared derived-metrics availability and provenance contract.
2. Move active repeated calculations through that contract.
3. Preserve the Phase 1 claims and accessibility policies on every migrated surface.
4. Add deterministic coverage for missing, partial, contextual `inBed`, and unspecified-stage evidence.
5. Run focused sleep suites and iPhone/watch builds.

Phase 2 must serve only the routed production surfaces established by the
closeout; it must not activate dormant analyses as an incidental side effect.

## Ready-To-Use Implementation Prompts

### Prompt A: Baseline And Reachability Audit

```text
Work in /Users/daniel/Documents/AppProjects/Zeez.

Read CLAUDE.md, AGENTS.md, SLEEP_RELIABILITY_IMPLEMENTATION_HANDOFF.md,
SLEEP_REFACTORING_PLAN.md, and SLEEP_METRICS_CLAIMS_AND_VALIDATION.md first.
Preserve the dirty worktree and completed sleep reliability/goal-shortfall
remediation.

Objective: execute Phase 1 of the canonical sleep roadmap. Trace active sleep
navigation from RootView/MainView/Dashboard/Settings/import through session
detail, sleep stages, estimated score, goal shortfall, recent sessions,
calendar/weekly progress, and phone-to-watch payload rendering. Classify sleep,
trends, widget, recommendation, environment, position, and learning-related
analysis surfaces as active, debug-only, educational-only, dormant, or
retirement candidates.

Identify active unsupported personal outputs, duplicate production detail
screens, placeholder/mock analysis reachable by users, and misleading
accessibility claims. Implement only narrow fixes required to stop unsupported
active behavior or consolidate duplicate active routing. Do not implement a new
score, new inference model, new HealthKit capability, or broad deletion pass.

Deliver findings first with file/line references, the reachability inventory,
modified files, focused deterministic tests, iPhone/watch simulator build
results, and deferred real-device checks.
```

### Prompt B: Derived Metrics Engine

```text
Work in /Users/daniel/Documents/AppProjects/Zeez.

Read CLAUDE.md, AGENTS.md, SLEEP_RELIABILITY_IMPLEMENTATION_HANDOFF.md,
SLEEP_REFACTORING_PLAN.md, and SLEEP_METRICS_CLAIMS_AND_VALIDATION.md. Begin
only after the Phase 1 reachability audit is complete.

Objective: execute Phase 2. Consolidate active sleep calculations into one
source-aware DerivedSleepMetrics contract with explicit metric availability and
provenance. Cover recorded interval, reported asleep duration, stage
composition, wake periods, sleep efficiency only where supported, selected-goal
shortfall, and period timing consistency with coverage.

Migrate active screens to the shared contract without expanding dormant
features. Remove user-facing fallback/default values that present missing input
as measured analysis. Add deterministic tests for imported typed stages,
asleepUnspecified, overlapping inBed, inBed-only data, missing stages, multiple
sessions per day, and insufficient trend coverage. Verify focused suites and
both simulator builds.
```

### Prompt C: Import Identity And Coverage

```text
Work in /Users/daniel/Documents/AppProjects/Zeez.

Read CLAUDE.md, AGENTS.md, SLEEP_RELIABILITY_IMPLEMENTATION_HANDOFF.md,
SLEEP_REFACTORING_PLAN.md, and SLEEP_METRICS_CLAIMS_AND_VALIDATION.md.
Preserve working derived-metrics behavior.

Objective: execute Phase 3. Make Apple Health import durably idempotent and
coverage-aware. Replace fragile duplicate policy where necessary with a stable
import identity/merge approach compatible with the existing Core Data model.
Record enough provenance and input coverage for derived metrics to distinguish
source-reported stages, asleep duration, in-bed context, heart rate, HRV,
respiratory data, and unavailable inputs.

Use deterministic HealthKit-boundary and in-memory Core Data tests. Do not
require real HealthKit access to implement or test logic; list the device checks
that remain deferred until Apple Developer account access is restored.
```

### Prompt D: Useful Trends Before A Proprietary Score

```text
Work in /Users/daniel/Documents/AppProjects/Zeez.

Read CLAUDE.md, AGENTS.md, SLEEP_RELIABILITY_IMPLEMENTATION_HANDOFF.md,
SLEEP_REFACTORING_PLAN.md, and SLEEP_METRICS_CLAIMS_AND_VALIDATION.md first.

Execute Phase 4 from SLEEP_REFACTORING_PLAN.md after the source-aware metrics
engine and import coverage are in place.

Objective: expose a coherent longitudinal sleep review using only supported
derived metrics: duration trend, recorded stage composition/availability,
schedule consistency, selected-goal shortfall, and evidence coverage. Activate
or replace existing trend UI only where it serves this scope. Do not make
clinical, recovery, or personalized health conclusions, and do not ship an
opaque score.

Add deterministic aggregation/accessibility tests and verify iPhone/watch
builds. Report dormant code that can now be removed in a separate cleanup.
```

### Prompt E: Experimental Score Specification And Implementation

```text
Work in /Users/daniel/Documents/AppProjects/Zeez.

Read CLAUDE.md, AGENTS.md, SLEEP_RELIABILITY_IMPLEMENTATION_HANDOFF.md,
SLEEP_REFACTORING_PLAN.md, and SLEEP_METRICS_CLAIMS_AND_VALIDATION.md first.

Execute Phase 5 only after the supported derived metrics and longitudinal views
are stable.

Objective: define and implement an explicitly experimental Zeez score derived
from transparent components and source-aware available inputs. First write a
score specification covering meaning, exclusions, required inputs, missing-data
behavior, provenance, calculation versioning, and test vectors. Then implement
the narrowest matching calculation and UI/watch presentation.

The score must not claim health, recovery, medical sleep debt, diagnosis, or
Apple-equivalent staging accuracy. It must remain visually and accessibly
labeled as an experimental Zeez estimate. Add deterministic score-component
tests and report the later dataset/device validation still needed.
```
