import Foundation

public class BSpline: Curve {
    public var poles: [Point]
    public var weights: [ParameterRef]
    public var knots: [Double]
    public var degree: Int
    public var periodic: Bool
    public var startPoint: Point?
    public var endPoint: Point?
    
    public init(poles: [Point], weights: [ParameterRef], knots: [Double], 
                degree: Int, periodic: Bool = false,
                startPoint: Point? = nil, endPoint: Point? = nil) {
        self.poles = poles
        self.weights = weights
        self.knots = knots
        self.degree = degree
        self.periodic = periodic
        self.startPoint = startPoint
        self.endPoint = endPoint
    }
    
    private func findKnotSpan(_ u: Double) -> Int {
        let n = poles.count - 1
        
        if u >= knots[n + 1] {
            return n
        }
        if u <= knots[degree] {
            return degree
        }
        
        var low = degree
        var high = n + 1
        var mid = (low + high) / 2
        
        while u < knots[mid] || u >= knots[mid + 1] {
            if u < knots[mid] {
                high = mid
            } else {
                low = mid
            }
            mid = (low + high) / 2
        }
        
        return mid
    }
    
    private func basisFunctions(_ span: Int, _ u: Double) -> [Double] {
        var N = Array(repeating: 0.0, count: degree + 1)
        var left = Array(repeating: 0.0, count: degree + 1)
        var right = Array(repeating: 0.0, count: degree + 1)
        
        N[0] = 1.0
        
        for j in 1...degree {
            left[j] = u - knots[span + 1 - j]
            right[j] = knots[span + j] - u
            
            var saved = 0.0
            for r in 0..<j {
                let temp = N[r] / (right[r + 1] + left[j - r])
                N[r] = saved + right[r + 1] * temp
                saved = left[j - r] * temp
            }
            N[j] = saved
        }
        
        return N
    }
    
    private func basisFunctionsDerivatives(_ span: Int, _ u: Double, _ n: Int) -> [[Double]] {
        var ders = Array(repeating: Array(repeating: 0.0, count: degree + 1), count: n + 1)
        var ndu = Array(repeating: Array(repeating: 0.0, count: degree + 1), count: degree + 1)
        var left = Array(repeating: 0.0, count: degree + 1)
        var right = Array(repeating: 0.0, count: degree + 1)
        
        ndu[0][0] = 1.0
        
        for j in 1...degree {
            left[j] = u - knots[span + 1 - j]
            right[j] = knots[span + j] - u
            
            var saved = 0.0
            for r in 0..<j {
                ndu[j][r] = right[r + 1] + left[j - r]
                let temp = ndu[r][j - 1] / ndu[j][r]
                ndu[r][j] = saved + right[r + 1] * temp
                saved = left[j - r] * temp
            }
            ndu[j][j] = saved
        }
        
        for j in 0...degree {
            ders[0][j] = ndu[j][degree]
        }
        
        for r in 0...degree {
            var s1 = 0
            var s2 = 1
            var a = Array(repeating: Array(repeating: 0.0, count: degree + 1), count: 2)
            
            a[0][0] = 1.0
            
            for k in 1...min(n, degree) {
                var d = 0.0
                let rk = r - k
                let pk = degree - k
                
                if r >= k {
                    a[s2][0] = a[s1][0] / ndu[pk + 1][rk]
                    d = a[s2][0] * ndu[rk][pk]
                }
                
                let j1 = rk >= -1 ? 1 : -rk
                let j2 = (r - 1) <= pk ? k - 1 : degree - r
                
                for j in j1...j2 {
                    a[s2][j] = (a[s1][j] - a[s1][j - 1]) / ndu[pk + 1][rk + j]
                    d += a[s2][j] * ndu[rk + j][pk]
                }
                
                if r <= pk {
                    a[s2][k] = -a[s1][k - 1] / ndu[pk + 1][r]
                    d += a[s2][k] * ndu[r][pk]
                }
                
                ders[k][r] = d
                
                let temp = s1
                s1 = s2
                s2 = temp
            }
        }
        
        var r = Double(degree)
        for k in 1...n {
            for j in 0...degree {
                ders[k][j] *= r
            }
            r *= Double(degree - k)
        }
        
        return ders
    }
    
    public func value(_ u: Double, deriv: Int) -> DeriVector2 {
        let span = findKnotSpan(u)
        let ders = basisFunctionsDerivatives(span, u, min(deriv, 1))
        
        var x = 0.0
        var y = 0.0
        var dx = 0.0
        var dy = 0.0
        var w = 0.0
        var dw = 0.0
        
        for i in 0...degree {
            let poleIndex = span - degree + i
            if poleIndex >= 0 && poleIndex < poles.count {
                let pole = poles[poleIndex]
                let weight = weights.isEmpty ? 1.0 : weights[poleIndex].value
                
                x += ders[0][i] * pole.x.value * weight
                y += ders[0][i] * pole.y.value * weight
                w += ders[0][i] * weight
                
                if deriv > 0 {
                    dx += ders[1][i] * pole.x.value * weight
                    dy += ders[1][i] * pole.y.value * weight
                    dw += ders[1][i] * weight
                }
            }
        }
        
        if w > 1e-10 {
            x /= w
            y /= w
            
            if deriv > 0 {
                dx = (dx - x * dw) / w
                dy = (dy - y * dw) / w
            }
        }
        
        return DeriVector2(x: x, y: y, dx: dx, dy: dy)
    }
}