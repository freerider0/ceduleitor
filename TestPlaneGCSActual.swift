#!/usr/bin/env swift

import Foundation

// Test with the ACTUAL PlaneGCS implementation
// This uses the real classes from the app

// MARK: - ParameterRef
public class ParameterRef {
    public var value: Double
    
    public init(_ value: Double) {
        self.value = value
    }
}

// MARK: - Geometry
public struct Point {
    public let x: ParameterRef
    public let y: ParameterRef
    
    public init(x: ParameterRef, y: ParameterRef) {
        self.x = x
        self.y = y
    }
}

public struct Line {
    public let p1: Point
    public let p2: Point
    
    public init(p1: Point, p2: Point) {
        self.p1 = p1
        self.p2 = p2
    }
}

// MARK: - Matrix (simplified)
public struct Matrix {
    public var data: [[Double]]
    public let rows: Int
    public let cols: Int
    
    public init(rows: Int, cols: Int) {
        self.rows = rows
        self.cols = cols
        self.data = Array(repeating: Array(repeating: 0.0, count: cols), count: rows)
    }
    
    public subscript(row: Int, col: Int) -> Double {
        get { return data[row][col] }
        set { data[row][col] = newValue }
    }
    
    public func transpose() -> Matrix {
        var result = Matrix(rows: cols, cols: rows)
        for i in 0..<rows {
            for j in 0..<cols {
                result[j, i] = self[i, j]
            }
        }
        return result
    }
    
    public static func * (lhs: Matrix, rhs: Matrix) -> Matrix {
        var result = Matrix(rows: lhs.rows, cols: rhs.cols)
        for i in 0..<lhs.rows {
            for j in 0..<rhs.cols {
                for k in 0..<lhs.cols {
                    result[i, j] += lhs[i, k] * rhs[k, j]
                }
            }
        }
        return result
    }
    
    public func solve(_ b: [Double]) -> [Double]? {
        guard rows == cols && rows == b.count else { return nil }
        guard rows > 0 else { return nil }
        
        // Create working copies - convert 2D array to flat for easier manipulation
        var a = Array(repeating: Array(repeating: 0.0, count: cols), count: rows)
        for i in 0..<rows {
            for j in 0..<cols {
                a[i][j] = self[i, j]
            }
        }
        var x = b
        
        // Forward elimination with partial pivoting
        for k in 0..<rows {
            // Find pivot
            var maxRow = k
            var maxVal = abs(a[k][k])
            for i in (k+1)..<rows {
                if abs(a[i][k]) > maxVal {
                    maxVal = abs(a[i][k])
                    maxRow = i
                }
            }
            
            // Check for singular matrix
            if abs(a[maxRow][k]) < 1e-10 {
                return nil
            }
            
            // Swap rows
            if maxRow != k {
                a.swapAt(k, maxRow)
                let temp = x[k]
                x[k] = x[maxRow]
                x[maxRow] = temp
            }
            
            // Eliminate column
            for i in (k+1)..<rows {
                let factor = a[i][k] / a[k][k]
                for j in k..<cols {
                    a[i][j] -= factor * a[k][j]
                }
                x[i] -= factor * x[k]
            }
        }
        
        // Back substitution
        for i in (0..<rows).reversed() {
            for j in (i+1)..<cols {
                x[i] -= a[i][j] * x[j]
            }
            x[i] /= a[i][i]
        }
        
        return x
    }
}

// MARK: - Constraint Protocol
public enum ConstraintType {
    case equal
    case distance
    case horizontal
    case vertical
}

public protocol Constraint: AnyObject {
    var type: ConstraintType { get }
    var parameters: [ParameterRef] { get }
    var scale: Double { get set }
    var tag: Int { get set }
    
    func error() -> Double
    func gradient() -> [Double]
    func rescale()
}

// MARK: - ConstraintEqual
public class ConstraintEqual: Constraint {
    public let type = ConstraintType.equal
    public var parameters: [ParameterRef]
    public var scale: Double = 1.0
    public var tag: Int = 0
    
