# Parked Capabilities

Status: Live register of removed and dormant product capabilities
Created: 2026-07-09 (second-audit item C0)
Binding contracts: `SLEEP_METRICS_CLAIMS_AND_VALIDATION.md`, `ZEEZ_SCORE_SPECIFICATION.md`

## Why this file exists

Audit phases A and B removed several capabilities. Every removal was justified — the code was
unreachable, fabricated data, or made claims the product cannot support — but the *intent*
behind each feature was recorded only in `SECOND_AUDIT_IMPROVEMENTS.md`, an audit tracker that
will be archived like `IMPROVEMENT_ROADMAP.md` before it. That would leave no answer to the
question "were we ever going to build this?"

**This register preserves the specification, not the implementation.** For most entries below
the deleted code is a liability rather than a head start: the HRV section computed "RMSSD" from
averaged HealthKit samples, which is not HRV at any sampling rate. Restoring that file would
restore a wrong implementation. What is worth keeping is the statement of what a correct
implementation requires — which is exactly what the claims contract demands *before* any Tier-3
feature ships (line 62: "written specification, versioned inputs, deterministic test vectors").

Nothing here is scheduled. An entry means "the idea survived the deletion", not "this is next."

## How to recover deleted code

Git retains everything. To find the commit that deleted a file and read it back:

```bash
git log --diff-filter=D --format=%h -1 -- <path>   # → <sha> of the deleting commit
git show <sha>^:<path>                              # print the file as it last existed
```

This is deliberately SHA-free, so it survives rebases. Known SHAs are listed per entry as a
convenience, not as the primary handle.

---

## 1. Heart-rate variability timeline

**Removed:** A1 (`8dd9d47`) — `Zeez/Views/HeartRate/HRVChart.swift`, `calculateHRV` in
`Zeez/Views/HeartRateView+Helpers.swift`.

**What it did.** Showed an "HRV" chart and insights panel on the Heart Rate screen, grading
results poor / fair / good / excellent.

**Why removed.** Two independent violations. It derived "RMSSD" from *averaged* HealthKit
heart-rate samples rather than beat-to-beat intervals, so the quantity was not HRV. And when
fewer than three windows existed it invented chart points with `Double.random(in: -0.15...0.15)`
and presented them as the user's personal timeline. The grading was an unvalidated Tier-3+
health judgment.

**Inputs required.** `HKQuantityTypeIdentifier.heartRateVariabilitySDNN`, imported directly.
The claims contract (line 84) states "HRV import support requires confirmation" — the HealthKit
type and its unit must be documented before the read scope is widened. Today's scope is exactly
`sleepAnalysis`, `heartRate`, `respiratoryRate` (B13), pinned by `HealthKitAuthorizationTests`;
adding a fourth type also changes the App Privacy questionnaire answer.

**Claims tier and label.** Tier 3. Must be conspicuously marked "Experimental Zeez Estimate",
with inputs, exclusions, and unavailable behavior specified. No quality grading, ever — the
contract prohibits "recovery/readiness" and inferred-disorder wording on this row.

**Missing-input policy.** Absent SDNN samples render the section *unavailable*, never a neutral
or interpolated value. Never synthesize points to fill a sparse chart (rule 4).

**Validation status.** None. No dataset or device evaluation has been run.

**Definition of done.** SDNN imported and unit-tested; a written spec in the style of
`ZEEZ_SCORE_SPECIFICATION.md`; deterministic test vectors; "Experimental" label present in the
chart, its `accessibilityValue`, and any watch payload; `HeartRateClaimsGuardTests` updated to
permit the new symbol while still forbidding randomized fills.

---

## 2. Pillow CSV / JSON import

**Removed:** B2 (`b7dc142`) — `Zeez/DataImport/PillowDataImporter.swift`,
`Zeez/Views/DataImportView.swift`.

**What it did.** Imported sleep sessions exported from the Pillow app. Reachable only from
`DataImportView`, which was itself unreferenced.

**Why removed.** Dead, and defective in five ways that each violate rule 4 (never fabricate a
missing input): missing quality became a hardcoded `75.0`; a CSV quality fallback computed
`duration × 12`; an unknown stage became `"light"`, inventing stage information; a ±1-hour dedup
tolerance matched against **any** source, silently dropping legitimate imports; the CSV parser
split on commas without honoring quoting, and parsed dates in `TimeZone.current` rather than the
export's zone.

