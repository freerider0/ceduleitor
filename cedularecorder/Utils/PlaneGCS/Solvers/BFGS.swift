import Foundation

public class BFGSSolver {
    public struct Options {
        public var maxIterations: Int = 100
        public var tolerance: Double = 1e-10
        public var lineSearchMaxIterations: Int = 50
        public var lineSearchTolerance: Double = 0.0001
        public var gradientTolerance: Double = 1e-10
        
        public init() {}
    }
    
    private var options: Options
    private var hessianApprox: Matrix
    private var dimension: Int
    
    public init(dimension: Int, options: Options = Options()) {
        self.dimension = dimension
        self.options = options
        self.hessianApprox = Matrix.identity(size: dimension)
    }
    
    public func solve(
        initialParams: [Double],
        objective: ([Double]) -> Double,
        gradient: ([Double]) -> [Double]
    ) -> (params: [Double], converged: Bool, iterations: Int) {
        
        var x = initialParams
        var grad = gradient(x)
        var iteration = 0
        
        resetHessian()
        
        while iteration < options.maxIterations {
            let gradNorm = grad.norm()
            
            if gradNorm < options.gradientTolerance {
                return (x, true, iteration)
            }
            
            let searchDirection = computeSearchDirection(grad)
            
            let (stepSize, _) = lineSearch(
                x: x,
                direction: searchDirection,
                objective: objective,
                gradient: gradient,
                currentValue: objective(x),
                currentGradient: grad
            )
            
            if stepSize < 1e-16 {
                return (x, false, iteration)
            }
            
            let xNew = x + stepSize * searchDirection
            let gradNew = gradient(xNew)
            
            let s = stepSize * searchDirection
            let y = gradNew - grad
            
            updateHessian(s: s, y: y)
            
            x = xNew
            grad = gradNew
            iteration += 1
            
            let improvement = s.norm()
            if improvement < options.tolerance {
                return (x, true, iteration)
            }
        }
        
        return (x, false, iteration)
    }
    
    private func resetHessian() {
        hessianApprox = Matrix.identity(size: dimension)
    }
    
    private func computeSearchDirection(_ gradient: [Double]) -> [Double] {
        var result = Array(repeating: 0.0, count: dimension)
        
        for i in 0..<dimension {
            for j in 0..<dimension {
                result[i] -= hessianApprox[i, j] * gradient[j]
            }
        }
        
        return result
    }
    
    private func updateHessian(s: [Double], y: [Double]) {
        let sDotY = s.dot(y)
        
        if sDotY < 1e-10 {
            resetHessian()
            return
        }
        
        let rho = 1.0 / sDotY
        
        var Hs = Array(repeating: 0.0, count: dimension)
        for i in 0..<dimension {
            for j in 0..<dimension {
                Hs[i] += hessianApprox[i, j] * s[j]
            }
        }
        
        let sHs = s.dot(Hs)
        
        for i in 0..<dimension {
            for j in 0..<dimension {
                hessianApprox[i, j] += rho * y[i] * y[j]
                hessianApprox[i, j] -= (1.0 / sHs) * Hs[i] * Hs[j]
            }
        }
    }
    
    private func lineSearch(
        x: [Double],
        direction: [Double],
        objective: ([Double]) -> Double,
        gradient: ([Double]) -> [Double],
        currentValue: Double,
        currentGradient: [Double]
    ) -> (stepSize: Double, value: Double) {
        
        let c1 = options.lineSearchTolerance
        let c2 = 0.9
        
        var alpha = 1.0
        let maxAlpha = 10.0
        let minAlpha = 1e-16
        
        let phi0 = currentValue
        let dPhi0 = currentGradient.dot(direction)
        
        if dPhi0 >= 0 {
            return (0, phi0)
        }
        
        var iteration = 0
        
        while iteration < options.lineSearchMaxIterations {
            let xNew = x + alpha * direction
            let phiAlpha = objective(xNew)
            
            if phiAlpha <= phi0 + c1 * alpha * dPhi0 {
                let gradNew = gradient(xNew)
                let dPhiAlpha = gradNew.dot(direction)
                
                if dPhiAlpha >= c2 * dPhi0 {
                    return (alpha, phiAlpha)
                }
                
                alpha = min(alpha * 2.0, maxAlpha)
            } else {
                alpha = alpha * 0.5
            }
            
            if alpha < minAlpha {
                return (minAlpha, phiAlpha)
            }
            
            iteration += 1
        }
        
        return (alpha, objective(x + alpha * direction))
    }
}