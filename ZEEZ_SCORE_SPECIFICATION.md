# Experimental Zeez Estimate — Score Specification

Status: Live specification for the Tier-3 Zeez sleep score
Version: `ZeezScore-3.0`
Adopted: 2026-07-09 (second-audit item B8)
Implements: `SLEEP_METRICS_CLAIMS_AND_VALIDATION.md`, Tier-3 row and §4 language rules

This document is the written specification the claims contract requires before a Zeez
score may be presented at all ("Written specification, versioned inputs, deterministic
test vectors"). Source of truth for the code is `Zeez/Sleep/Quality/ZeezScore.swift` and
`Zeez/Sleep/Quality/SleepQualityCalculator.swift`. **This document and that code change
together, and `ZeezScore.version` is bumped whenever inputs, weights, bands, or the
missing-input policy change.**

## 1. What the score is, and is not

The Experimental Zeez Estimate is a 0–100 number summarizing a single Zeez-recorded
sleep session against published adult sleep norms. It is a Tier-3 interpretation: its
accuracy and usefulness have **not** been independently established.

It is **not** a measure of sleep quality, recovery, readiness, or health, and it must
never be presented without the "Experimental Zeez Estimate" label — including in charts,
watch payloads, and accessibility output (claims rule 10).

## 2. Scope: which sessions get a score

A session is scored only when **all** of the following hold:

| Precondition | Enforced in |
| --- | --- |
| Session has valid ordered start/end times | `SleepAnalyzer.analyzeInContext` |
| Recorded interval ≥ 30 minutes | `SleepAnalyzer.analyzeInContext` |
| At least one movement or heart-rate sample exists | `SleepAnalyzer.analyzeInContext` |
| Stages are Zeez-inferred, not Apple-Health-reported | `SleepAnalyzer.analyzeInContext` |
| Required score components are available (§4) | `SleepQualityCalculator.calculateMetrics` |

Apple Health sessions carrying source-reported stages are **never** scored: Zeez does not
grade Apple's estimates. Sessions failing any precondition keep `qualityScore <= 1.0`,
which every UI consumer reads as "no displayable score".

## 3. Components, inputs, and weights

Weights sum to 1.0 across all five components.

| Component | Weight | Required inputs | Definition |
| --- | --- | --- | --- |
| `duration` | 0.25 | Valid ordered start/end | Recorded interval scored against adult duration bands |
| `sleepOpportunity` | 0.30 | ≥1 stage interval, ≥1 asleep interval, valid window | Summed asleep duration ÷ recording window |
| `stageDistribution` | 0.25 | ≥1 asleep interval with positive duration | Duration-weighted shares of Deep/Light/REM within total asleep time |
| `fragmentation` | 0.15 | ≥1 stage interval | Count of wake episodes occurring after sleep onset |
| `latency` | 0.05 | ≥1 stage interval, ≥1 asleep interval | Recording start → earliest asleep interval start |

### 3.1 `sleepOpportunity` is not sleep efficiency

The denominator is the **recording window**, not a reported in-bed interval. Calling this
"sleep efficiency" would violate claims rule 6, and the contract requires that an
alternative ratio carry a different name. Derived sleep efficiency — time asleep over
Apple-Health-reported time in bed — remains a separate Tier-2 metric in
`DerivedSleepMetrics`, available only when Apple Health reported `inBed` intervals.

Asleep time is the **sum of asleep intervals**. It is not `window − awake`: that older
form silently counted unlabeled gaps as sleep.

### 3.2 `stageDistribution` is duration-weighted

Shares are computed from summed interval **durations**, not from how many stage records
exist. A session with four 1-minute Deep records and one with four 30-minute Deep records
must not score identically.

`asleepUnspecified` remains in the denominator and is never redistributed into Deep,
Light, or REM (claims rule 5). A session dominated by unspecified asleep therefore scores
lower on the typed stages, rather than having stage information invented for it.

### 3.3 Scoring bands

**Duration** (hours): `7.0–9.0` → 100; `6.0–7.0` or `9.0–10.0` → 85; `5.0–6.0` or
`10.0–11.0` → 70; `4.0–5.0` or `11.0–12.0` → 50; otherwise 25.

**Sleep opportunity** (ratio): `≥0.90` → 100; `0.85–0.90` → 90; `0.80–0.85` → 80;
`0.75–0.80` → 70; `0.70–0.75` → 60; otherwise `max(20, ratio × 100)`.

**Stage distribution**: each of Deep, Light, REM is scored by its share against an optimal
and an acceptable range (Deep optimal 0.15–0.20, acceptable 0.10–0.25; Light optimal
0.45–0.55, acceptable 0.35–0.65; REM optimal 0.20–0.25, acceptable 0.15–0.30). Inside
optimal → 100; inside acceptable → linear 100 down to 70; outside → 40. The three combine
as `deep × 0.4 + rem × 0.35 + light × 0.25`.

**Fragmentation** (wake episodes after onset): `0–1` → 100; `2–3` → 85; `4–5` → 70;
`6–8` → 55; `9–12` → 40; otherwise 25.

**Latency** (minutes): `<10` → 100; `10–20` → 90; `20–30` → 75; `30–45` → 60; `45–60` → 45;
otherwise 25.

## 4. Missing-input policy

Claims rule 4: *missing inputs make a metric unavailable; they must never become zeros,
neutral-looking scores, default percentages, or reassuring trends.*

Version 3.0 replaces the previous behavior, in which absent stage data produced neutral
sub-scores of 85 / 75 / 85 / 85 and a composite that looked like a measurement.

1. **Every component is available or unavailable.** There are no default sub-scores.
2. **Required components gate the score.** `duration` and `stageDistribution` must both be
   available. If either is not, `calculateMetrics()` returns `nil` and no score is
   persisted. A composite assembled from duration alone would be a statement about the
   clock, not about sleep.
3. **Optional components shrink coverage.** `inputCoverage` is the share of total
   component weight that was available, 0–100.
4. **Coverage has a floor.** Below `ZeezScore.minimumCoverage` (60), no score is produced.
5. **The composite renormalizes.** `overallScore` is the weighted mean over available
   components only, divided by their summed weight — so an unavailable component neither
   drags the score down nor is silently treated as average.

When no score is produced, `SleepAnalyzer` writes the sentinel `qualityScore = 1.0`. The
sentinel is never displayed as a personal result; it exists so background analysis stops
retrying.

## 5. Confidence

`SleepQualityScore.confidenceScore` previously stored the constant `85.0` for every
estimate, which asserted a uniform confidence Zeez had not established.

It now stores **input-coverage confidence**:

```
confidence = inputCoverage × sensorBreadthFactor

sensorBreadthFactor = 1.00  movement and heart-rate series both present
                      0.85  exactly one series present
                      0.70  stages present but no retained raw series
```

This describes **how complete the inputs were**, never how accurate the method is. No
value of `confidenceScore` licenses stronger wording than "Experimental Zeez Estimate".

## 6. Versioning

`ZeezScore.version` (`ZeezScore-3.0`) is persisted to
`SleepQualityScore.calculationVersion` with every estimate, so stored scores remain
attributable to the specification that produced them. Earlier records carry
`SleepAnalyzer-2.0` and were produced under the neutral-default policy described in §4;
they are not comparable with 3.0 scores and must not be mixed in a trend without
disclosure.

## 7. Validation status

| Required before shipping | Status |
| --- | --- |
| Written specification | This document |
| Versioned inputs | `ZeezScore.version`, persisted per estimate |
| Deterministic test vectors | `ZeezTests/SleepQualityCalculatorTests.swift` |
| Explicit experimental presentation | `hasDisplayableScore` gating + "Experimental Zeez Estimate" labels |
| Matched dataset / device evaluation | **Not done.** Required before any wording stronger than "Experimental Zeez Estimate" |

The score has not been compared against polysomnography or any reference dataset. Per the
claims contract, engineering tests cannot establish that it measures sleep quality; only
an appropriately matched study could support stronger wording, and none has been run.
