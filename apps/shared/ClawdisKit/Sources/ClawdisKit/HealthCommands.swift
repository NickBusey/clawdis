import Foundation

public enum ClawdisHealthCommand: String, Codable, Sendable {
    case weightGet = "health.weight.get"
    case weightRecord = "health.weight.record"
    case workoutLatest = "health.workout.latest"
    case ringsGet = "health.rings.get"
    case stepsGet = "health.steps.get"
    case bloodPressureGet = "health.blood_pressure.get"
    case sleepGet = "health.sleep.get"
}

public enum ClawdisHealthWeightUnit: String, Codable, Sendable {
    case kg
    case lb
    case g
}

public enum ClawdisHealthEnergyUnit: String, Codable, Sendable {
    case kcal
}

public enum ClawdisHealthDistanceUnit: String, Codable, Sendable {
    case m
}

public struct ClawdisHealthWeightQueryParams: Codable, Sendable, Equatable {
    public var startDate: Date?
    public var endDate: Date?
    public var limit: Int?
    public var unit: ClawdisHealthWeightUnit?
    public var ascending: Bool?

    public init(
        startDate: Date? = nil,
        endDate: Date? = nil,
        limit: Int? = nil,
        unit: ClawdisHealthWeightUnit? = nil,
        ascending: Bool? = nil)
    {
        self.startDate = startDate
        self.endDate = endDate
        self.limit = limit
        self.unit = unit
        self.ascending = ascending
    }
}

public struct ClawdisHealthWeightRecordParams: Codable, Sendable, Equatable {
    public var value: Double
    public var unit: ClawdisHealthWeightUnit?
    public var date: Date?

    public init(
        value: Double,
        unit: ClawdisHealthWeightUnit? = nil,
        date: Date? = nil)
    {
        self.value = value
        self.unit = unit
        self.date = date
    }
}

public struct ClawdisHealthWeightSample: Codable, Sendable, Equatable {
    public var value: Double
    public var unit: ClawdisHealthWeightUnit
    public var date: Date
    public var sourceBundleId: String?

    public init(
        value: Double,
        unit: ClawdisHealthWeightUnit,
        date: Date,
        sourceBundleId: String? = nil)
    {
        self.value = value
        self.unit = unit
        self.date = date
        self.sourceBundleId = sourceBundleId
    }
}

public struct ClawdisHealthWeightQueryResponse: Codable, Sendable, Equatable {
    public var samples: [ClawdisHealthWeightSample]

    public init(samples: [ClawdisHealthWeightSample]) {
        self.samples = samples
    }
}

public struct ClawdisHealthWeightRecordResponse: Codable, Sendable, Equatable {
    public var sample: ClawdisHealthWeightSample

    public init(sample: ClawdisHealthWeightSample) {
        self.sample = sample
    }
}

public struct ClawdisHealthWorkoutSample: Codable, Sendable, Equatable {
    public var activityType: Int
    public var activityName: String?
    public var startDate: Date
    public var endDate: Date
    public var durationSeconds: Double
    public var totalEnergy: Double?
    public var totalEnergyUnit: ClawdisHealthEnergyUnit?
    public var totalDistance: Double?
    public var totalDistanceUnit: ClawdisHealthDistanceUnit?

    public init(
        activityType: Int,
        activityName: String? = nil,
        startDate: Date,
        endDate: Date,
        durationSeconds: Double,
        totalEnergy: Double? = nil,
        totalEnergyUnit: ClawdisHealthEnergyUnit? = nil,
        totalDistance: Double? = nil,
        totalDistanceUnit: ClawdisHealthDistanceUnit? = nil)
    {
        self.activityType = activityType
        self.activityName = activityName
        self.startDate = startDate
        self.endDate = endDate
        self.durationSeconds = durationSeconds
        self.totalEnergy = totalEnergy
        self.totalEnergyUnit = totalEnergyUnit
        self.totalDistance = totalDistance
        self.totalDistanceUnit = totalDistanceUnit
    }
}

public struct ClawdisHealthWorkoutLatestResponse: Codable, Sendable, Equatable {
    public var sample: ClawdisHealthWorkoutSample?

    public init(sample: ClawdisHealthWorkoutSample?) {
        self.sample = sample
    }
}

public struct ClawdisHealthActivityRings: Codable, Sendable, Equatable {
    public var date: Date
    public var move: Double
    public var moveGoal: Double
    public var exerciseMinutes: Double
    public var exerciseGoalMinutes: Double
    public var standHours: Double
    public var standGoalHours: Double
    public var moveUnit: ClawdisHealthEnergyUnit

    public init(
        date: Date,
        move: Double,
        moveGoal: Double,
        exerciseMinutes: Double,
        exerciseGoalMinutes: Double,
        standHours: Double,
        standGoalHours: Double,
        moveUnit: ClawdisHealthEnergyUnit = .kcal)
    {
        self.date = date
        self.move = move
        self.moveGoal = moveGoal
        self.exerciseMinutes = exerciseMinutes
        self.exerciseGoalMinutes = exerciseGoalMinutes
        self.standHours = standHours
        self.standGoalHours = standGoalHours
        self.moveUnit = moveUnit
    }
}

public struct ClawdisHealthActivityRingsResponse: Codable, Sendable, Equatable {
    public var rings: ClawdisHealthActivityRings?

    public init(rings: ClawdisHealthActivityRings?) {
        self.rings = rings
    }
}

public struct ClawdisHealthStepsSummary: Codable, Sendable, Equatable {
    public var startDate: Date
    public var endDate: Date
    public var steps: Double

    public init(startDate: Date, endDate: Date, steps: Double) {
        self.startDate = startDate
        self.endDate = endDate
        self.steps = steps
    }
}

public struct ClawdisHealthStepsResponse: Codable, Sendable, Equatable {
    public var summary: ClawdisHealthStepsSummary

    public init(summary: ClawdisHealthStepsSummary) {
        self.summary = summary
    }
}

public struct ClawdisHealthBloodPressureSample: Codable, Sendable, Equatable {
    public var systolic: Double
    public var diastolic: Double
    public var unit: String
    public var date: Date
    public var sourceBundleId: String?

    public init(
        systolic: Double,
        diastolic: Double,
        unit: String = "mmHg",
        date: Date,
        sourceBundleId: String? = nil)
    {
        self.systolic = systolic
        self.diastolic = diastolic
        self.unit = unit
        self.date = date
        self.sourceBundleId = sourceBundleId
    }
}

public struct ClawdisHealthBloodPressureResponse: Codable, Sendable, Equatable {
    public var sample: ClawdisHealthBloodPressureSample?

    public init(sample: ClawdisHealthBloodPressureSample?) {
        self.sample = sample
    }
}

public struct ClawdisHealthSleepSample: Codable, Sendable, Equatable {
    public var startDate: Date
    public var endDate: Date
    public var value: Int
    public var valueName: String?
    public var sourceBundleId: String?

    public init(
        startDate: Date,
        endDate: Date,
        value: Int,
        valueName: String? = nil,
        sourceBundleId: String? = nil)
    {
        self.startDate = startDate
        self.endDate = endDate
        self.value = value
        self.valueName = valueName
        self.sourceBundleId = sourceBundleId
    }
}

public struct ClawdisHealthSleepQueryParams: Codable, Sendable, Equatable {
    public var limit: Int?

    public init(limit: Int? = nil) {
        self.limit = limit
    }
}

public struct ClawdisHealthSleepResponse: Codable, Sendable, Equatable {
    public var samples: [ClawdisHealthSleepSample]

    public init(samples: [ClawdisHealthSleepSample]) {
        self.samples = samples
    }
}
