# Zeez Sleep Metrics Claims And Validation Contract

Status: Canonical supporting document for sleep product claims  
Adopted: 2026-05-26  
Applies to: iPhone UI, watch UI and payloads, widgets, charts, accessibility
output, notifications, educational-to-personal transitions, analytics
descriptions, and App Store or marketing copy

## 1. Purpose And Scope

This document defines the evidence, naming, disclosure, missing-data, and
validation rules for every sleep metric or analytical claim shown in Zeez. It
complements `SLEEP_REFACTORING_PLAN.md`, which remains the canonical phase
roadmap.

Zeez is a personal sleep review product built primarily on sleep evidence
imported from Apple Health. It may calculate transparent descriptive metrics
from that evidence and a user-selected goal. It must not turn source data,
missing inputs, or unvalidated analysis into clinical-sounding personal
conclusions.

## Governance Findings At Adoption

The following constraints refine or qualify the existing planning material:

- Apple HealthKit defines `inBed` independently from detailed `awake`,
  `asleepCore`, `asleepDeep`, `asleepREM`, and `asleepUnspecified` samples.
  `inBed` may overlap detailed states and must not be counted as a sleep stage.
- Apple defines `asleepUnspecified` as asleep without a known specific stage.
  Treating it as Core, light, REM, or Deep invents information.
- Apple states that Apple Watch sleep samples may omit awake detail at the
  beginning or end of an in-bed sample. Consequently, Zeez may show reported
  awake intervals, but must not claim it observed every awakening or infer
  sleep onset latency from incomplete boundary data.
- Apple's sleep-stage validation supports careful display of Apple-produced
  estimated stages with provenance. It does not validate a Zeez score,
  Zeez-owned stage inference, medical conclusions, or claims of clinical
  measurement.
- Standard definitions support time asleep, sleep efficiency, sleep latency,
  wake after sleep onset (WASO), and number of awakenings only when their
  required input intervals exist. A neutral-looking fallback is not a metric.
- NHLBI uses sleep debt in relation to sleep lost versus sleep need. A
  user-selected Zeez goal is not a determination of physiological need. The
  product should therefore use goal-shortfall wording, not medical sleep-debt
  or recovery wording.
- Public PSG/actigraphy datasets can support exploratory method evaluation when
  signal inputs are comparable. They cannot validate Apple proprietary outputs
  or a Zeez watch-input model without an appropriate paired-data design.
- Resolved in the Phase 1 claims-conformance closeout on 2026-05-26:
  `SLEEP_RELIABILITY_IMPLEMENTATION_HANDOFF.md` is a historical audit, while
  current source and regression tests confirm its imported-stage,
  unavailable-score, startup recovery, and imported-parent-save remediation.
  See `SLEEP_PHASE_1_CLAIMS_CONFORMANCE_CLOSEOUT.md` for the active-surface
  inventory and current verification.

## 2. Evidence Tiers

| Tier | Meaning | Permitted Presentation | Validation Gate |
| --- | --- | --- | --- |
| Tier 1: Source-reported data | Data imported from Apple Health without Zeez reinterpretation, including sleep stage intervals and available physiological samples. Apple Watch stage outputs remain Apple estimates. | Display with provenance, for example "Reported by Apple Health" or "Apple Health reported Core sleep." | Import mapping, identity, overlap, missing-data, device import, and display/accessibility verification. |
| Tier 2: Deterministic derived metrics | Transparent Zeez calculations from Tier 1 evidence and/or a user-selected goal. | Label as "Derived" or describe the calculation, for example "Below Your Selected Goal." | Deterministic unit/integration tests, input-availability policy, provenance in presentation, device smoke verification where imports are involved. |
| Tier 3: Experimental Zeez interpretations | A Zeez score, owned stage inference, correlations, or personal suggestions whose accuracy or usefulness has not been independently established. | Only when conspicuously marked "Experimental Zeez Estimate," with inputs, exclusions, and unavailable behavior specified. | Written specification, versioned inputs, deterministic test vectors, and later appropriately matched dataset/device evaluation before any stronger wording. |
| Tier 4: Prohibited clinical claims without separate validation | Diagnosis, treatment advice, medical sleep debt, recovery/readiness, health-risk conclusions, or Apple-equivalent/clinical staging accuracy. | Not a supported Zeez product claim. | Separate reference-data or clinical validation and applicable regulatory review before reconsideration. |

## 3. Metric Claims Matrix

`Current status` records only what can be established from the roadmap and
third-audit handoff. It is not an assertion that active code conforms.

