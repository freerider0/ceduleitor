import Foundation

public class Hyperbola: Curve {
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
        return sqrt(abs(c * c - b * b))
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
        
        let cosh_u = cosh(u)
        let sinh_u = sinh(u)
        let cos_theta = cos(theta)
        let sin_theta = sin(theta)
        
        let x_local = a * cosh_u
        let y_local = b * sinh_u
        
        let x = center.x.value + x_local * cos_theta - y_local * sin_theta
        let y = center.y.value + x_local * sin_theta + y_local * cos_theta
        
        if deriv == 0 {
            return DeriVector2(x: x, y: y, dx: 0, dy: 0)
        } else {
            let dx_local = a * sinh_u
            let dy_local = b * cosh_u
            
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
        
        let result = (x_local * x_local) / (a * a) - (y_local * y_local) / (b * b)
        return abs(result - 1.0) < 1e-10
    }
}

public class ArcOfHyperbola: Hyperbola {
    public var startParam: ParameterRef
    public var endParam: ParameterRef
    public var startPoint: Point
    public var endPoint: Point
    
    public init(center: Point, focus1: Point, radmin: ParameterRef,
                startParam: ParameterRef, endParam: ParameterRef,
                startPoint: Point, endPoint: Point) {
        self.startParam = startParam
        self.endParam = endParam
        self.startPoint = startPoint
        self.endPoint = endPoint
        super.init(center: center, focus1: focus1, radmin: radmin)
    }
    
    public func paramInRange(_ param: Double) -> Bool {
        let start = startParam.value
        let end = endParam.value
        
        if start <= end {
            return param >= start && param <= end
        } else {
            return param >= start || param <= end
        }
    }
}