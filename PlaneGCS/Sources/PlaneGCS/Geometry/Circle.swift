import Foundation

public class Circle: Curve {
    public var center: Point
    public var radius: ParameterRef
    
    public init(center: Point, radius: ParameterRef) {
        self.center = center
        self.radius = radius
    }
    
    public convenience init(center: Point, radius: Double) {
        self.init(center: center, radius: ParameterRef(radius))
    }
    
    public func value(_ u: Double, deriv: Int) -> DeriVector2 {
        let cos_u = cos(u)
        let sin_u = sin(u)
        
        let x = center.x.value + radius.value * cos_u
        let y = center.y.value + radius.value * sin_u
        
        if deriv == 0 {
            return DeriVector2(x: x, y: y, dx: 0, dy: 0)
        } else {
            let dx = -radius.value * sin_u
            let dy = radius.value * cos_u
            return DeriVector2(x: x, y: y, dx: dx, dy: dy)
        }
    }
    
    public func containsPoint(_ point: Point) -> Bool {
        let distance = point.distance(to: center)
        return abs(distance - radius.value) < 1e-10
    }
    
    public func distanceToPoint(_ point: Point) -> Double {
        let distance = point.distance(to: center)
        return abs(distance - radius.value)
    }
}

public class Arc: Circle {
    public var startAngle: ParameterRef
    public var endAngle: ParameterRef
    public var startPoint: Point
    public var endPoint: Point
    
    public init(center: Point, radius: ParameterRef, 
                startAngle: ParameterRef, endAngle: ParameterRef,
                startPoint: Point, endPoint: Point) {
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.startPoint = startPoint
        self.endPoint = endPoint
        super.init(center: center, radius: radius)
    }
    
    public func angleInRange(_ angle: Double) -> Bool {
        var normalizedAngle = angle.truncatingRemainder(dividingBy: 2 * .pi)
        if normalizedAngle < 0 {
            normalizedAngle += 2 * .pi
        }
        
        var start = startAngle.value.truncatingRemainder(dividingBy: 2 * .pi)
        var end = endAngle.value.truncatingRemainder(dividingBy: 2 * .pi)
        
        if start < 0 { start += 2 * .pi }
        if end < 0 { end += 2 * .pi }
        
        if start <= end {
            return normalizedAngle >= start && normalizedAngle <= end
        } else {
            return normalizedAngle >= start || normalizedAngle <= end
        }
    }
}