    public var param1: ParameterRef
    public var param2: ParameterRef
    
    public init(param1: ParameterRef, param2: ParameterRef) {
        self.param1 = param1
        self.param2 = param2
        self.parameters = [param1, param2]
    }
    
    public func error() -> Double {
        return scale * (param1.value - param2.value)
    }
    
    public func gradient() -> [Double] {
        return [scale, -scale]
    }
    
    public func rescale() {
        let err = abs(error())
        if err > 1e-10 {
            scale = 1.0 / err
        } else {
            scale = 1.0
        }
    }
}

// MARK: - SubSystem
public class SubSystem {
    public var constraints: [Constraint] = []
    public var parameters: Set<ObjectIdentifier> = []
    public var parameterRefs: [ParameterRef] = []
    public var parameterIndices: [ObjectIdentifier: Int] = [:]
    
    public init() {}
    
    public func addConstraint(_ constraint: Constraint) {
        constraints.append(constraint)
        print("  SubSystem: Added constraint, now have \(constraints.count) constraints")
        
        let paramCount = constraint.parameters.count
        print("  SubSystem: Constraint has \(paramCount) parameters")
        
        for param in constraint.parameters {
            let id = ObjectIdentifier(param)
            if !parameters.contains(id) {
                parameters.insert(id)
                parameterIndices[id] = parameterRefs.count
                parameterRefs.append(param)
                print("  SubSystem: Added new parameter, total params: \(parameterRefs.count)")
            } else {
                print("  SubSystem: Parameter already exists")
            }
        }
    }
    
    public func isEmpty() -> Bool {
        return constraints.isEmpty
    }
    
    public func getParameterValues() -> [Double] {
        return parameterRefs.map { $0.value }
    }
    
    public func setParameterValues(_ values: [Double]) {
        for (index, value) in values.enumerated() {
            if index < parameterRefs.count {
                parameterRefs[index].value = value
            }
        }
    }
    
    public func computeResiduals() -> [Double] {
        return constraints.map { $0.error() }
    }
    
    public func computeJacobian() -> Matrix {
        let m = constraints.count
        let n = parameterRefs.count
        
        var jacobian = Matrix(rows: m, cols: n)
        
        for (i, constraint) in constraints.enumerated() {
            let gradient = constraint.gradient()
            
            for (j, param) in constraint.parameters.enumerated() {
                let id = ObjectIdentifier(param)
                if let colIndex = parameterIndices[id] {
                    jacobian[i, colIndex] = gradient[j]
                }
            }
        }
        
        return jacobian
    }
    
    public func getMaxError() -> Double {
        return constraints.map { abs($0.error()) }.max() ?? 0.0
    }
    
    public func getTotalError() -> Double {
        return constraints.map { $0.error() * $0.error() }.reduce(0, +)
    }
    
    public func getDOF() -> Int {
        return parameterRefs.count - constraints.count
    }
}

// MARK: - Import the ACTUAL DogLeg solver from the app
public class DogLegSolver {
    public struct Options {
        public var maxIterations: Int = 100
        public var tolerance: Double = 1e-10
        public var trustRegionRadius: Double = 1.0
        public var minTrustRegionRadius: Double = 1e-10
        public var maxTrustRegionRadius: Double = 1e10
        public var eta: Double = 0.125
        public var toleranceGradient: Double = 1e-10
        
        public init() {}
    }
    
    private var options: Options
    private var trustRadius: Double
    
    public init(options: Options = Options()) {
        self.options = options
        self.trustRadius = options.trustRegionRadius
    }
    
