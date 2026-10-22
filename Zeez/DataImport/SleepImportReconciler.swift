import CoreData
import Foundation
import os.log

/// A stored HealthKit night whose heart-rate and respiratory samples must be fetched for
/// its current range. Only plain values and the saved object ID cross context queues.
struct ImportedSessionRange: Equatable {
    let sessionID: NSManagedObjectID
    let start: Date
    let end: Date
}

/// What one HealthKit import changed in the store.
struct SleepImportReconciliation: Equatable {
    /// Nights that were not stored before.
    var inserted: [ImportedSessionRange] = []
    /// Stored nights that gained or lost samples, changed range, or absorbed a duplicate.
    var updated: [ImportedSessionRange] = []
    /// Stored nights removed because HealthKit reported every one of their samples deleted.
    var removedCount = 0
}

/// Reconciles fetched Apple Health sleep samples with the HealthKit nights already stored
/// (PARKED_CAPABILITIES §8a). Replaces the old rule — skip any night whose start is within
/// 15 minutes of an existing import — which dropped every later change to a night and
/// duplicated a night whose start moved further than that.
///
/// The policy:
/// - **A night** is every stored HealthKit session and fetched sample chained within
///   `sleepSessionGapThreshold` of each other — the rule `groupIntervalsIntoSessions` applies
///   to a first import, so a re-import arrives at the nights a fresh import would.
/// - **Samples are identified by `HKObject.uuid`.** One already stored is left alone; a new
///   one is added.
/// - **Absence is not deletion.** A stored sample HealthKit did not return is kept: HealthKit
///   returns an empty result, not an error, when read access is revoked, and an import window
///   can cut a night short.
/// - **Deletion is explicit.** A stage is removed when HealthKit reports its sample deleted
///   (`deletedSampleUUIDs`, from an anchored query), wherever the night falls; a night left
///   with no stages is removed. An edit in the Health app arrives as a deletion plus a new
///   sample, so it replaces the stage.
/// - **Pre-v3 stages** have no uuid. One is replaced by the identified copy of the same sample
///   (same stage type, start and end) when HealthKit returns it, and kept otherwise.
/// - **Duplicates fold into the oldest session.** When several stored sessions belong to one
///   night, the one created first keeps its `id` and absorbs the others' stages and notes.
/// - **Sources are not ranked.** A night holds every source's samples, each stage records its
///   source, and derived metrics follow the claims contract's union definition.
/// - Only sessions with HealthKit provenance are considered; a Zeez-recorded session is never
///   merged with an imported one.
///
/// Must run on `context`'s queue. Saves once, so a failure leaves the store as it was.
func reconcileImportedSleepSessions(
    _ fetchedSamples: [ImportedSleepSample],
    deletedSampleUUIDs: Set<UUID> = [],
    in context: NSManagedObjectContext
) throws -> SleepImportReconciliation {
    guard let coordinator = context.persistentStoreCoordinator, !coordinator.persistentStores.isEmpty else {
        ZeezLogger.error(ZeezLogger.error, "Core Data context has no persistent stores")
        return SleepImportReconciliation()
    }

    var changed: [SleepSession] = []
    var touched: [SleepSession] = []

    if !deletedSampleUUIDs.isEmpty {
        let request: NSFetchRequest<SleepStage> = SleepStage.fetchRequest()
        request.predicate = NSPredicate(
            format: "healthKitSampleUUID IN %@ AND session.deviceIdentifier == %@",
            Array(deletedSampleUUIDs), AppConstants.DataProvenance.healthKitImport
        )
        for stage in try context.fetch(request) {
            if let session = stage.session, !touched.contains(where: { $0 === session }) {
                touched.append(session)
            }
            remove(stage, in: context)
        }
        // A session emptied here keeps its old range for now, so a replacement sample fetched
        // in this same import (an edit in the Health app) refills it instead of starting a
        // new session with a new id. Only sessions still empty after merging are removed.
        for session in touched {
            updateBounds(of: session)
            session.modifiedAt = Date()
            changed.append(session)
        }
    }

    // HealthKit should never return a sample it also reports deleted; if a race makes it, the
    // deletion is the newer fact.
    let samples = fetchedSamples.filter { !deletedSampleUUIDs.contains($0.uuid) }
    let gap = sleepSessionGapThreshold
    let groups = groupIntervalsIntoSessions(samples, gapThreshold: gap)

    var stored: [SleepSession] = []
    if let earliest = samples.map(\.start).min(), let latest = samples.map(\.end).max() {
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        request.predicate = NSPredicate(
            format: "deviceIdentifier == %@ AND startTime <= %@ AND endTime >= %@",
            AppConstants.DataProvenance.healthKitImport,
            latest.addingTimeInterval(gap) as NSDate,
            earliest.addingTimeInterval(-gap) as NSDate
        )
        stored = try context.fetch(request)
    }
    var created: [SleepSession] = []

    for group in groups {
        guard let groupStart = group.map(\.start).min(),
              let groupEnd = group.map(\.end).max() else { continue }

        // Every stored session chained to this group, widening the span as each joins.
        var span = (start: groupStart, end: groupEnd)
        var night: [SleepSession] = []
        var joined = true
        while joined {
            joined = false
            for session in stored where !night.contains(where: { $0 === session }) {
                guard let start = session.startTime, let end = session.endTime,
                      start <= span.end.addingTimeInterval(gap),
                      end >= span.start.addingTimeInterval(-gap) else { continue }
                night.append(session)
                span = (min(span.start, start), max(span.end, end))
                joined = true
            }
        }

        guard let survivor = night.min(by: { oldestFirst($0, $1) }) else {
            let session = makeHealthKitSession(in: context)
            group.forEach { addStage(for: $0, to: session, in: context) }
            updateBounds(of: session)
            stored.append(session)
            created.append(session)
            continue
        }

        var didChange = false

        for other in night where other !== survivor {
            for stage in stages(of: other) { stage.session = survivor }
            for note in other.notes as? Set<SleepNote> ?? [] { note.session = survivor }
            stored.removeAll { $0 === other }
            created.removeAll { $0 === other }
            changed.removeAll { $0 === other }
            context.delete(other)
            didChange = true
        }

        // A sample can arrive twice when the folded sessions both held it.
        var seen = Set<UUID>()
        for stage in stages(of: survivor) {
            guard let uuid = stage.healthKitSampleUUID, !seen.insert(uuid).inserted else { continue }
            remove(stage, in: context)
            didChange = true
        }

        let fetchedKeys = Set(group.map(LegacyStageKey.init))
        for stage in stages(of: survivor) where stage.healthKitSampleUUID == nil {
            guard let key = LegacyStageKey(stage), fetchedKeys.contains(key) else { continue }
            remove(stage, in: context)
            didChange = true
        }

        let storedUUIDs = Set(stages(of: survivor).compactMap(\.healthKitSampleUUID))
        for sample in group where !storedUUIDs.contains(sample.uuid) {
            addStage(for: sample, to: survivor, in: context)
            didChange = true
        }

        if updateBounds(of: survivor) { didChange = true }

        if didChange {
            survivor.modifiedAt = Date()
            if !created.contains(where: { $0 === survivor }) && !changed.contains(where: { $0 === survivor }) {
                changed.append(survivor)
            }
        }
    }

    var removedCount = 0
    for session in touched where !session.isDeleted && stages(of: session).isEmpty {
        changed.removeAll { $0 === session }
        context.delete(session)
        removedCount += 1
    }

    if context.hasChanges {
        try context.save()
    }
    ZeezLogger.info(ZeezLogger.coreData, "HealthKit import: \(groups.count) night(s) fetched, \(created.count) new, \(changed.count) updated, \(removedCount) removed")

    // Object IDs are permanent once saved, so they can be resolved by related-data contexts.
    return SleepImportReconciliation(
        inserted: created.compactMap(ImportedSessionRange.init),
        updated: changed.compactMap(ImportedSessionRange.init),
        removedCount: removedCount
    )
}

