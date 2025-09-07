import Foundation

public class LevenbergMarquardtSolver {
    public struct Options {
        public var maxIterations: Int = 100
        public var tolerance: Double = 1e-10
        public var lambda: Double = 0.001
        public var lambdaUp: Double = 10.0
        public var lambdaDown: Double = 0.1
        public var eps: Double = 1e-10
        public var eps1: Double = 1e-80
        
        public init() {}
    }
    
    private var options: Options
    private var lambda: Double
    
    public init(options: Options = Options()) {
        self.options = options
        self.lambda = options.lambda
    }
    
    public func solve(
        initialParams: [Double],
        residuals: ([Double]) -> [Double],
        jacobian: ([Double]) -> Matrix
    ) -> (params: [Double], converged: Bool, iterations: Int) {
        
        var x = initialParams
        var iteration = 0
        
        lambda = options.lambda
        
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
            if gradientNorm < options.eps {
                return (x, true, iteration)
            }
            
            var improved = false
            var innerIteration = 0
            let maxInnerIterations = 10
            
            while !improved && innerIteration < maxInnerIterations {
                var A = JTJ
                for i in 0..<A.rows {
                    A[i, i] += lambda
                }
                
                guard let delta = A.solve(JTr.map { -$0 }) else {
                    lambda *= options.lambdaUp
                    innerIteration += 1
                    continue
                }
                
                let xNew = x + delta
                let newResiduals = residuals(xNew)
                let newError = newResiduals.map { $0 * $0 }.reduce(0, +)
                
                let rho = computeGainRatio(
                    actualReduction: currentError - newError,
                    predictedReduction: predictedReduction(JTr: JTr, JTJ: JTJ, delta: delta)
                )
                
                if rho > 0 {
                    x = xNew
                    currentResiduals = newResiduals
                    currentError = newError
                    
                    if rho > 0.75 {
                        lambda = max(lambda * options.lambdaDown, 1e-7)
                    } else if rho < 0.25 {
                        lambda = min(lambda * options.lambdaUp, 1e7)
                    }
                    
                    improved = true
                } else {
                    lambda *= options.lambdaUp
                }
                
                innerIteration += 1
            }
            
            if !improved {
                return (x, false, iteration)
            }
            
            let improvement = currentResiduals.norm()
            if improvement < options.tolerance {
                return (x, true, iteration)
            }
            
            iteration += 1
        }
        
        return (x, false, iteration)
    }
    
    private func computeGainRatio(actualReduction: Double, predictedReduction: Double) -> Double {
        if abs(predictedReduction) < options.eps1 {
            return 0
        }
        return actualReduction / predictedReduction
    }
    
    private func predictedReduction(JTr: [Double], JTJ: Matrix, delta: [Double]) -> Double {
        var reduction = 0.0
        
        for i in 0..<delta.count {
            reduction += delta[i] * JTr[i]
            
            for j in 0..<delta.count {
                reduction += 0.5 * delta[i] * JTJ[i, j] * delta[j]
            }
        }
        
        return reduction
    }
}