    public func solve(
        initialParams: [Double],
        residuals: ([Double]) -> [Double],
        jacobian: ([Double]) -> Matrix
    ) -> (params: [Double], converged: Bool, iterations: Int) {
        
        var x = initialParams
        var iteration = 0
        
        trustRadius = options.trustRegionRadius
        
        var currentResiduals = residuals(x)
        var currentError = currentResiduals.map { $0 * $0 }.reduce(0, +)
        
        while iteration < options.maxIterations {
            let J = jacobian(x)
            let JT = J.transpose()
            let JTJ = JT * J
            
            var JTr = Array(repeating: 0.0, count: x.count)
            for i in 0..<x.count {
                for j in 0..<currentResiduals.count {
                    JTr[i] += JT[i, j] * currentResiduals[j]
                }
            }
            
            let gradientNorm = sqrt(JTr.map { $0 * $0 }.reduce(0, +))
            if gradientNorm < options.toleranceGradient {
                return (x, true, iteration)
            }
            
            let (step, predictedReduction) = computeDogLegStep(
                JTJ: JTJ,
                JTr: JTr,
                trustRadius: trustRadius
            )
            
            let xNew = x.enumerated().map { $1 + step[$0] }
            let newResiduals = residuals(xNew)
            let newError = newResiduals.map { $0 * $0 }.reduce(0, +)
            
            let actualReduction = currentError - newError
            let rho = computeGainRatio(
                actualReduction: actualReduction,
                predictedReduction: predictedReduction
            )
            
            if rho > options.eta {
                x = xNew
                currentResiduals = newResiduals
                currentError = newError
                
                if rho > 0.75 {
                    trustRadius = min(2.0 * trustRadius, options.maxTrustRegionRadius)
                }
            } else {
                if rho < 0.25 {
                    trustRadius = max(0.25 * trustRadius, options.minTrustRegionRadius)
                }
            }
            
            if trustRadius < options.minTrustRegionRadius {
                return (x, false, iteration)
            }
            
            let improvement = sqrt(step.map { $0 * $0 }.reduce(0, +))
            if improvement < options.tolerance {
                return (x, true, iteration)
            }
            
            iteration += 1
        }
        
        return (x, false, iteration)
    }
    
    private func computeDogLegStep(
        JTJ: Matrix,
        JTr: [Double],
        trustRadius: Double
    ) -> (step: [Double], predictedReduction: Double) {
        
        let alpha = JTr.map { $0 * $0 }.reduce(0, +) / computeQuadraticForm(v: JTr, A: JTJ)
        let steepestDescent = JTr.map { -alpha * $0 }
        let steepestDescentNorm = sqrt(steepestDescent.map { $0 * $0 }.reduce(0, +))
        
        if steepestDescentNorm >= trustRadius {
            let scale = trustRadius / steepestDescentNorm
            let step = steepestDescent.map { scale * $0 }
            let predictedReduction = computePredictedReduction(step: step, JTr: JTr, JTJ: JTJ)
            return (step, predictedReduction)
        }
        
        // Add Levenberg-Marquardt style damping for underdetermined systems
        var JTJ_damped = JTJ
        let lambda = 0.01  // Small damping parameter
        for i in 0..<JTJ.rows {
            JTJ_damped[i, i] = JTJ[i, i] + lambda
        }
        
        guard let gaussNewtonStep = JTJ_damped.solve(JTr.map { -$0 }) else {
            let predictedReduction = computePredictedReduction(step: steepestDescent, JTr: JTr, JTJ: JTJ)
            return (steepestDescent, predictedReduction)
        }
        
        let gaussNewtonNorm = sqrt(gaussNewtonStep.map { $0 * $0 }.reduce(0, +))
        
        if gaussNewtonNorm <= trustRadius {
            let predictedReduction = computePredictedReduction(step: gaussNewtonStep, JTr: JTr, JTJ: JTJ)
            return (gaussNewtonStep, predictedReduction)
        }
        
        let dogLegStep = computeDogLegInterpolation(
            steepestDescent: steepestDescent,
            gaussNewtonStep: gaussNewtonStep,
            trustRadius: trustRadius
        )
        
        let predictedReduction = computePredictedReduction(step: dogLegStep, JTr: JTr, JTJ: JTJ)
        return (dogLegStep, predictedReduction)
    }
    