/// Two nights further apart than this are separate sessions — on a first import and on every
/// re-import alike.
let sleepSessionGapThreshold: TimeInterval = 4 * 3600

// MARK: - Helpers

private extension ImportedSessionRange {
    init?(_ session: SleepSession) {
        guard let start = session.startTime, let end = session.endTime else { return nil }
        self.init(sessionID: session.objectID, start: start, end: end)
    }
}

/// What a pre-v3 stage and the sample it copied have in common.
private struct LegacyStageKey: Hashable {
    let stageType: String
    let start: Date
    let end: Date

    init(_ sample: ImportedSleepSample) {
        stageType = healthKitSleepStageType(for: sample.value)
        start = sample.start
        end = sample.end
    }

    init?(_ stage: SleepStage) {
        guard let stageType = stage.stageType, let start = stage.startTime, let end = stage.endTime else {
            return nil
        }
        self.stageType = stageType
        self.start = start
        self.end = end
    }
}

private func oldestFirst(_ lhs: SleepSession, _ rhs: SleepSession) -> Bool {
    (lhs.createdAt ?? .distantFuture, lhs.startTime ?? .distantFuture)
        < (rhs.createdAt ?? .distantFuture, rhs.startTime ?? .distantFuture)
}

private func stages(of session: SleepSession) -> [SleepStage] {
    (session.sleepStages as? Set<SleepStage> ?? []).filter { !$0.isDeleted }
}

private func remove(_ stage: SleepStage, in context: NSManagedObjectContext) {
    stage.session = nil
    context.delete(stage)
}

private func makeHealthKitSession(in context: NSManagedObjectContext) -> SleepSession {
    let session = SleepSession(context: context)
    session.id = UUID()
    session.isActive = false
    session.createdAt = Date()
    session.modifiedAt = Date()
    session.deviceIdentifier = AppConstants.DataProvenance.healthKitImport
    // Source-reported stages only; qualityScore stays unavailable until an independent
    // scoring source writes a displayable score.
    return session
}

private func addStage(for sample: ImportedSleepSample, to session: SleepSession, in context: NSManagedObjectContext) {
    let stage = SleepStage(context: context)
    stage.id = UUID()
    stage.startTime = sample.start
    stage.endTime = sample.end
    stage.duration = sample.end.timeIntervalSince(sample.start)
    stage.confidence = 85.0
    stage.healthKitSampleUUID = sample.uuid
    stage.sourceBundleIdentifier = sample.sourceBundleIdentifier
    stage.stageType = healthKitSleepStageType(for: sample.value)
    if stage.stageType == "unknown" {
        ZeezLogger.debug(ZeezLogger.coreData, "Unknown HealthKit sleep value: \(sample.value)")
    }
    stage.session = session
}

/// Set the session's range to span its stages. Returns whether it moved.
@discardableResult
private func updateBounds(of session: SleepSession) -> Bool {
    let current = stages(of: session)
    guard let start = current.compactMap(\.startTime).min(),
          let end = current.compactMap(\.endTime).max(),
          start != session.startTime || end != session.endTime else { return false }
    session.startTime = start
    session.endTime = end
    return true
}
