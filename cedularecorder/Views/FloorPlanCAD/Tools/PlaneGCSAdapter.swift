import Foundation
import UIKit

// MARK: - PlaneGCS Adapter
/// Adapter to bridge between CADRoom constraints and PlaneGCS System
/// Using the real PlaneGCS implementation from Utils folder
class PlaneGCSAdapter {
    
    // Using the real PlaneGCS System
    private let system = System()
    
    // MARK: - Solve Constraints
    /// Solve all constraints for a room using PlaneGCS
    func solveConstraints(for room: CADRoom) -> (success: Bool, error: String?) {
        print("\n========== PlaneGCSAdapter: Starting Constraint Solving ==========")
        print("Room: \(room.name) with \(room.corners.count) corners")
        print("Edge constraints: \(room.edgeConstraints.count)")
        print("Point constraints: \(room.pointConstraints.count)")
        
        // Clear previous constraints
        system.clearConstraints()
        
        // Create parameters for each corner coordinate
        var parameters: [ParameterRef] = []
        for (index, corner) in room.corners.enumerated() {
            let xParam = ParameterRef(Double(corner.x))
            let yParam = ParameterRef(Double(corner.y))
            parameters.append(xParam)
            parameters.append(yParam)
            print("Corner \(index): (\(corner.x), \(corner.y))")
        }
        
        // Add point constraints to the system
        for constraint in room.pointConstraints {
            switch constraint.type {
            case .pointOnLine:
                if let edgeIndex = constraint.referenceEdgeIndex {
                    let pointIndex = constraint.pointIndex
                    let edgeStart = edgeIndex * 2
                    let edgeEnd = ((edgeIndex + 1) % room.corners.count) * 2
                    
                    let point = Point(
                        x: parameters[pointIndex * 2],
                        y: parameters[pointIndex * 2 + 1]
                    )
                    let line = Line(
                        p1: Point(x: parameters[edgeStart], y: parameters[edgeStart + 1]),
                        p2: Point(x: parameters[edgeEnd], y: parameters[edgeEnd + 1])
                    )
                    
                    let pointOnLineConstraint = ConstraintPointOnLine(point: point, line: line)
                    system.addConstraint(pointOnLineConstraint)
                }
                
            case .pointToPointDistance:
                if let refPointIndex = constraint.referencePointIndex,
                   let distance = constraint.targetValue {
                    let p1 = Point(
                        x: parameters[constraint.pointIndex * 2],
                        y: parameters[constraint.pointIndex * 2 + 1]
                    )
                    let p2 = Point(
                        x: parameters[refPointIndex * 2],
                        y: parameters[refPointIndex * 2 + 1]
                    )
                    
                    let distanceParam = ParameterRef(Double(distance))
                    let distanceConstraint = ConstraintP2PDistance(
                        p1: p1,
                        p2: p2,
                        distance: distanceParam
                    )
                    system.addConstraint(distanceConstraint)
                }
                
            case .pointToLineDistance:
                if let edgeIndex = constraint.referenceEdgeIndex,
                   let distance = constraint.targetValue {
                    let pointIndex = constraint.pointIndex
                    let edgeStart = edgeIndex * 2
                    let edgeEnd = ((edgeIndex + 1) % room.corners.count) * 2
                    
                    let point = Point(
                        x: parameters[pointIndex * 2],
                        y: parameters[pointIndex * 2 + 1]
                    )
                    let line = Line(
                        p1: Point(x: parameters[edgeStart], y: parameters[edgeStart + 1]),
                        p2: Point(x: parameters[edgeEnd], y: parameters[edgeEnd + 1])
                    )
                    
                    let distanceParam = ParameterRef(Double(distance))
                    let distanceConstraint = ConstraintP2LDistance(
                        point: point,
                        line: line,
                        distance: distanceParam
                    )
                    system.addConstraint(distanceConstraint)
                }
                
            case .coincident:
                if let refPointIndex = constraint.referencePointIndex {
                    // Make two points coincident (same location)
                    let xEqual = ConstraintEqual(
                        param1: parameters[constraint.pointIndex * 2],
                        param2: parameters[refPointIndex * 2]
                    )
                    let yEqual = ConstraintEqual(
                        param1: parameters[constraint.pointIndex * 2 + 1],
                        param2: parameters[refPointIndex * 2 + 1]
                    )
                    system.addConstraint(xEqual)
                    system.addConstraint(yEqual)
                }
                
            default:
                // Skip edge constraint types
                break
            }
        }
        
        // Add edge constraints to the system
        for constraint in room.edgeConstraints {
            switch constraint.type {
            case .length:
                if let targetLength = constraint.targetValue {
                    let i = constraint.edgeIndex * 2
                    let j = ((constraint.edgeIndex + 1) % room.corners.count) * 2
                    
                    print("Adding LENGTH constraint for edge \(constraint.edgeIndex): \(targetLength)")
                    
                    // Create points for the edge
                    let p1 = Point(x: parameters[i], y: parameters[i + 1])
                    let p2 = Point(x: parameters[j], y: parameters[j + 1])
                    
                    // Create distance constraint
                    let distanceParam = ParameterRef(Double(targetLength))
                    let distanceConstraint = ConstraintP2PDistance(
                        p1: p1,
                        p2: p2,
                        distance: distanceParam
                    )
                    system.addConstraint(distanceConstraint)
                }
                
            case .horizontal:
                let i = constraint.edgeIndex * 2
                let j = ((constraint.edgeIndex + 1) % room.corners.count) * 2
                
                print("Adding HORIZONTAL constraint for edge \(constraint.edgeIndex)")
                print("  Points: (\(parameters[i].value), \(parameters[i+1].value)) -> (\(parameters[j].value), \(parameters[j+1].value))")
                
                // For horizontal constraint, y-coordinates should be equal
                // This is simpler and more stable than angle constraints
                let y1 = parameters[i + 1]
                let y2 = parameters[j + 1]
                print("  Y1 value: \(y1.value), Y2 value: \(y2.value)")
                print("  Difference: \(abs(y1.value - y2.value))")
                
                let equalY = ConstraintEqual(
                    param1: y1,
                    param2: y2
                )
                print("  About to add ConstraintEqual constraint")
                print("  Constraint has \(equalY.parameters.count) parameters")
                system.addConstraint(equalY)
                print("  Added ConstraintEqual for Y coordinates")
                
            case .vertical:
                let i = constraint.edgeIndex * 2
                let j = ((constraint.edgeIndex + 1) % room.corners.count) * 2
                
                print("Adding VERTICAL constraint for edge \(constraint.edgeIndex)")
                print("  Points: (\(parameters[i].value), \(parameters[i+1].value)) -> (\(parameters[j].value), \(parameters[j+1].value))")
                
                // For vertical constraint, x-coordinates should be equal
                // This is simpler and more stable than angle constraints
                let equalX = ConstraintEqual(
                    param1: parameters[i],      // x1
                    param2: parameters[j]       // x2
                )
                system.addConstraint(equalX)
                print("  Constraining X coordinates to be equal")
                
            case .perpendicular:
                if let refIndex = constraint.referenceEdgeIndex {
                    // Create perpendicular constraint between two edges
                    let i1 = constraint.edgeIndex * 2
                    let j1 = ((constraint.edgeIndex + 1) % room.corners.count) * 2
                    let i2 = refIndex * 2
                    let j2 = ((refIndex + 1) % room.corners.count) * 2
                    
                    // Create lines for both edges
                    let line1 = Line(
                        p1: Point(x: parameters[i1], y: parameters[i1 + 1]),
                        p2: Point(x: parameters[j1], y: parameters[j1 + 1])
                    )
                    let line2 = Line(
                        p1: Point(x: parameters[i2], y: parameters[i2 + 1]),
                        p2: Point(x: parameters[j2], y: parameters[j2 + 1])
                    )
                    
                    let perpendicularConstraint = ConstraintPerpendicular(
                        line1: line1,
                        line2: line2
                    )
                    system.addConstraint(perpendicularConstraint)
                }
                
            case .parallel:
                if let refIndex = constraint.referenceEdgeIndex {
                    // Create parallel constraint between two edges
                    let i1 = constraint.edgeIndex * 2
                    let j1 = ((constraint.edgeIndex + 1) % room.corners.count) * 2
                    let i2 = refIndex * 2
                    let j2 = ((refIndex + 1) % room.corners.count) * 2
                    
                    // Create lines for both edges
                    let line1 = Line(
                        p1: Point(x: parameters[i1], y: parameters[i1 + 1]),
                        p2: Point(x: parameters[j1], y: parameters[j1 + 1])
                    )
                    let line2 = Line(
                        p1: Point(x: parameters[i2], y: parameters[i2 + 1]),
                        p2: Point(x: parameters[j2], y: parameters[j2 + 1])
                    )
                    
                    let parallelConstraint = ConstraintParallel(
                        line1: line1,
                        line2: line2
                    )
                    system.addConstraint(parallelConstraint)
                }
                
            case .angle:
                // Not implemented yet
                break
                
            // Point constraint types should not appear here (handled separately)
            case .pointOnLine, .pointToPointDistance, .pointToLineDistance, .coincident:
                // These are handled in the pointConstraints loop above
                break
            }
        }
        
        // Check if we have any constraints to solve
        let hasEdgeConstraints = !room.edgeConstraints.isEmpty
        let hasPointConstraints = !room.pointConstraints.isEmpty
        
        if !hasEdgeConstraints && !hasPointConstraints {
            print("No constraints to solve, returning original geometry")
            return (true, nil)
        }
        
        // Debug: Check what got added to the system
        print("\n=== CONSTRAINT SYSTEM DEBUG ===")
        print("System has \(system.getConstraintCount()) constraints")
        print("System has \(system.getParameterCount()) parameters")
        
        // Configure solver parameters
        var solverParams = SolverParameters()
        solverParams.algorithm = .dogLeg  // Try DogLeg again with better settings
        solverParams.maxIterations = 1000  // More iterations for convergence
        solverParams.convergenceTolerance = 1e-6  // More reasonable tolerance
        solverParams.debugMode = true
        
        // Configure DogLeg specific options
        solverParams.dogLegOptions.trustRegionRadius = 10.0
        solverParams.dogLegOptions.maxTrustRegionRadius = 1000.0
        solverParams.dogLegOptions.minTrustRegionRadius = 1e-6
        
        system.setParameters(solverParams)
        
        // Solve the system
        print("\nSolving constraint system...")
        print("DOF (Degrees of Freedom): \(system.getDOF())")
        print("Constraints in system: \(system.getConstraintCount())")
        print("Parameters in system: \(system.getParameterCount())")
        print("About to call system.solve()...")
        let status = system.solve()
        print("Solver status: \(status)")
        print("Solver error: \(system.getMaxError())")
        print("Solver iterations: \(system.getLastIterations())")
        
        // Update room corners with solved values
        var newCorners: [CGPoint] = []
        for i in 0..<room.corners.count {
            let oldX = room.corners[i].x
            let oldY = room.corners[i].y
            let x = CGFloat(parameters[i * 2].value)
            let y = CGFloat(parameters[i * 2 + 1].value)
            newCorners.append(CGPoint(x: x, y: y))
            
            // Debug: Show corner movement
            let dx = x - oldX
            let dy = y - oldY
            if abs(dx) > 0.1 || abs(dy) > 0.1 {
                print("Corner \(i) moved: (\(oldX), \(oldY)) -> (\(x), \(y)) [Δx=\(dx), Δy=\(dy)]")
            }
        }
        room.corners = newCorners
        print("PlaneGCS: Updated \(room.corners.count) corners")
        
        // Return result based on solve status
        print("\n========== PlaneGCSAdapter: Solving Complete ==========\n")
        switch status {
        case .success:
            print("✅ PlaneGCS: Solved successfully")
            return (true, nil)
        case .convergedToLocalMinimum:
            print("PlaneGCS: Converged to local minimum")
            return (true, "Converged to local minimum")
        case .notConverged:
            print("PlaneGCS: Failed to converge")
            return (false, "Failed to converge")
        case .failed:
            print("PlaneGCS: Solver failed")
            return (false, "Solver failed")
        }
    }
    
    // MARK: - Available Algorithms
    /// Get list of available solver algorithms
    func availableAlgorithms() -> [String] {
        return ["BFGS", "Levenberg-Marquardt", "DogLeg"]
    }
    
    // MARK: - Solver Info
    /// Get information about the current solver
    func getSolverInfo() -> String {
        return "Using PlaneGCS with DogLeg algorithm"
    }
}