    private func computeDogLegInterpolation(
        steepestDescent: [Double],
        gaussNewtonStep: [Double],
        trustRadius: Double
    ) -> [Double] {
        
        let diff = zip(gaussNewtonStep, steepestDescent).map { $0 - $1 }
        let a = diff.map { $0 * $0 }.reduce(0, +)
        let b = 2.0 * zip(steepestDescent, diff).map { $0 * $1 }.reduce(0, +)
        let c = steepestDescent.map { $0 * $0 }.reduce(0, +) - trustRadius * trustRadius
        
        let discriminant = b * b - 4.0 * a * c
        if discriminant < 0 {
            return steepestDescent
        }
        
        let tau = (-b + sqrt(discriminant)) / (2.0 * a)
        let clampedTau = max(0.0, min(1.0, tau))
        
        return zip(steepestDescent, diff).map { $0 + clampedTau * $1 }
    }
    
    private func computeQuadraticForm(v: [Double], A: Matrix) -> Double {
        var result = 0.0
        for i in 0..<v.count {
            for j in 0..<v.count {
                result += v[i] * A[i, j] * v[j]
            }
        }
        return result
    }
    
    private func computePredictedReduction(step: [Double], JTr: [Double], JTJ: Matrix) -> Double {
        var reduction = 0.0
        
        for i in 0..<step.count {
            reduction -= step[i] * JTr[i]
            
            for j in 0..<step.count {
                reduction -= 0.5 * step[i] * JTJ[i, j] * step[j]
            }
        }
        
        return reduction
    }
    
    private func computeGainRatio(actualReduction: Double, predictedReduction: Double) -> Double {
        if abs(predictedReduction) < 1e-80 {
            return 0
        }
        return actualReduction / predictedReduction
    }
}

// MARK: - System
public enum SolveStatus {
    case success
    case convergedToLocalMinimum
    case notConverged
    case failed
}

public enum Algorithm {
    case dogLeg
    case levenbergMarquardt
    case bfgs
}

public struct SolverParameters {
    public var algorithm: Algorithm = .dogLeg
    public var maxIterations: Int = 100
    public var convergenceTolerance: Double = 1e-10
    public var debugMode: Bool = true
    
    public init() {}
}

public class System {
    private var subSystems: [SubSystem] = []
    private var allConstraints: [Constraint] = []
    private var parameters: SolverParameters = SolverParameters()
    private var lastIterations: Int = 0
    
    public init() {
        subSystems.append(SubSystem())
    }
    
    public func addConstraint(_ constraint: Constraint) {
        allConstraints.append(constraint)
        subSystems[0].addConstraint(constraint)
        print("System: Added constraint, total: \(allConstraints.count)")
    }
    
    public func setParameters(_ params: SolverParameters) {
        self.parameters = params
    }
    
    public func solve() -> SolveStatus {
        print("\n=== System.solve() called ===")
        print("Total constraints: \(allConstraints.count)")
        print("SubSystems: \(subSystems.count)")
        
        if allConstraints.isEmpty {
            print("No constraints to solve")
            lastIterations = 0
            return .success
        }
        
        for (i, subSystem) in subSystems.enumerated() {
            print("SubSystem \(i): \(subSystem.constraints.count) constraints, \(subSystem.parameterRefs.count) parameters")
            
            if !subSystem.isEmpty() {
                let initialParams = subSystem.getParameterValues()
                
                if initialParams.isEmpty {
                    print("WARNING: No parameters to solve!")
                    lastIterations = 0
                    return .success
                }
                
                let residuals: ([Double]) -> [Double] = { params in
                    subSystem.setParameterValues(params)
                    return subSystem.computeResiduals()
                }
                
                let jacobian: ([Double]) -> Matrix = { params in
                    subSystem.setParameterValues(params)
                    return subSystem.computeJacobian()
                }
                
                // Use the ACTUAL DogLeg solver from the app
                let solver = DogLegSolver()
                let result = solver.solve(
                    initialParams: initialParams,
                    residuals: residuals,
                    jacobian: jacobian
                )
                
                subSystem.setParameterValues(result.params)
                lastIterations = result.iterations
                
                return result.converged ? .success : .notConverged
            }
        }
        
        return .success
    }
    
