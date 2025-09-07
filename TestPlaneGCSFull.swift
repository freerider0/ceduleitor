#!/usr/bin/env swift

import Foundation

// Full test of PlaneGCS implementation
// Compile and run: swiftc -I cedularecorder/Utils/PlaneGCS -o testgcs TestPlaneGCSFull.swift && ./testgcs

print("==============================================")
print("PlaneGCS Implementation Test")
print("==============================================\n")

// MARK: - Import PlaneGCS types (simplified versions for standalone test)

class ParameterRef {
    var value: Double
    init(_ value: Double) {
        self.value = value
    }
}

struct Point {
    let x: ParameterRef
    let y: ParameterRef
}

struct Line {
    let p1: Point
    let p2: Point
}

protocol Constraint: AnyObject {
    var parameters: [ParameterRef] { get }
    func error() -> Double
    func gradient() -> [Double]
    func rescale()
}

class ConstraintEqual: Constraint {
    let param1: ParameterRef
    let param2: ParameterRef
    
    var parameters: [ParameterRef] {
        return [param1, param2]
    }
    
    init(param1: ParameterRef, param2: ParameterRef) {
        self.param1 = param1
        self.param2 = param2
    }
    
    func error() -> Double {
        return param1.value - param2.value
    }
    
    func gradient() -> [Double] {
        return [1.0, -1.0]
    }
    
    func rescale() {
        // No rescaling needed for equality
    }
}

class ConstraintP2PDistance: Constraint {
    let p1: Point
    let p2: Point
    let distance: ParameterRef
    
    var parameters: [ParameterRef] {
        return [p1.x, p1.y, p2.x, p2.y, distance]
    }
    
    init(p1: Point, p2: Point, distance: ParameterRef) {
        self.p1 = p1
        self.p2 = p2
        self.distance = distance
    }
    
    func error() -> Double {
        let dx = p2.x.value - p1.x.value
        let dy = p2.y.value - p1.y.value
        let currentDist = sqrt(dx * dx + dy * dy)
        return currentDist - distance.value
    }
    
    func gradient() -> [Double] {
        let dx = p2.x.value - p1.x.value
        let dy = p2.y.value - p1.y.value
        let dist = sqrt(dx * dx + dy * dy)
        
        if dist < 1e-10 {
            return [0, 0, 0, 0, -1]
        }
        
        let factor = 1.0 / dist
        return [
            -dx * factor,  // d/dx1
            -dy * factor,  // d/dy1
            dx * factor,   // d/dx2
            dy * factor,   // d/dy2
            -1.0          // d/ddistance
        ]
    }
    
    func rescale() {
        // No rescaling for now
    }
}

// MARK: - Simple Solver Implementation

class SimpleSolver {
    func solve(parameters: [ParameterRef], constraints: [Constraint], maxIterations: Int = 100) -> (success: Bool, iterations: Int) {
        print("\nStarting solver with \(parameters.count) parameters and \(constraints.count) constraints")
        
        if constraints.isEmpty {
            print("No constraints to solve")
            return (true, 0)
        }
        
        var iteration = 0
        let tolerance = 1e-6
        
        while iteration < maxIterations {
            // Compute total error
            let errors = constraints.map { abs($0.error()) }
            let maxError = errors.max() ?? 0
            
            print("  Iteration \(iteration): max error = \(String(format: "%.6e", maxError))")
            
            if maxError < tolerance {
                print("  Converged!")
                return (true, iteration)
            }
            
            // Simple gradient descent step
            var gradients = Array(repeating: 0.0, count: parameters.count)
            
            for constraint in constraints {
                let error = constraint.error()
                let grad = constraint.gradient()
                let params = constraint.parameters
                
                for (i, param) in params.enumerated() {
                    if let idx = parameters.firstIndex(where: { $0 === param }) {
                        gradients[idx] -= error * grad[i] * 0.1 // learning rate
                    }
                }
            }
            
            // Update parameters
            for (i, param) in parameters.enumerated() {
                param.value += gradients[i]
            }
            
            iteration += 1
        }
        
        print("  Did not converge after \(maxIterations) iterations")
        return (false, iteration)
    }
}

// MARK: - Test Cases

func testEqualityConstraint() {
    print("\n========================================")
    print("Test 1: Simple Equality Constraint")
    print("========================================")
    
    let p1 = ParameterRef(10.0)
    let p2 = ParameterRef(20.0)
    
    print("Initial: p1 = \(p1.value), p2 = \(p2.value)")
    
    let constraint = ConstraintEqual(param1: p1, param2: p2)
    print("Constraint: p1 == p2")
    print("Initial error: \(constraint.error())")
    
    let solver = SimpleSolver()
    let result = solver.solve(parameters: [p1, p2], constraints: [constraint])
    
    print("\nResult: \(result.success ? "SUCCESS" : "FAILED") after \(result.iterations) iterations")
    print("Final: p1 = \(p1.value), p2 = \(p2.value)")
    print("Final error: \(constraint.error())")
    print("Values equal? \(abs(p1.value - p2.value) < 1e-6 ? "YES ✓" : "NO ✗")")
}