**Inputs required.** A documented Pillow export schema. Without one, quality and stage fields
must be treated as absent rather than guessed.

**Claims tier and label.** Tier 1 for values Pillow itself reports, provided provenance is shown
("reported by Pillow"). Any Zeez-derived quantity computed from them is Tier 3.

**Missing-input policy.** Absent quality → no score, not `75.0`. Unknown stage →
`asleepUnspecified`, never `light`. Dedup must compare within a source, not across sources.

**Validation status.** None.

**Definition of done.** All five defects fixed; a quoted-CSV parser with fixture tests; timezone
taken from the export; dedup scoped by `deviceIdentifier`; provenance surfaced in the UI. Note
the `"Pillow Import"` string still appears as a test fixture, because legacy shipped stores hold
that identifier and those sessions must survive `clearMockData` — do not repurpose it.

---

## 3. Sleep debt and recovery framing

**Removed:** B7 (`b0c58ef`) — `Zeez/Sleep/Debt/DebtSeverity.swift`,
`Zeez/Sleep/Debt/SleepDebtMetrics.swift`, `Zeez/Learn/Sleep/LearnSleepDebtHistoryView.swift`,
`Zeez/Learn/Sleep/LearnSleepDebtDetailView.swift`, and `RecommendationsView`.

**What it did.** Graded accumulated "sleep debt" as minimal / moderate / significant / severe,
attached health-risk impacts ("weakened immune system", "cardiovascular strain"), produced a
"Recovery Timeline" and "recovery plan", and told severe users to "consult a healthcare
professional".

**Why removed.** Tier 4 (medical / clinical conclusions) — outside what this product may claim
at any confidence level. Two of these surfaces were **live**, not dormant, contrary to the
tracker's assumption: `SleepGoalSettingsView` displayed "Weekly Sleep Debt" over a value that was
already a goal shortfall.

**Inputs required.** None that would make the original framing permissible. A user-selected sleep
goal is not a determination of physiological need, so a shortfall against it is not "debt".

**Claims tier and label.** Any revival must use **goal-shortfall** vocabulary and stay within
Tier 2 (arithmetic against a user-chosen target). `ClinicalVocabularyGuardTests` enforces the
prohibited phrases across every non-Learn tree and will fail the build if they return.

**Note.** `Zeez/Learn/LearnSleepDebtView.swift` remains live and is intentionally exempt: it
teaches sleep debt as a published concept (NHLBI framing) rather than reporting the user's own,
and says so on screen. `DailyMetrics.sleepDebt` also remains, as a persisted Core Data attribute
— renaming it requires a new model version, so the name stays and the *presentation* is what the
guard test polices.

**Validation status.** Not applicable; the framing is prohibited rather than unvalidated.

---

## 4. Real WidgetKit extension

**Removed:** B1 (`ee534b8`) — `Zeez/Widgets/Widget.swift`, `Zeez/Widgets/WidgetContainer.swift`,
`Zeez/Views/WidgetViews.swift`, `Zeez/Views/WidgetPickerView.swift`.

**What it did.** Nothing — the tree was unreachable in-app cards, misleadingly named "Widgets".
It contained a hardcoded "Room Temperature 20°C / Optimal" reading, "coming in Phase 2"
placeholder copy, "accumulated sleep debt and recovery status" wording, and premium flags nothing
enforced.

**Why removed.** Dead code carrying three separate claims violations.

**Definition of done.** A real WidgetKit extension target (not in-app cards). Tracked as Phase **D3c**
in `SECOND_AUDIT_IMPROVEMENTS.md`. Every value it surfaces is bound by the same claims rules as
the in-app equivalent, including the "Experimental Zeez Estimate" label on any score — in visible text
*and* in `accessibilityValue` (rule 10) — the `qualityScore <= 1.0` no-score sentinel rendered as "no
estimate" rather than a number, and the `measured*` accessors for environmental readings (never the raw
sentinel attributes).

**Data prerequisite: done (D3a, 2026-07-09).** An extension can only reach the app's Core Data store
through a shared App Group container, and the store used to open at the default app-container URL.
`CoreData/StoreLocation.swift` now puts it in `group.com.danielsparano.zeez` and relocates any legacy
store on first launch. This had to land before any user had data — afterward it would have been a
migration against real sleep history. ⚠️ It stays inert until the **App Groups capability is toggled once
in Xcode**; CLI `xcodebuild` strips profile-backed entitlements, so the group path cannot be exercised
from the command line.

---

