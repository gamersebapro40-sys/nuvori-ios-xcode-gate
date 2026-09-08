import Foundation
import HealthKit

/// Production HealthKit read bridge for NUVORI. All permissions are user-controlled.
/// The bridge only normalizes source data; nutrition/adaptive decisions stay in the NUVORI Brain.
@MainActor
final class NUVORIHealthKitBridge: ObservableObject {
    private let store = HKHealthStore()
    @Published private(set) var authorized = false
    @Published private(set) var lastSync: Date?

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        var x = Set<HKObjectType>()
        [HKQuantityTypeIdentifier.stepCount,
         .activeEnergyBurned,
         .bodyMass,
         .heartRate,
         .restingHeartRate,
         .distanceWalkingRunning].forEach { id in
            if let t = HKObjectType.quantityType(forIdentifier: id) { x.insert(t) }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { x.insert(sleep) }
        x.insert(HKObjectType.workoutType())
        return x
    }

    func requestAuthorization() async throws {
        guard Self.isAvailable else { throw HealthError.unavailable }
        try await store.requestAuthorization(toShare: [], read: readTypes)
        authorized = true
    }

    func importRecent(days: Int = 30) async throws -> [HealthEvent] {
        guard Self.isAvailable else { throw HealthError.unavailable }
        let end = Date(), start = Calendar.current.date(byAdding: .day, value: -max(1, days), to: end)!
        async let steps = quantityEvents(.stepCount, unit: .count(), start: start, end: end, kind: "steps")
        async let energy = quantityEvents(.activeEnergyBurned, unit: .kilocalorie(), start: start, end: end, kind: "active_energy_kcal")
        async let weight = quantityEvents(.bodyMass, unit: .gramUnit(with: .kilo), start: start, end: end, kind: "weight_kg")
        async let heart = quantityEvents(.heartRate, unit: HKUnit.count().unitDivided(by: .minute()), start: start, end: end, kind: "heart_rate_bpm")
        async let restingHeart = quantityEvents(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), start: start, end: end, kind: "resting_heart_rate")
        async let distance = quantityEvents(.distanceWalkingRunning, unit: .meter(), start: start, end: end, kind: "distance_m")
        async let sleep = sleepEvents(start: start, end: end)
        async let workouts = workoutEvents(start: start, end: end)
        let out = try await steps + energy + weight + heart + restingHeart + distance + sleep + workouts
        lastSync = Date()
        return out.sorted { $0.start < $1.start }
    }

    private func quantityEvents(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date, kind: String) async throws -> [HealthEvent] {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, values, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: (values as? [HKQuantitySample]) ?? [])
            }
            store.execute(q)
        }
        return samples.map { HealthEvent(id: $0.uuid.uuidString, kind: kind, value: $0.quantity.doubleValue(for: unit), unit: unit.unitString, start: $0.startDate, end: $0.endDate, source: $0.sourceRevision.source.name) }
    }

    private func sleepEvents(start: Date, end: Date) async throws -> [HealthEvent] {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, values, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: (values as? [HKCategorySample]) ?? [])
            }
            store.execute(q)
        }
        return samples.map { s in HealthEvent(id: s.uuid.uuidString, kind: "sleep", value: s.endDate.timeIntervalSince(s.startDate) / 60.0, unit: "min", start: s.startDate, end: s.endDate, source: s.sourceRevision.source.name, metadata: ["stage": String(s.value)]) }
    }

    private func workoutEvents(start: Date, end: Date) async throws -> [HealthEvent] {
        let type = HKObjectType.workoutType(), predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let samples: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, values, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: (values as? [HKWorkout]) ?? [])
            }
            store.execute(q)
        }
        return samples.map { w in HealthEvent(id: w.uuid.uuidString, kind: "workout", value: w.duration / 60.0, unit: "min", start: w.startDate, end: w.endDate, source: w.sourceRevision.source.name, metadata: ["activityTypeRaw": String(w.workoutActivityType.rawValue)], activityType: activityName(w.workoutActivityType), distanceMeters: w.totalDistance?.doubleValue(for: .meter()), activeEnergy: w.totalEnergyBurned?.doubleValue(for: .kilocalorie())) }
    }

    private func activityName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Strength Training"
        case .yoga: return "Yoga"
        default: return "Workout"
        }
    }

    enum HealthError: Error { case unavailable }
}

struct HealthEvent: Codable, Identifiable {
    let id: String
    let kind: String
    let value: Double
    let unit: String
    let start: Date
    let end: Date
    let source: String
    var metadata: [String:String] = [:]
    var activityType: String? = nil
    var distanceMeters: Double? = nil
    var activeEnergy: Double? = nil
}