func testRectangleConstraints() {
    print("\n========================================")
    print("Test 2: Rectangle with H/V Constraints")
    print("========================================")
    
    // Create a skewed rectangle
    let corners = [
        Point(x: ParameterRef(100), y: ParameterRef(102)),  // top-left (off horizontal)
        Point(x: ParameterRef(298), y: ParameterRef(98)),   // top-right (off horizontal)
        Point(x: ParameterRef(302), y: ParameterRef(197)),  // bottom-right (off vertical)
        Point(x: ParameterRef(99), y: ParameterRef(203))    // bottom-left (off vertical)
    ]
    
    print("Initial corners:")
    for (i, corner) in corners.enumerated() {
        print("  Corner \(i): (\(corner.x.value), \(corner.y.value))")
    }
    
    // Create constraints
    var constraints: [Constraint] = []
    
    // Top edge horizontal: y0 == y1
    constraints.append(ConstraintEqual(param1: corners[0].y, param2: corners[1].y))
    
    // Right edge vertical: x1 == x2
    constraints.append(ConstraintEqual(param1: corners[1].x, param2: corners[2].x))
    
    // Bottom edge horizontal: y2 == y3
    constraints.append(ConstraintEqual(param1: corners[2].y, param2: corners[3].y))
    
    // Left edge vertical: x3 == x0
    constraints.append(ConstraintEqual(param1: corners[3].x, param2: corners[0].x))
    
    print("\nConstraints:")
    print("  Top edge: horizontal (y0 == y1)")
    print("  Right edge: vertical (x1 == x2)")
    print("  Bottom edge: horizontal (y2 == y3)")
    print("  Left edge: vertical (x3 == x0)")
    
    // Collect all parameters
    var parameters: [ParameterRef] = []
    for corner in corners {
        parameters.append(corner.x)
        parameters.append(corner.y)
    }
    
    let solver = SimpleSolver()
    let result = solver.solve(parameters: parameters, constraints: constraints)
    
    print("\nResult: \(result.success ? "SUCCESS" : "FAILED") after \(result.iterations) iterations")
    
    print("\nFinal corners:")
    for (i, corner) in corners.enumerated() {
        print("  Corner \(i): (\(corner.x.value), \(corner.y.value))")
    }
    
    print("\nConstraint verification:")
    print("  Top horizontal (Δy): \(abs(corners[0].y.value - corners[1].y.value)) \(abs(corners[0].y.value - corners[1].y.value) < 1e-6 ? "✓" : "✗")")
    print("  Right vertical (Δx): \(abs(corners[1].x.value - corners[2].x.value)) \(abs(corners[1].x.value - corners[2].x.value) < 1e-6 ? "✓" : "✗")")
    print("  Bottom horizontal (Δy): \(abs(corners[2].y.value - corners[3].y.value)) \(abs(corners[2].y.value - corners[3].y.value) < 1e-6 ? "✓" : "✗")")
    print("  Left vertical (Δx): \(abs(corners[3].x.value - corners[0].x.value)) \(abs(corners[3].x.value - corners[0].x.value) < 1e-6 ? "✓" : "✗")")
}

func testDistanceConstraint() {
    print("\n========================================")
    print("Test 3: Distance Constraint")
    print("========================================")
    
    let p1 = Point(x: ParameterRef(0), y: ParameterRef(0))
    let p2 = Point(x: ParameterRef(3), y: ParameterRef(4))
    let targetDist = ParameterRef(10.0)
    
    print("Initial points:")
    print("  P1: (\(p1.x.value), \(p1.y.value))")
    print("  P2: (\(p2.x.value), \(p2.y.value))")
    
    let initialDist = sqrt(pow(p2.x.value - p1.x.value, 2) + pow(p2.y.value - p1.y.value, 2))
    print("  Initial distance: \(initialDist)")
    print("  Target distance: \(targetDist.value)")
    
    let constraint = ConstraintP2PDistance(p1: p1, p2: p2, distance: targetDist)
    
    let solver = SimpleSolver()
    let result = solver.solve(
        parameters: [p1.x, p1.y, p2.x, p2.y],
        constraints: [constraint]
    )
    
    print("\nResult: \(result.success ? "SUCCESS" : "FAILED") after \(result.iterations) iterations")
    
    print("\nFinal points:")
    print("  P1: (\(p1.x.value), \(p1.y.value))")
    print("  P2: (\(p2.x.value), \(p2.y.value))")
    
    let finalDist = sqrt(pow(p2.x.value - p1.x.value, 2) + pow(p2.y.value - p1.y.value, 2))
    print("  Final distance: \(finalDist)")
    print("  Error: \(abs(finalDist - targetDist.value))")
    print("  Constraint satisfied? \(abs(finalDist - targetDist.value) < 1e-6 ? "YES ✓" : "NO ✗")")
}

// MARK: - Main

print("Running PlaneGCS Implementation Tests")
print("======================================\n")

testEqualityConstraint()
testRectangleConstraints()
testDistanceConstraint()

print("\n==============================================")
print("SUMMARY")
print("==============================================")
print("If all tests show ✓, the constraint solver is working correctly.")
print("If tests show ✗ or 0 iterations, there's an issue with the implementation.")
print("\nThis test shows that a basic constraint solver CAN work.")
print("The issue in your app is likely:")
print("1. Constraints not being added to the System")
print("2. System.solve() not actually iterating")
print("3. Parameters not being properly connected")
print("==============================================")