## 5. Personalized sleep recommendations

**Removed:** C2 — `Zeez/Sleep/SleepRecommendationSystem.swift`,
`Zeez/Sleep/SleepRecommendationGenerator.swift`, `Zeez/Sleep/SleepRecommendationTypes.swift`.

**What it did.** Nothing reachable. `SleepRecommendationSystem.generateRecommendations(ageGroup:
activityLevel:)` would have produced an optimal schedule, quality tips, and schedule adjustments.
B7 deleted its only would-be caller: a "Get Personalized Recommendations" button in
`SleepGoalSettingsView` that set state with no sheet attached, so it did nothing when tapped.

**Why removed.** Dead, and claims-blocked. `AgeGroup.recommendedSleepRange` returned a
physiological sleep-need range (7–9 h) and `ActivityLevel.sleepAdjustment` added up to 1.5 h based
on activity. Determining how much sleep a person *needs* is a Tier-4 clinical conclusion. It also
required age and activity-level data the app has never collected and does not ask for — the
button promised advice derived from inputs that do not exist.

**Inputs required.** Either the app starts collecting age and activity level (a privacy-manifest
and App Privacy questionnaire change, currently "no data collected"), or recommendations are
restricted to the user's *own* recorded history against their *own* selected goal.

**Claims tier and label.** Personal suggestions are Tier 3 at best (claims matrix line 62:
"correlations, or personal suggestions whose accuracy or usefulness has not been independently
established"). Published-norm ranges may be cited as education in the Learn tree, attributed, and
never applied to the individual as a determination of need.

**Missing-input policy.** No age or activity data → no recommendation. Do not default to "adult".

**Validation status.** None.

**Definition of done.** A decision on whether Zeez collects age/activity at all; a written spec;
goal-shortfall rather than sleep-need vocabulary. `ClinicalVocabularyGuardTests` now asserts
`SleepRecommendationSystem` stays deleted, so reviving the type name is a deliberate act.

**Stubs deleted 2026-10-27.** `PersonalizationManager` and `HistoricalAnalyzer`, in
`Zeez/Sleep/SleepAnalysisTypes.swift`, returned hard-coded "personalized baselines" and "sleep
patterns": a consistency score of 75, "Regular"/"Delayed" weekday and weekend patterns, and 0.7–0.8
confidence. Nothing called them, but the first caller would have shown those numbers as the user's
own. They went with the file's other dead types; the goal-shortfall types it also held now live in
`SleepGoalShortfall.swift`. Personalization starts from this entry, not from those types.

---

## 6. Session detail, monthly trends, and environmental display views

**Removed:** C2 — `Zeez/Sleep/SleepDetailView.swift`, `Zeez/Views/MonthlyTrendsView.swift`,
`Zeez/Environment/EnvironmentalDataView.swift`, `Zeez/Environment/EnvironmentalFactors.swift`,
`Zeez/Environment/AverageEnvironmentalReadingView.swift`.

**What they did.** A per-session detail screen, a monthly trends screen, and three environmental
display views. All unreachable — no callers outside their own `#Preview` blocks.

**Why removed.** Pure dead UI. They drifted out of sync with the data model (B5 had to update the
noise labels in views nobody could open), and each one that survives is a surface a future claims
review must re-read.

**Note on rebuild.** These are presentation only; the data they showed is intact and now better.
Rebuild against `DerivedSleepMetrics`, `asleepStageComposition`, `NoiseIndex`, and the
`measured*` environmental accessors rather than restoring the files — the deleted versions predate
all four. `MonthlyTrendsDataProvider`, `TrendInsightsSection`, and `MonthlyChartSection` were
**not** deleted, because C2 believed they were live behind `TrendsView`. They are not.
`TrendsView` itself had no entry point from `ac140c2` (2025-08-19); this was found 2026-10-22.
**Reconnected 2026-10-26** through the dashboard's Sleep Trends link, after a claims pass over everything it
shows (`FUTURE_IMPROVEMENTS.md`, completed 2026-10-26). The monthly views are now live.

**Claims tier and label.** Whatever they display. A rebuilt session-detail screen showing a Zeez
score must carry the "Experimental Zeez Estimate" label in text *and* `accessibilityValue`
(rule 10), and must respect the `qualityScore <= 1.0` no-score sentinel.

---

## 7. Environmental correlation and insights — *parked in tree, not deleted*

**Status:** Present in the codebase, deliberately dormant. Not scheduled.

**Files:** `Zeez/Environment/EnvironmentalAnalyzer.swift`,
`Zeez/Environment/EnvironmentalInsightsView.swift`,
`Zeez/Environment/EnhancedEnvironmentalScoring.swift`,
`Zeez/Environment/EnvironmentalRecommendationTracker.swift`.

**Why it looks dead but is not.** `EnvironmentalInsightsView` and `EnhancedEnvironmentalScoring`
have no callers; they are the only consumers of `EnvironmentalAnalyzer`, which is in turn the only
consumer of `EnvironmentalRecommendationTracker`. A dead-code sweep would take all four. The
subsystem stays because the parking was deliberate and documented — `MonthlyTrendsDataProvider`
carries the reason at its `generateMonthlyInsights` call site:

> `// Sleep-debt and environmental insights are omitted until the underlying`
> `// measurements and computation are production-ready and data-backed.`

`EnvironmentalAnalyzer` is also not stale: B5 rewrote its thresholds and copy when noise moved
from fabricated dB to the relative index.

**What holds it in the build.** `MonthlyInsight.environmentalImprovementNeeded(recommendations:)`
references `EnvironmentalRecommendation`. The case is never constructed; it exists so the wiring
survives. Deleting the case is the first step of retiring the subsystem, should that be decided.

**Claims tier and label.** Correlations between environment and sleep are Tier 3 (claims line 62),
and "caused poor sleep" is explicitly prohibited. Recommendations derived from them are Tier 3.
Environmental readings must be consumed through the `measured*` accessors — the raw attributes use
the `-1` sentinel and read as a freezing, pitch-dark room when absent.

**Missing-input policy.** A mic-denied session has no noise reading. It must render unavailable,
never `0` and never "quiet".

**Validation status.** None. The gating comment's bar — "production-ready and data-backed" — is
the correct one, and no data backing exists.

**Definition of done.** Real measurements with documented accuracy; a written correlation spec
with test vectors; Tier-3 labeling throughout; a route into the app from `TrendsView`.

---

## 8. Sleep-product roadmap residue — *never built, not deleted*

**Status:** Outstanding work from `Archive/SLEEP_REFACTORING_PLAN.md` Phases 3, 4, and 5, recorded
here (second-audit D3d) because that plan is archived and phases A–C delivered most of it under
different names. Nothing here is scheduled.

**a. Durable HealthKit import identity (Phase 3).** ✅ **Delivered in code 2026-10-22** (`2244e20`…`47b040d`);
the documented device check is `DEVICE_TEST_RUN.md` **T3.1**, pending the device pass.

- *Identity:* model **v3** (`Zeez 3.xcdatamodel`) adds `SleepStage.healthKitSampleUUID` (`HKObject.uuid`) and
  `sourceBundleIdentifier`. It sits on the stage, not the session as first sketched below: a night's start
  moves when Apple Health extends it, a sample's uuid does not, and HealthKit reports deletions only by uuid.
- *Merge policy* (`Zeez/DataImport/SleepImportReconciler.swift`): a night is every stored HealthKit session and
  fetched sample chained within the 4-hour grouping gap, so a re-import lands on the nights a fresh import
  would. Samples are matched by uuid; sessions the old rule duplicated fold into the oldest, which keeps its
  `id`; pre-v3 stages are replaced by the identified copy of the same sample. Zeez-recorded sessions are never
  merged with imported ones.
- *Overlapping sources:* not ranked (Daniel, 2026-10-22). A night holds every source's samples and each stage
  records its source; time asleep follows the claims contract's union definition, and conflicting stage types
  make composition unavailable. A per-night preferred source would need a contract amendment first.
- *Deletion:* explicit only. Absence is never deletion — HealthKit returns an empty result, not an error, when
  read access is revoked. Deletions come from an `HKAnchoredObjectQuery` (`HealthKitSleepAnchor.swift`) whose
  anchor is kept in `UserDefaults` and advanced only after the deletions it covers are saved. A night whose
  samples are all deleted is removed.
- *Related data:* a changed night's heart-rate and respiratory readings are re-fetched and replaced; an empty
  fetch keeps what is stored.
- *Migration:* the v2→v3 hop is the store's first structural migration. It runs as Core Data automatic
  lightweight migration after a WAL-safe backup; the manual path, whose sidecar handling was broken, is now
  only the fallback and was fixed. On an install predating D3a, relocation and migration run on the same launch
  (T1).

*Known limits.* HealthKit may purge its record of a deletion at any time, so a deletion made long before the
next import can go unreported and the sample stays — the same outcome as not propagating deletions, never a
wrong one. Stages imported before v3 carry no uuid, so their deletions cannot be applied until the night is
re-imported. A HealthKit night overlapping a Zeez-recorded session is kept as two sessions.

*Original stub, kept for provenance:* Import currently deduplicates on start-time
proximity. A correct implementation keys on HealthKit sample identity (`HKObject.uuid`) or stored
import metadata, defines an overlapping-source merge policy, and makes re-import safe. B2's deleted
Pillow importer failed exactly here — a ±1-hour tolerance matched across *any* source and silently
dropped legitimate sessions. *Inputs required:* stable sample identity persisted on `SleepSession`,
which is a Core Data model version bump. *Definition of done:* re-import neither duplicates nor
discards; deterministic regression tests plus one documented device check.

**b. Coverage reporting (Phases 3 and 4).** ✅ **Delivered 2026-10-20** — `Zeez/Sleep/SleepCoverage.swift`:
`NightCoverage` on Trends ("Recorded on 5 of the last 7 nights", plus how many carry an estimate) and
`SessionInputCoverage` as the "Recorded Inputs" card in session details. The same change stopped Trends
showing "0%" / "0h 0m" for an empty period. Kept below for provenance. "5 of 7 nights recorded", and per-session input coverage
(stages, asleep time, in-bed context, HR, respiratory, and what is missing) surfaced to the user.
`QualityMetrics.inputCoverage` already computes this per session (B8) but nothing renders it.
*Claims tier:* Tier 1 — it reports what was recorded, not what it means. *Missing-input policy:* a
night with no recording is absent, never zero; trends must never average unavailable scores or
fabricate missing nights.

**c. A component score the user can see (Phase 5).** ✅ **Delivered 2026-10-20** — see
`ZEEZ_SCORE_SPECIFICATION.md` §8 and `ZeezScoreBreakdown`. Kept below for provenance. The score's exit
criterion "can explain itself from components" was **not met**: `QualityMetrics.components` holds a per-component
`ComponentResult` and `ZeezScoreComponent` carries the weights, but the values never leave
`SleepQualityCalculator` — no view renders the breakdown, so the score is still an opaque number to
the user. *Definition of done:* a breakdown surface that names each component, its weight, and
whether it was available; the "Experimental Zeez Estimate" label in text **and** `accessibilityValue`
(rule 10); the `qualityScore <= 1.0` sentinel rendered as "no estimate", never as a number.

---

## 9. Owned-sensor stage inference — *shipped, unvalidated*

**Status:** Live in production. The **evaluation** is what is parked, not the code.
`Archive/SLEEP_REFACTORING_PLAN.md` Phase 6.

**What it does.** `Zeez/Sleep/Stage/SleepStageAnalyzer.swift` infers sleep stages from movement and
heart rate for every Zeez-recorded session. B8 made `stageDistribution` a **required** score
component, so those inferred stages are the substrate of the Zeez score.

**The gap.** Phase 6's exit criterion is "no production stage inference is enabled without a
defensible evaluation." No dataset or device evaluation has been run;
`ZEEZ_SCORE_SPECIFICATION.md`'s validation-status table says so. What stands in for an evaluation is
the Tier-3 "Experimental Zeez Estimate" label and the missing-input policy. **That is a disclosure,
not a validation**, and the distinction should not blur over time.

**Inputs required for an evaluation.** A labeled reference set with *comparable sensors*. Per the
plan: MESA wrist actigraphy supports sleep/wake research; PSG/EEG-only datasets do **not** validate a
watch-input stage model, and citing them would itself be a claims violation.

**Claims tier and label.** Tier 3, and it must stay there. Inferred stages must never be presented
as equivalent to Apple-Health-reported stages — `displayName(reportedByAppleHealth:)` and
`stageSourceDescription` exist to keep the two visually distinct. The score deliberately refuses to
grade Apple's own stages (spec §2), so the two provenances must never be merged into one denominator.

**Definition of done.** A go/no-go report measuring inferred stages against a labeled reference,
documenting failure cases. If no-go, the honest outcome is to stop scoring stage distribution rather
than to keep labeling it experimental indefinitely.

---

## 10. Learn home screen

**Removed:** D1a — `Zeez/Learn/LearnHomeView.swift` (with its `Route` enum and `CategoryCard`).

**What it did.** Nothing reachable. It was added in `ac140c2` (2025-08-19) as an alternative Learn
landing page — a search bar, a daily-fact preview, a category grid, and progress, notes, tools, and
practice sections — routed through a typed `Route` and `navigationDestination`. Nothing ever created
it; the Learn tab has always been `LearnView`.

**Why removed.** Dead, and not a model to copy for D1: it nested a `NavigationView` inside a sheet
presented from its own `NavigationStack`, the double-container shape D1 removes. Its
`navigationDestination(for:)` routing is the one useful idea in it.

**Left without callers, then deleted (2026-10-27).** `LearnDailyFactView` (and
`LearnDailyFactPreview`) and `LearnNoteBrowserView` were reachable only from this screen. Daniel chose
to delete them, with the two helpers only the browser used: `NoteCard` (`Note/LearnNoteCard.swift`)
and `Views/FetchRequestView.swift`.
- *Daily fact.* It showed one `SleepFact` a day, then the rest as a list. Nothing in the app ever
  creates a `SleepFact`, so it could only have shown its empty state. The entity stays in the model;
  removing it is a model change. A return needs a written, attributed set of facts, reviewed against
  the claims contract (§4), and something that seeds it.
- *Note browser.* It filtered notes into highlights, article notes and quick notes, and shared a
  selection of them. Learn still reaches notes through Quick Notes and an article's highlights, and
  `LearnNoteDetailView` still shares a single note.

**Still without callers** (found 2026-10-27 by a reference search over `Zeez/`; not deleted):
`LearnContentManager` with `LearnContentManager+DefaultContent`, `LearnEnvironmentalDetailView`,
`LearnGlossaryView` (and `LearnGlossaryTermDetailView`, which only it opens), `LearnReferenceView`,
`ToolCard` (`LearnToolCard.swift`), `LearnNoteListView`, `LearnQuizBrowserView` and
`LearnSleepPositionDetailView`. A Learn cleanup should decide each one the same way.

**Claims tier and label.** Educational content. `ClinicalVocabularyGuardTests` exempts `Zeez/Learn`,
so any Learn surface that returns needs its copy reviewed by hand against
`SLEEP_METRICS_CLAIMS_AND_VALIDATION.md` §4.

**Definition of done.** A product decision that Learn needs a landing page distinct from
`LearnView`'s segmented tabs. Build it inside the Learn tab's `NavigationStack` (`MainView`) with
`navigationDestination` routes and no container of its own.

---

## 11. Custom alarm sound import — *never built*

**Removed:** 2026-10-27 — the alarm sound picker's "Add Custom Sounds" section
(`Zeez/Alarm/AlarmSoundPickerView.swift`), reachable from Alarm → edit an alarm → Alarm Sound. It held a
"Pro Tip" telling the user to add audio files to their music library and import them through the Files
app, above an "Import from Files" button whose action was `// TODO: Implement custom sound import`.

**What it did.** Nothing. The app has no import. The picker's "Custom Sounds" are the bundled Zeez sounds
(`AlarmSounds.customZeezSounds`) and any other audio file in the app bundle.
`AlarmAudioController.startLooping(fileURL:)` can loop a file outside the bundle, but nothing calls it.

**Why removed.** A dead control on a reachable screen, under instructions for a feature that does not
exist; an App Review completeness risk (guideline 2.1). `DeadControlGuardTests` now fails on any new button
whose action is empty.

**What an import needs.** An alarm rings through two players, and an imported sound has to work in both:
- The main notification and its follow-ups use `UNNotificationSound(named:)`. It finds files only in the
  app bundle and in `Library/Sounds` of the app's (or an App Group's) container, plays at most 30 seconds
  (longer files get the default sound), and takes Linear PCM, IMA4, µLaw or aLaw in an aiff, wav or caf.
- The in-app loop, `AlarmAudioController.startLooping(fileURL:)`, plays anything `AVAudioPlayer` reads.

So an import converts and trims the file into `Library/Sounds`, the picker lists those files, and
`AlarmScheduler` and `AlarmNotificationHandler` find them by name, as they find bundled sounds now. Delete
All Data removes them. Each ringing path (foreground, locked, force-quit) needs a device check.

**Claims tier and label.** None; an alarm sound is not a sleep metric.

**Definition of done.** The above, with a test that an imported file lands in `Library/Sounds` in a
notification-playable format, and a `DEVICE_TEST_RUN.md` check.