| Metric Or Feature | Required Input Data | Tier | Acceptable User-Facing Label Or Claim | Language To Avoid | Missing-Data Behavior | Validation Required Before Release | Current Status From Planning Documents |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Recorded sleep session duration | A sourced session start and end with valid ordering | 1 or 2, depending on persisted source representation | "Recorded session duration" | "Time asleep" unless asleep inputs support it; "clinically measured sleep" | Unavailable for invalid/missing bounds; do not equate interval duration with sleep | Boundary, timezone, DST, and duplicate-session fixture tests; presentation review | Roadmap identifies this as ship-quality; prior remediation says `SleepInformationView` now uses session-duration wording. |
| Time asleep | Non-overlapping union of Apple Health asleep values: Core, Deep, REM, and `asleepUnspecified` where imported | 2 derived from Tier 1 | "Time asleep, reported by Apple Health" or "Derived time asleep from Apple Health sleep records" | "Exact sleep duration"; "Zeez measured sleep" | Unavailable when no usable asleep intervals; never replace with session duration | Mapping, overlap/deduplication, partial coverage, multiple-source, and presentation tests; real-device import check | Planned for the shared derived metrics engine; existing information calculations are identified for consolidation. |
| In-bed interval | Apple Health `inBed` intervals, retained with provenance | 1 | "In Bed, reported by Apple Health" | "Asleep"; inclusion as a sleep stage | Hide or state not reported when absent; absence must not be fabricated from sleep stages | Mapping and overlap tests; verify denominator policy wherever used | Handoff identifies current semantic risk; roadmap states it must be contextual only. |
| Awake periods / awakenings | Apple Health `awake` detail intervals and a defined episode boundary | 1 for intervals; 2 for counts | "Recorded awake periods" or "Awake intervals reported by Apple Health" | "All awakenings"; "sleep fragmentation disorder"; diagnostic interpretation | State unavailable/incomplete if awake detail or episode coverage is absent; do not infer edge wake | Interval/count fixture tests and disclosure check; real-device Apple Health behavior review | Planned; Apple Watch boundary limitation requires UI disclosure policy. |
| REM/Core/Deep duration | Imported Apple Health detailed stage intervals of the corresponding type | 1 or transparent Tier 2 total | "REM/Core/Deep reported by Apple Health" or "Recorded REM duration" | "Zeez detected REM"; "restorative sleep"; normal/abnormal conclusions | Stage unavailable when not reported; distinguish from unspecified asleep | Exact value mapping and overlap tests; accessibility/source-label review | Phase 1 confirms active Apple Health stage UI uses source-aware Core/Deep/REM presentation; physical-device import verification remains deferred. |
| `asleepUnspecified` duration | Imported Apple Health `asleepUnspecified` intervals | 1 or transparent Tier 2 total | "Asleep, stage unspecified" | "Core," "Light," "REM," or "Deep" | Preserve and display as unspecified or include only in clearly defined total asleep; never redistribute | HealthKit boundary mapping regression test and chart/legend review | Phase 1 confirms active mapping and stage presentation preserve unspecified asleep honestly; covered by focused regression tests. |
| Stage percentages / composition | Typed Apple Health asleep stages; explicit denominator, including policy for `asleepUnspecified` | 2 | "Reported sleep stage composition" and a disclosed denominator such as "of staged sleep" | Stage-quality judgments; including `inBed` in percentages; hiding unspecified redistribution | Unavailable when denominator has no eligible stage data; show coverage/unspecified separately when relevant | Calculation tests for `inBed` overlap, unspecified data, denominator choice, and accessibility values | Phase 1 confirms active stage composition excludes `inBed` and awake rows and retains unspecified asleep; central derived-metrics consolidation remains Phase 2. |
| Sleep efficiency | Time asleep and a defensible time-in-bed/opportunity interval with disclosed denominator | 2 | "Derived sleep efficiency: time asleep as a percentage of reported time in bed" | "Sleep quality"; disorder inference; silent use of recording/session duration as `inBed` | Unavailable if required denominator is absent or invalid; an alternative ratio must have a different name | Formula/denominator fixtures; input-provenance review; real-device coverage review | Roadmap permits only with valid inputs and calls for replacing fallback values. |
| Sleep onset latency (SOL), if supported | A valid in-bed/bedtime boundary plus first asleep boundary with adequate start-of-period coverage | 2 | "Derived time from reported in-bed start to first reported sleep," only with coverage disclosure | "Time it took you to fall asleep" when boundary wake/in-bed coverage is incomplete; insomnia conclusions | Unavailable by default if start coverage cannot be demonstrated | Define eligibility first; test boundary gaps and Apple Watch edge-awake limitation; device verification | Optional in target architecture; not established as production-ready. |
| Wake after sleep onset (WASO), if supported | A sleep episode with first and final asleep boundaries plus awake intervals inside that period | 2 | "Derived recorded awake time after sleep onset" | "All awake time overnight"; clinical fragmentation or insomnia conclusions | Unavailable or explicitly limited when adequate interval coverage is not present | Eligibility and formula fixtures; missing-awake disclosure; real-device verification | Optional in target architecture; not established as production-ready. |
| Bedtime / wake-time consistency | Sufficient nights with sourced timing boundaries; stated period, minimum-night and timezone rules | 2 | "Your recorded sleep start time varied by X over this period" | "Circadian disruption"; health-outcome claims; fixed quality grade | Unavailable below the defined coverage minimum; report included nights | Aggregation, DST/timezone, multiple-session, nap/exclusion, and accessibility tests | Phase 4 target; existing fixed consistency calculation is listed for replacement. |
| Sleep goal shortfall | User-selected goal and available derived sleep duration with provenance | 2 | "Sleep Goal Shortfall" or "Below Your Selected Goal" | "Sleep debt"; "deficit"; "recovery needed"; biological-need claims | Unavailable if goal or qualified duration is unavailable; never default to zero | Goal comparison/unit tests, provenance and copy review | Phase 1 confirms the active dashboard/Learn path is labeled as goal shortfall with non-medical disclosure and focused tests. |
| Heart rate, HRV, or respiratory rate, where available | Imported physiological samples, source metadata, unit, and relevant time range | 1 for reported values; 3 for sleep associations | "Heart rate reported for this recorded session" or equivalent measured-signal wording | "Caused poor sleep"; "recovery/readiness"; inferred disorder or stage without validation | Show unavailable when absent; do not infer normal or neutral values | Import/unit/range tests and device verification; source documentation confirmation for every enabled quantity type | Roadmap anticipates input coverage; handoff states heart-rate and respiratory imports exist, not that interpretive claims are supported. HRV import support requires confirmation. |
| Zeez estimated / experimental sleep score | Written score specification, enumerated qualified inputs, version, and missing-input policy | 3 | "Experimental Zeez Estimate" with component explanation | "Sleep quality" as validated health judgment; "recovery"; "readiness"; "clinically validated" | No score unless all specification-required inputs are available; no sentinel displayed as personal result | Specification and test vectors; provenance/UI/accessibility/watch review; later matched research before stronger claim | Phase 1 keeps existing reachable output explicitly labeled `Experimental Zeez Estimate` and availability-gated; score redesign/specification remains Phase 5. |
| Zeez-owned inferred sleep stages | Defined owned sensor inputs, algorithm/version, and evaluated reference comparison | 3 until a validation decision; Tier 4 claims prohibited | At most "Experimental Zeez-estimated stage" after research gate | "Reported by Apple Health"; "Apple-equivalent"; "validated stage"; diagnosis | No inferred replacement of missing imported stages; remain separate from Apple data | Phase 6 go/no-go, reference-data evaluation with comparable sensors, failure analysis, device validation | Not a currently validated production capability; existing heuristic analyzer is to be quarantined or retired. |
| Recommendations or personalized insights | Qualified metrics plus separately documented evidence and language policy | 3 unless purely descriptive | "Observation: your recorded bedtime varied more this week," if calculation is defined | Advice to change treatment; causal claims; personal health conclusions | No recommendation from unavailable or sparse data; educational text must not masquerade as personal output | Written insights contract, fixture tests, copy/accessibility review; stronger advice requires separate validation | Existing recommendation system is identified as unsupported and to remain unreachable or be removed. |
| Medical / clinical conclusions | Appropriate clinical/reference evidence and validation outside ordinary product metrics | 4 | None; direct concerned users to a qualified healthcare provider without interpreting data | Diagnosis, screening, treatment, medical sleep debt, recovery/readiness, or health-risk conclusions | Never generated from Zeez sleep metrics alone | Separate clinical validation and regulatory assessment before any product decision | Out of current product scope. |

