import Foundation

public protocol Curve: AnyObject {
    func value(_ u: Double, deriv: Int) -> DeriVector2
    func normal(_ u: Double) -> SIMD2<Double>
    func tangent(_ u: Double) -> SIMD2<Double>
}

public extension Curve {
    func normal(_ u: Double) -> SIMD2<Double> {
        let d = value(u, deriv: 1)
        let tangent = SIMD2(d.dx, d.dy)
        let length = sqrt(tangent.x * tangent.x + tangent.y * tangent.y)
        if length > 1e-10 {
            return SIMD2(-tangent.y / length, tangent.x / length)
        }
        return SIMD2(0, 0)
    }
    
    func tangent(_ u: Double) -> SIMD2<Double> {
        let d = value(u, deriv: 1)
        let tangent = SIMD2(d.dx, d.dy)
        let length = sqrt(tangent.x * tangent.x + tangent.y * tangent.y)
        if length > 1e-10 {
            return tangent / length
        }
        return SIMD2(0, 0)
    }
}