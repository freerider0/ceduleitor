import Foundation

public class Ellipse: Curve {
    public var center: Point
    public var focus1: Point
    public var radmin: ParameterRef
    
    public init(center: Point, focus1: Point, radmin: ParameterRef) {
        self.center = center
        self.focus1 = focus1
        self.radmin = radmin
    }
    
    public var majorRadius: Double {
        let c = center.distance(to: focus1)
        let b = radmin.value
        return sqrt(c * c + b * b)
    }
    
    public var minorRadius: Double {
        radmin.value
    }
    
    public var eccentricity: Double {
        let c = center.distance(to: focus1)
        let a = majorRadius
        return c / a
    }
    
    public var rotation: Double {
        atan2(focus1.y.value - center.y.value, focus1.x.value - center.x.value)
    }
    
    public func value(_ u: Double, deriv: Int) -> DeriVector2 {
        let a = majorRadius
        let b = minorRadius
        let theta = rotation
        
        let cos_u = cos(u)
        let sin_u = sin(u)
        let cos_theta = cos(theta)
        let sin_theta = sin(theta)
        
        let x_local = a * cos_u
        let y_local = b * sin_u
        
        let x = center.x.value + x_local * cos_theta - y_local * sin_theta
        let y = center.y.value + x_local * sin_theta + y_local * cos_theta
        
        if deriv == 0 {
            return DeriVector2(x: x, y: y, dx: 0, dy: 0)
        } else {
            let dx_local = -a * sin_u
            let dy_local = b * cos_u
            
            let dx = dx_local * cos_theta - dy_local * sin_theta
            let dy = dx_local * sin_theta + dy_local * cos_theta
            
            return DeriVector2(x: x, y: y, dx: dx, dy: dy)
        }
    }
    
    public func containsPoint(_ point: Point) -> Bool {
        let theta = rotation
        let cos_theta = cos(theta)
        let sin_theta = sin(theta)
        
        let dx = point.x.value - center.x.value
        let dy = point.y.value - center.y.value
        
        let x_local = dx * cos_theta + dy * sin_theta
        let y_local = -dx * sin_theta + dy * cos_theta
        
        let a = majorRadius
        let b = minorRadius
        
        let result = (x_local * x_local) / (a * a) + (y_local * y_local) / (b * b)
        return abs(result - 1.0) < 1e-10
    }
}

public class ArcOfEllipse: Ellipse {
    public var startAngle: ParameterRef
    public var endAngle: ParameterRef
    public var startPoint: Point
    public var endPoint: Point
    
    public init(center: Point, focus1: Point, radmin: ParameterRef,
                startAngle: ParameterRef, endAngle: ParameterRef,
                startPoint: Point, endPoint: Point) {
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.startPoint = startPoint
        self.endPoint = endPoint
        super.init(center: center, focus1: focus1, radmin: radmin)
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