## 4. Product Language Rules

These rules apply equally to visual UI, VoiceOver text, charts and chart
legends, watch payload fields and presentation, widgets, notifications, and
external product copy:

1. Imported Apple Health sleep-stage data uses provenance wording such as
   "Reported by Apple Health." When emphasizing classification uncertainty,
   "Apple Health estimated stage" is also acceptable.
2. A Zeez calculation uses "Derived" or a precisely descriptive name. A
   not-yet-validated interpretation uses "Experimental Zeez Estimate."
3. Use "Sleep Goal Shortfall" or "Below Your Selected Goal." Do not present a
   selected-goal comparison as medical sleep debt, recovery need, or health
   impact.
4. Missing inputs make a metric unavailable. They must never become zeros,
   neutral-looking scores, default percentages, reassuring trends, or
   accessibility announcements of a personal result.
5. Preserve `asleepUnspecified` as asleep with an unspecified stage. Do not map
   it to Core, light, Deep, or REM.
6. `inBed` is context, not a sleep stage. Never include it in an asleep-stage
   numerator or stage-composition denominator.
7. Do not call session interval duration "time asleep" without qualified asleep
   evidence.
8. Awake intervals from Apple Watch must not be presented as exhaustive
   awakening detection because boundary awake samples may be absent.
9. Physiological signals may be displayed with source and units where
   available. Relationships between those signals and sleep outcomes remain
   experimental unless separately validated.