    public func getLastIterations() -> Int {
        return lastIterations
    }
    
    public func getDOF() -> Int {
        return subSystems.map { $0.getDOF() }.reduce(0, +)
    }
    
    public func getMaxError() -> Double {
        return subSystems.map { $0.getMaxError() }.max() ?? 0.0
    }
}

// MARK: - Tests

print("==============================================")
print("Testing ACTUAL PlaneGCS Implementation")
print("==============================================\n")

func testSimpleEqual() {
    print("\nTest 1: Simple Equal Constraint")
    print("--------------------------------")
    
    let system = System()
    
    // Create two parameters that should be equal
    let a = ParameterRef(10.0)
    let b = ParameterRef(20.0)
    
    print("Initial: a = \(a.value), b = \(b.value)")
    
    // Add constraint a == b
    system.addConstraint(ConstraintEqual(param1: a, param2: b))
    
    var params = SolverParameters()
    params.algorithm = .dogLeg
    params.maxIterations = 50
    params.debugMode = false
    system.setParameters(params)
    
    let status = system.solve()
    
    print("Result: a = \(a.value), b = \(b.value)")
    print("Status: \(status), Iterations: \(system.getLastIterations())")
    print("Error: \(abs(a.value - b.value))")
    
    if abs(a.value - b.value) < 1e-6 {
        print("✅ PASSED: Values are equal")
    } else {
        print("❌ FAILED: Values should be equal")
    }
}

func testTriangle() {
    print("\nTest 2: Triangle with Mixed Constraints")
    print("----------------------------------------")
    
    let system = System()
    
    // Create triangle vertices
    let x0 = ParameterRef(0.0)
    let y0 = ParameterRef(0.0)
    let x1 = ParameterRef(10.0)
    let y1 = ParameterRef(1.0)  // Slightly off horizontal
    let x2 = ParameterRef(5.0)
    let y2 = ParameterRef(8.0)
    
    print("Initial triangle:")
    print("  V0: (\(x0.value), \(y0.value))")
    print("  V1: (\(x1.value), \(y1.value))")
    print("  V2: (\(x2.value), \(y2.value))")
    
    // Make base horizontal (y0 == y1)
    system.addConstraint(ConstraintEqual(param1: y0, param2: y1))
    
    // Fix x0 at origin
    let zero = ParameterRef(0.0)
    system.addConstraint(ConstraintEqual(param1: x0, param2: zero))
    system.addConstraint(ConstraintEqual(param1: y0, param2: zero))
    
    var params = SolverParameters()
    params.algorithm = .dogLeg
    params.maxIterations = 50
    params.debugMode = false
    system.setParameters(params)
    
    let status = system.solve()
    
    print("\nFinal triangle:")
    print("  V0: (\(x0.value), \(y0.value))")
    print("  V1: (\(x1.value), \(y1.value))")
    print("  V2: (\(x2.value), \(y2.value))")
    print("Status: \(status), Iterations: \(system.getLastIterations())")
    
    let baseHorizontal = abs(y0.value - y1.value) < 1e-6
    let v0AtOrigin = abs(x0.value) < 1e-6 && abs(y0.value) < 1e-6
    
    if baseHorizontal && v0AtOrigin {
        print("✅ PASSED: Triangle constraints satisfied")
    } else {
        print("❌ FAILED: Constraints not satisfied")
    }
}

