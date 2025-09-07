import Foundation

public class Line: Curve {
    public var p1: Point
    public var p2: Point
    
    public init(p1: Point, p2: Point) {
        self.p1 = p1
        self.p2 = p2
    }
    
    public func value(_ u: Double, deriv: Int) -> DeriVector2 {
        let x = p1.x.value + u * (p2.x.value - p1.x.value)
        let y = p1.y.value + u * (p2.y.value - p1.y.value)
        
        if deriv == 0 {
            return DeriVector2(x: x, y: y, dx: 0, dy: 0)
        } else {
            let dx = p2.x.value - p1.x.value
            let dy = p2.y.value - p1.y.value
            return DeriVector2(x: x, y: y, dx: dx, dy: dy)
        }
    }
    
    public var direction: SIMD2<Double> {
        let dx = p2.x.value - p1.x.value
        let dy = p2.y.value - p1.y.value
        let length = sqrt(dx * dx + dy * dy)
        if length > 1e-10 {
            return SIMD2(dx / length, dy / length)
        }
        return SIMD2(0, 0)
    }
    
    public func distanceToPoint(_ point: Point) -> Double {
        let A = p2.y.value - p1.y.value
        let B = p1.x.value - p2.x.value
        let C = p2.x.value * p1.y.value - p1.x.value * p2.y.value
        
        let denominator = sqrt(A * A + B * B)
        if denominator < 1e-10 {
            return point.distance(to: p1)
        }
        
        return abs(A * point.x.value + B * point.y.value + C) / denominator
    }
    
    public func closestParameter(to point: Point) -> Double {
        let dx = p2.x.value - p1.x.value
        let dy = p2.y.value - p1.y.value
        let lengthSquared = dx * dx + dy * dy
        
        if lengthSquared < 1e-10 {
            return 0
        }
        
        let t = ((point.x.value - p1.x.value) * dx + (point.y.value - p1.y.value) * dy) / lengthSquared
        return max(0, min(1, t))
    }
}