10. A score or inferred stage must never lose its experimental/provenance label
    when sent to watchOS, rendered in a chart, or described through
    accessibility output.

## 5. Validation Matrix

| Feature Category | Required Before Shipping A Descriptive Feature | Later Or Conditional Validation | Claims This Does Not Support |
| --- | --- | --- | --- |
| HealthKit value import and source provenance | Deterministic mapping/integration tests, overlap and missing-data tests, simulator build and UI/accessibility review | Real-device Apple Health import verification | That Apple data is clinically exact or Zeez validated it |
| Derived totals, percentages, goal comparisons, and timing variability | Pure unit/integration fixtures for formula, denominator, source coverage, timezone/DST, and unavailable behavior; chart/accessibility review | Device smoke check using imported data | Health, diagnosis, recovery, or causal conclusions |
| Phone-to-watch sleep summaries | Payload contract tests and phone/watch build/UI accessibility review | Paired Apple Watch payload/update verification | That watch presentation validates the underlying measurement |
| Apple Health physiological samples | Mapping, units, time-association, and missing-data tests | Real-device coverage verification for enabled signal types | Correlation, readiness, or stage-inference claims |
| Experimental Zeez score | Written specification, model/calculation version, input coverage, deterministic test vectors, explicit experimental presentation | Public-dataset exploratory work only where inputs are comparable; device study before stronger wording | Validated sleep quality, health, recovery, or treatment meaning |
| Zeez-owned inferred stages | No production activation during current roadmap phases without a Phase 6 validation decision | Paired reference-data evaluation with comparable acquired sensors, error analysis, and device validation | Apple-equivalent or PSG-equivalent staging absent separate evidence |
| Diagnostic, clinical, or treatment claims | Not permitted as part of descriptive product validation | Separate clinical study/reference validation and regulatory assessment | Any clinical claim until that work is completed |

Deterministic imported-data presentation and transparent calculations do not
require extensive user studies before release. Clinical conclusions, owned
staging-accuracy claims, recovery/readiness claims, or health interpretations
cannot responsibly be justified by engineering tests or ordinary app usage.

## 6. Source Registry

The registry below contains the primary or official sources used for this
contract. Where a desired assertion goes beyond a source, it is marked for
later confirmation rather than treated as established.

