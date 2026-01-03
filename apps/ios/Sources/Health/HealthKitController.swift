import ClawdisKit
import Foundation
import HealthKit

enum HealthKitControllerError: LocalizedError {
    case unavailable
    case unsupported
    case authorizationRequired
    case permissionDenied
    case invalidValue

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "HEALTH_UNAVAILABLE: Health data is not available on this device"
        case .unsupported:
            "HEALTH_UNAVAILABLE: Weight data type is not available"
        case .authorizationRequired:
            "HEALTH_AUTH_REQUIRED: open Clawdis to grant Health access"
        case .permissionDenied:
            "HEALTH_PERMISSION_DENIED: enable Health access in Settings > Health > Data Access & Devices"
        case .invalidValue:
            "INVALID_REQUEST: weight value must be greater than 0"
        }
    }
}

actor HealthKitController {
    nonisolated static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private let store = HKHealthStore()

    private var weightType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .bodyMass)
    }

    private var stepsType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .stepCount)
    }

    private var systolicType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)
    }

    private var diastolicType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)
    }

    private var bloodPressureType: HKCorrelationType? {
        HKCorrelationType.correlationType(forIdentifier: .bloodPressure)
    }

    private var sleepType: HKCategoryType? {
        HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)
    }

    func fetchWeights(
        params: ClawdisHealthWeightQueryParams,
        allowPrompt: Bool) async throws -> [ClawdisHealthWeightSample]
    {
        try self.ensureAvailable()
        guard let weightType else { throw HealthKitControllerError.unsupported }

        try await self.ensureReadAuthorization(
            readTypes: [weightType],
            allowPrompt: allowPrompt)

        let limit = max(1, params.limit ?? 1)
        let predicate = Self.samplePredicate(startDate: params.startDate, endDate: params.endDate)
        let ascending = params.ascending ?? false
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: ascending)
        let unit = params.unit ?? .kg

        return try await withCheckedThrowingContinuation { cont in
            let query = HKSampleQuery(
                sampleType: weightType,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sort])
            { _, samples, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                let mapped = (samples ?? []).compactMap { sample -> ClawdisHealthWeightSample? in
                    guard let quantity = sample as? HKQuantitySample else { return nil }
                    return Self.sample(from: quantity, unit: unit)
                }
                cont.resume(returning: mapped)
            }
            self.store.execute(query)
        }
    }

    func recordWeight(
        params: ClawdisHealthWeightRecordParams,
        allowPrompt: Bool) async throws -> ClawdisHealthWeightSample
    {
        try self.ensureAvailable()
        guard let weightType else { throw HealthKitControllerError.unsupported }

        let value = params.value
        guard value > 0 else { throw HealthKitControllerError.invalidValue }

        try await self.ensureWriteAuthorization(weightType: weightType, allowPrompt: allowPrompt)

        let unit = params.unit ?? .kg
        let date = params.date ?? Date()
        let quantity = HKQuantity(unit: unit.hkUnit, doubleValue: value)
        let sample = HKQuantitySample(type: weightType, quantity: quantity, start: date, end: date)

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.store.save(sample) { _, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                cont.resume(returning: ())
            }
        }

        return Self.sample(from: sample, unit: unit)
    }

    func fetchLatestWorkout(allowPrompt: Bool) async throws -> ClawdisHealthWorkoutSample? {
        try self.ensureAvailable()
        let workoutType = HKObjectType.workoutType()

        try await self.ensureReadAuthorization(
            readTypes: [workoutType],
            allowPrompt: allowPrompt)

        return try await withCheckedThrowingContinuation { cont in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)])
            { _, samples, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                guard let workout = (samples?.first as? HKWorkout) else {
                    cont.resume(returning: nil)
                    return
                }
                cont.resume(returning: Self.workoutSample(from: workout))
            }
            self.store.execute(query)
        }
    }

    func fetchActivityRings(allowPrompt: Bool) async throws -> ClawdisHealthActivityRings? {
        try self.ensureAvailable()
        let summaryType = HKObjectType.activitySummaryType()

        try await self.ensureReadAuthorization(
            readTypes: [summaryType],
            allowPrompt: allowPrompt)

        let calendar = Calendar.current
        let now = Date()
        let comps = calendar.dateComponents([.year, .month, .day], from: now)
        let predicate = HKQuery.predicateForActivitySummary(with: comps)

        return try await withCheckedThrowingContinuation { cont in
            let query = HKActivitySummaryQuery(predicate: predicate) { _, summaries, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                guard let summary = summaries?.first else {
                    cont.resume(returning: nil)
                    return
                }
                let move = summary.activeEnergyBurned.doubleValue(for: .kilocalorie())
                let moveGoal = summary.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie())
                let exercise = summary.appleExerciseTime.doubleValue(for: .minute())
                let exerciseGoal = summary.appleExerciseTimeGoal.doubleValue(for: .minute())
                let stand = summary.appleStandHours.doubleValue(for: .count())
                let standGoal = summary.appleStandHoursGoal.doubleValue(for: .count())
                let date = calendar.date(from: summary.dateComponents(for: calendar)) ?? now
                let rings = ClawdisHealthActivityRings(
                    date: date,
                    move: move,
                    moveGoal: moveGoal,
                    exerciseMinutes: exercise,
                    exerciseGoalMinutes: exerciseGoal,
                    standHours: stand,
                    standGoalHours: standGoal)
                cont.resume(returning: rings)
            }
            self.store.execute(query)
        }
    }

    func fetchStepsSummary(allowPrompt: Bool) async throws -> ClawdisHealthStepsSummary {
        try self.ensureAvailable()
        guard let stepsType else { throw HealthKitControllerError.unsupported }

        try await self.ensureReadAuthorization(
            readTypes: [stepsType],
            allowPrompt: allowPrompt)

        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.startOfDay(for: endDate)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])

        return try await withCheckedThrowingContinuation { cont in
            let query = HKStatisticsQuery(
                quantityType: stepsType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum)
            { _, stats, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                let steps = stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                cont.resume(returning: ClawdisHealthStepsSummary(
                    startDate: startDate,
                    endDate: endDate,
                    steps: steps))
            }
            self.store.execute(query)
        }
    }

    func fetchLatestBloodPressure(allowPrompt: Bool) async throws -> ClawdisHealthBloodPressureSample? {
        try self.ensureAvailable()
        guard let bloodPressureType else { throw HealthKitControllerError.unsupported }
        guard let systolicType, let diastolicType else {
            throw HealthKitControllerError.unsupported
        }

        try await self.ensureReadAuthorization(
            readTypes: [systolicType, diastolicType],
            allowPrompt: allowPrompt)

        return try await withCheckedThrowingContinuation { cont in
            let query = HKSampleQuery(
                sampleType: bloodPressureType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)])
            { _, samples, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                guard let correlation = samples?.first as? HKCorrelation else {
                    cont.resume(returning: nil)
                    return
                }
                guard
                    let systolicSample = correlation
                        .objects(for: systolicType)
                        .first as? HKQuantitySample,
                        let diastolicSample = correlation
                            .objects(for: diastolicType)
                            .first as? HKQuantitySample
                else {
                    cont.resume(returning: nil)
                    return
                }
                let systolic = systolicSample.quantity.doubleValue(for: .millimeterOfMercury())
                let diastolic = diastolicSample.quantity.doubleValue(for: .millimeterOfMercury())
                let sourceBundleId = correlation.sourceRevision.source.bundleIdentifier
                cont.resume(returning: ClawdisHealthBloodPressureSample(
                    systolic: systolic,
                    diastolic: diastolic,
                    date: correlation.endDate,
                    sourceBundleId: sourceBundleId))
            }
            self.store.execute(query)
        }
    }

    func fetchSleepSamples(limit: Int, allowPrompt: Bool) async throws -> [ClawdisHealthSleepSample] {
        try self.ensureAvailable()
        guard let sleepType else { throw HealthKitControllerError.unsupported }

        try await self.ensureReadAuthorization(
            readTypes: [sleepType],
            allowPrompt: allowPrompt)

        let maxLimit = max(1, min(limit, 50))
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { cont in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: nil,
                limit: maxLimit,
                sortDescriptors: [sort])
            { _, samples, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                let mapped = (samples ?? []).compactMap { sample -> ClawdisHealthSleepSample? in
                    guard let sleepSample = sample as? HKCategorySample else { return nil }
                    let valueName = Self.sleepValueName(sleepSample.value)
                    let sourceBundleId = sleepSample.sourceRevision.source.bundleIdentifier
                    return ClawdisHealthSleepSample(
                        startDate: sleepSample.startDate,
                        endDate: sleepSample.endDate,
                        value: sleepSample.value,
                        valueName: valueName,
                        sourceBundleId: sourceBundleId)
                }
                cont.resume(returning: mapped)
            }
            self.store.execute(query)
        }
    }

    func requestWeightAuthorization(allowPrompt: Bool) async throws {
        try await self.requestHealthAuthorization(allowPrompt: allowPrompt)
    }

    func requestHealthAuthorization(allowPrompt: Bool) async throws {
        try self.ensureAvailable()
        guard let weightType else { throw HealthKitControllerError.unsupported }

        let readTypes = Set([
            weightType,
            HKObjectType.workoutType(),
            HKObjectType.activitySummaryType(),
            self.stepsType,
            self.systolicType,
            self.diastolicType,
            self.sleepType,
        ].compactMap(\.self))

        let shareTypes: Set<HKSampleType> = [weightType]

        let status = try await self.requestStatus(toShare: shareTypes, read: readTypes)
        if status == .shouldRequest {
            guard allowPrompt else { throw HealthKitControllerError.authorizationRequired }
            _ = try await self.requestAuthorization(toShare: shareTypes, read: readTypes)
        }
    }

    private func ensureAvailable() throws {
        guard Self.isAvailable else { throw HealthKitControllerError.unavailable }
    }

    private func ensureReadAuthorization(readTypes: Set<HKObjectType>, allowPrompt: Bool) async throws {
        let status = try await self.requestStatus(toShare: [], read: readTypes)
        if status == .shouldRequest {
            guard allowPrompt else { throw HealthKitControllerError.authorizationRequired }
            _ = try await self.requestAuthorization(toShare: [], read: readTypes)
        }
    }

    private func ensureWriteAuthorization(weightType: HKQuantityType, allowPrompt: Bool) async throws {
        let status = try await self.requestStatus(toShare: [weightType], read: [weightType])
        if status == .shouldRequest {
            guard allowPrompt else { throw HealthKitControllerError.authorizationRequired }
            _ = try await self.requestAuthorization(toShare: [weightType], read: [weightType])
        }
        if self.store.authorizationStatus(for: weightType) == .sharingDenied {
            throw HealthKitControllerError.permissionDenied
        }
    }

    private func requestStatus(
        toShare: Set<HKSampleType>,
        read: Set<HKObjectType>) async throws -> HKAuthorizationRequestStatus
    {
        try await withCheckedThrowingContinuation { cont in
            self.store.getRequestStatusForAuthorization(toShare: toShare, read: read) { status, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                cont.resume(returning: status)
            }
        }
    }

    private func requestAuthorization(
        toShare: Set<HKSampleType>,
        read: Set<HKObjectType>) async throws -> Bool
    {
        try await withCheckedThrowingContinuation { cont in
            self.store.requestAuthorization(toShare: toShare, read: read) { success, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                cont.resume(returning: success)
            }
        }
    }

    private static func workoutSample(from workout: HKWorkout) -> ClawdisHealthWorkoutSample {
        let activityType = workout.workoutActivityType
        let energy = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
        let distance = workout.totalDistance?.doubleValue(for: .meter())
        return ClawdisHealthWorkoutSample(
            activityType: Int(activityType.rawValue),
            activityName: Self.workoutActivityName(activityType),
            startDate: workout.startDate,
            endDate: workout.endDate,
            durationSeconds: workout.duration,
            totalEnergy: energy,
            totalEnergyUnit: energy == nil ? nil : .kcal,
            totalDistance: distance,
            totalDistanceUnit: distance == nil ? nil : .m)
    }

    private static func workoutActivityName(_ type: HKWorkoutActivityType) -> String? {
        switch type {
        case .running:
            "running"
        case .walking:
            "walking"
        case .cycling:
            "cycling"
        case .swimming:
            "swimming"
        case .yoga:
            "yoga"
        case .traditionalStrengthTraining:
            "strengthTraining"
        case .functionalStrengthTraining:
            "functionalStrengthTraining"
        case .highIntensityIntervalTraining:
            "hiit"
        case .rowing:
            "rowing"
        case .hiking:
            "hiking"
        case .elliptical:
            "elliptical"
        case .stairClimbing:
            "stairClimbing"
        case .coreTraining:
            "coreTraining"
        case .pilates:
            "pilates"
        case .mindAndBody:
            "mindAndBody"
        case .other:
            "other"
        default:
            nil
        }
    }

    private static func samplePredicate(startDate: Date?, endDate: Date?) -> NSPredicate? {
        if startDate == nil, endDate == nil { return nil }
        return HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
    }

    private static func sleepValueName(_ value: Int) -> String? {
        switch value {
        case HKCategoryValueSleepAnalysis.inBed.rawValue:
            "inBed"
        case HKCategoryValueSleepAnalysis.asleep.rawValue:
            "asleep"
        case HKCategoryValueSleepAnalysis.awake.rawValue:
            "awake"
        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
            "asleepUnspecified"
        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
            "asleepCore"
        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
            "asleepDeep"
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
            "asleepREM"
        default:
            nil
        }
    }

    private static func sample(
        from sample: HKQuantitySample,
        unit: ClawdisHealthWeightUnit) -> ClawdisHealthWeightSample
    {
        let value = sample.quantity.doubleValue(for: unit.hkUnit)
        let sourceBundleId = sample.sourceRevision.source.bundleIdentifier
        return ClawdisHealthWeightSample(
            value: value,
            unit: unit,
            date: sample.endDate,
            sourceBundleId: sourceBundleId)
    }
}

extension ClawdisHealthWeightUnit {
    fileprivate var hkUnit: HKUnit {
        switch self {
        case .kg:
            HKUnit.gramUnit(with: .kilo)
        case .lb:
            HKUnit.pound()
        case .g:
            HKUnit.gram()
        }
    }
}
