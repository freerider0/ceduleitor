import Foundation
import ARKit
import Combine
import simd

public struct SimpleMeasurement: Identifiable {
    public let id = UUID()
    public var startPoint: simd_float3?
    public var endPoint: simd_float3?
    public var startAnchor: ARAnchor?
    public var endAnchor: ARAnchor?
    public let timestamp: Date = Date()
    
    var distance: Float? {
        guard let start = startPoint, let end = endPoint else { return nil }
        return simd_distance(start, end)
    }
    
    var distanceText: String {
        guard let distance = distance else { return "Measuring..." }
        if distance < 1.0 {
            return String(format: "%.1f cm", distance * 100)
        } else {
            return String(format: "%.2f m", distance)
        }
    }
}

final class ARMeasurementService: ObservableObject {
    @Published var measurements: [SimpleMeasurement] = []
    @Published var currentMeasurement: SimpleMeasurement?
    @Published var isPlacingPoint = false
    
    private var measurementMode: MeasurementMode = .idle
    
    enum MeasurementMode {
        case idle
        case placingStart
        case placingEnd
    }
    
    func startNewMeasurement() {
        currentMeasurement = SimpleMeasurement()
        measurementMode = .placingStart
        isPlacingPoint = true
    }
    
    // These methods are no longer used with RealityKit
    // Keeping them for backward compatibility if needed
    
    func cancelCurrentMeasurement() {
        currentMeasurement = nil
        measurementMode = .idle
        isPlacingPoint = false
    }
    
    func clearAllMeasurements() {
        measurements.removeAll()
        cancelCurrentMeasurement()
    }
    
    func deleteMeasurement(_ measurement: SimpleMeasurement) {
        measurements.removeAll { $0.id == measurement.id }
    }
    
    var totalMeasurements: Int {
        measurements.count
    }
    
    var lastMeasurementText: String {
        guard let last = measurements.last else { return "No measurements" }
        return last.distanceText
    }
    
    var allMeasurementsText: String {
        guard !measurements.isEmpty else { return "" }
        return measurements.map { $0.distanceText }.joined(separator: ", ")
    }
    
    // Simplified methods for RealityKit
    func addPoint(at worldPosition: simd_float3) {
        if currentMeasurement == nil {
            currentMeasurement = SimpleMeasurement(startPoint: worldPosition)
            measurementMode = .placingEnd
        } else if currentMeasurement?.endPoint == nil {
            currentMeasurement?.endPoint = worldPosition
            if let measurement = currentMeasurement {
                measurements.append(measurement)
                currentMeasurement = nil
                measurementMode = .idle
            }
        }
    }
    
    var isReadyForNextPoint: Bool {
        return currentMeasurement == nil || currentMeasurement?.endPoint == nil
    }
    
    func toggleMeasurementMode() {
        if measurementMode == .idle {
            startNewMeasurement()
        } else {
            currentMeasurement = nil
            measurementMode = .idle
            isPlacingPoint = false
        }
    }
    
    func clearMeasurements() {
        measurements.removeAll()
        currentMeasurement = nil
        measurementMode = .idle
        isPlacingPoint = false
    }
}