| Source Title | Organization / Authors | Link | What It Supports In Zeez | Important Limitation |
| --- | --- | --- | --- | --- |
| `HKCategoryValueSleepAnalysis` | Apple Developer Documentation | [Apple HealthKit documentation](https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis) | Values and semantics for `inBed`, `awake`, Core, Deep, REM, and `asleepUnspecified`; overlapping `inBed`/detail samples; Apple Watch boundary-awake note; examples of derivable secondary statistics | Defines data semantics, not accuracy of a particular source or a Zeez implementation |
| *Estimating Sleep Stages from Apple Watch*, updated October 2025 | Apple | [Apple validation white paper](https://www.apple.com/tr/health/pdf/Estimating_Sleep_Stages_from_Apple_Watch_Oct_2025.pdf) | Apple-published validation context for Apple Watch estimated sleep stages versus PSG and the need to preserve source attribution | Does not validate Zeez calculations, score, inference, medical interpretation, or every third-party/OS-version data path; exact performance figures must be rechecked against the applicable Apple version before public use |
| *Clinical Practice Guideline for the Pharmacologic Treatment of Chronic Insomnia in Adults* | American Academy of Sleep Medicine; Sateia et al. | [AASM guideline PDF](https://aasm.org/resources/pdf/pharmacologictreatmentofinsomnia.pdf) | Standard descriptive definitions used here for sleep latency, TST, WASO, sleep efficiency, and awakenings | Clinical insomnia treatment guideline; definitions do not make a consumer calculation diagnostic |
| *Consumer Sleep Technology: An American Academy of Sleep Medicine Position Statement* | AASM; Khosla et al. | [Journal text via PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC5940440/) | Boundary that consumer sleep technology intended to diagnose or treat requires rigorous gold-standard testing and appropriate clearance | General position statement; it does not validate any individual Zeez or Apple metric |
| *The importance of sleep regularity: a consensus statement of the National Sleep Foundation sleep timing and variability panel* | National Sleep Foundation panel; Sletten et al. | [Sleep Health article](https://doi.org/10.1016/j.sleh.2023.07.016) | Sleep regularity/timing is a legitimate descriptive domain for a schedule-consistency metric | Does not specify Zeez's aggregation formula or justify personal health claims from timing variation |
| *Sleep Deprivation and Deficiency - How Much Sleep Is Enough* | National Heart, Lung, and Blood Institute, NIH | [NHLBI guidance](https://www.nhlbi.nih.gov/health/sleep-deprivation/how-much-sleep) | Sleep need varies; sleep debt is framed as sleep lost relative to needed sleep, supporting separation from a user-selected goal | Public guidance, not validation of a Zeez goal or personalized sleep-need model |
| MESA Sleep dataset documentation | National Sleep Research Resource, NHLBI-supported | [MESA dataset](https://sleepdata.org/datasets/mesa/pages), [actigraphy documentation](https://sleepdata.org/datasets/mesa/pages/actigraphy-introduction.md), [PSG documentation](https://sleepdata.org/datasets/mesa/pages/polysomnography-introduction.md) | Candidate exploratory dataset with week-long wrist actigraphy for 2,237 recruited participants and PSG signal/annotation data for 2,056 participants | Signals are not Apple Watch HealthKit output; usable for matched exploratory questions, not direct Apple/Zeez production validation |
| Sleep Heart Health Study dataset documentation | National Sleep Research Resource, NHLBI-supported | [SHHS dataset](https://sleepdata.org/datasets/shhs/pages), [PSG documentation](https://sleepdata.org/datasets/shhs/pages/05-polysomnography-introduction.md) | Candidate PSG reference resource with staged annotation files for exploratory sleep-analysis work | Legacy cohort/conversion limitations are documented; does not pair Zeez or Apple Watch inputs |
| Sleep-EDF Database Expanded | PhysioNet; Bob Kemp | [PhysioNet dataset](https://physionet.org/content/sleep-edfx/1.0.0/) | Open PSG/hypnogram data for prototyping or checking stage-analysis research workflows | 197 recordings, manual Rechtschaffen and Kales scoring, and sensor modalities not equivalent to Zeez watch inputs |

### Assertions Requiring Source Confirmation Or Additional Evidence

- The precise Apple Watch algorithm/OS version represented by sleep samples
  available to Zeez must be established before quoting Apple validation
  performance in UI, marketing, or a validation report.
- HRV import support and every enabled physiological signal's HealthKit type,
  provenance, coverage, and units must be verified from implementation and
  official API documentation before presentation rules are finalized.
- A formula and minimum-coverage threshold for Zeez bedtime/wake-time
  consistency have not been selected by these sources; they require an
  explicit product specification and deterministic tests.
- A public dataset is not automatically suitable for a Zeez model. Suitability
  depends on whether its sensors, sampling, labels, and intended output match
  the proposed experiment.

## 7. Roadmap Integration Requirements

Every future phase in `SLEEP_REFACTORING_PLAN.md` must treat this document as
the claim and validation contract for active text, accessibility output,
payloads, charts, and analysis.

| Roadmap Phase | Required Use Of This Contract |
| --- | --- |
| Phase 1: Production Surface And Reachability Audit | Complete after claims-conformance fixes on 2026-05-26; see `SLEEP_PHASE_1_CLAIMS_CONFORMANCE_CLOSEOUT.md` for routed inventory, corrections, and verification. |
| Phase 2: One Derived Metrics Engine | Encode per-metric availability, denominator, missing-data behavior, and provenance consistent with the matrix. |
| Phase 3: Import Integrity And Data Coverage | Capture source/import identity and the coverage needed to determine which allowed metrics are available. |
| Phase 4: Longitudinal Sleep Review | Expose only supported derived duration, composition, schedule, coverage, and selected-goal comparisons; avoid unsupported conclusions. |
| Phase 5: Experimental Zeez Score | Write a score specification against this contract before implementation and keep every presentation explicitly experimental. |
| Phase 6: Owned Sensor Analysis Research | Do not activate independent inferred staging without a documented validation decision; never mingle it with Apple-reported stages. |
| Phase 7: Release Hardening | Perform final claims, accessibility, device-import, paired-watch, privacy, and external-copy review against this contract. |