func testRectangleConstraints() {
    print("\nTest 3: Rectangle with All Edges Constrained")
    print("---------------------------------------------")
    
    let system = System()
    
    // Create 4 corners (slightly misaligned)
    let x0 = ParameterRef(100.0)
    let y0 = ParameterRef(102.0)  // Off by 2
    let x1 = ParameterRef(298.0)
    let y1 = ParameterRef(98.0)   // Off by 2
    let x2 = ParameterRef(302.0)  // Off by 4
    let y2 = ParameterRef(197.0)
    let x3 = ParameterRef(99.0)   // Off by 1
    let y3 = ParameterRef(203.0)  // Off by 6
    
    print("Initial corners:")
    print("  0: (\(x0.value), \(y0.value))")
    print("  1: (\(x1.value), \(y1.value))")
    print("  2: (\(x2.value), \(y2.value))")
    print("  3: (\(x3.value), \(y3.value))")
    
    // Add constraints
    // Top horizontal: y0 == y1
    system.addConstraint(ConstraintEqual(param1: y0, param2: y1))
    
    // Right vertical: x1 == x2
    system.addConstraint(ConstraintEqual(param1: x1, param2: x2))
    
    // Bottom horizontal: y2 == y3
    system.addConstraint(ConstraintEqual(param1: y2, param2: y3))
    
    // Left vertical: x3 == x0
    system.addConstraint(ConstraintEqual(param1: x3, param2: x0))
    
    // Solve
    var params = SolverParameters()
    params.algorithm = .dogLeg
    params.maxIterations = 100
    params.debugMode = false
    system.setParameters(params)
    
    let status = system.solve()
    
    print("\nFinal corners:")
    print("  0: (\(String(format: "%.2f", x0.value)), \(String(format: "%.2f", y0.value)))")
    print("  1: (\(String(format: "%.2f", x1.value)), \(String(format: "%.2f", y1.value)))")
    print("  2: (\(String(format: "%.2f", x2.value)), \(String(format: "%.2f", y2.value)))")
    print("  3: (\(String(format: "%.2f", x3.value)), \(String(format: "%.2f", y3.value)))")
    
    print("\nStatus: \(status), Iterations: \(system.getLastIterations())")
    print("Max error: \(system.getMaxError())")
    
    let topHorizontal = abs(y0.value - y1.value)
    let rightVertical = abs(x1.value - x2.value)
    let bottomHorizontal = abs(y2.value - y3.value)
    let leftVertical = abs(x3.value - x0.value)
    
    print("\nConstraint errors:")
    print("  Top horizontal: \(String(format: "%.6f", topHorizontal))")
    print("  Right vertical: \(String(format: "%.6f", rightVertical))")
    print("  Bottom horizontal: \(String(format: "%.6f", bottomHorizontal))")
    print("  Left vertical: \(String(format: "%.6f", leftVertical))")
    
    let maxConstraintError = max(topHorizontal, rightVertical, bottomHorizontal, leftVertical)
    if maxConstraintError < 0.1 {
        print("✅ PASSED: Rectangle constraints mostly satisfied")
    } else {
        print("❌ FAILED: Rectangle constraints not satisfied")
    }
}

func testOverConstrained() {
    print("\nTest 4: Over-constrained System")
    print("--------------------------------")
    
    let system = System()
    
    // Create parameters
    let a = ParameterRef(10.0)
    let b = ParameterRef(20.0)
    let c = ParameterRef(30.0)
    
    print("Initial: a = \(a.value), b = \(b.value), c = \(c.value)")
    
    // Add conflicting constraints
    system.addConstraint(ConstraintEqual(param1: a, param2: b))  // a == b
    system.addConstraint(ConstraintEqual(param1: b, param2: c))  // b == c
    system.addConstraint(ConstraintEqual(param1: a, param2: c))  // a == c (redundant)
    
    var params = SolverParameters()
    params.algorithm = .dogLeg
    params.maxIterations = 50
    params.debugMode = false
    system.setParameters(params)
    
    let status = system.solve()
    
    print("Result: a = \(String(format: "%.2f", a.value)), b = \(String(format: "%.2f", b.value)), c = \(String(format: "%.2f", c.value))")
    print("Status: \(status), Iterations: \(system.getLastIterations())")
    
    let allEqual = abs(a.value - b.value) < 0.1 && abs(b.value - c.value) < 0.1
    if allEqual {
        print("✅ PASSED: All values converged to be equal")
    } else {
        print("❌ FAILED: Values should be equal")
    }
}

// Run all tests
testSimpleEqual()
testTriangle()
testRectangleConstraints()
testOverConstrained()

print("\n==============================================")
print("All Tests Complete")
print("==============================================")