import Foundation

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
            
            let gradientNorm = JTr.norm()
            if gradientNorm < options.toleranceGradient {
                return (x, true, iteration)
            }
            
            let (step, predictedReduction) = computeDogLegStep(
                JTJ: JTJ,
                JTr: JTr,
                trustRadius: trustRadius
            )
            
            let xNew = x + step
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
            
            let improvement = step.norm()
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
        
        let alpha = JTr.dot(JTr) / computeQuadraticForm(v: JTr, A: JTJ)
        let steepestDescent = alpha * JTr.map { -$0 }
        let steepestDescentNorm = steepestDescent.norm()
        
        if steepestDescentNorm >= trustRadius {
            let scale = trustRadius / steepestDescentNorm
            let step = scale * steepestDescent
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
        
        let gaussNewtonNorm = gaussNewtonStep.norm()
        
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
        
        let diff = gaussNewtonStep - steepestDescent
        let a = diff.dot(diff)
        let b = 2.0 * steepestDescent.dot(diff)
        let c = steepestDescent.dot(steepestDescent) - trustRadius * trustRadius
        
        let discriminant = b * b - 4.0 * a * c
        if discriminant < 0 {
            return steepestDescent
        }
        
        let tau = (-b + sqrt(discriminant)) / (2.0 * a)
        let clampedTau = max(0.0, min(1.0, tau))
        
        return steepestDescent + clampedTau * diff
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