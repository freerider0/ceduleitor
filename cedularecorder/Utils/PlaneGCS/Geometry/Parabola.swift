import Foundation

public class Parabola: Curve {
    public var vertex: Point
    public var focus: Point
    
    public init(vertex: Point, focus: Point) {
        self.vertex = vertex
        self.focus = focus
    }
    
    public var focalLength: Double {
        vertex.distance(to: focus)
    }
    
    public var axis: SIMD2<Double> {
        let dx = focus.x.value - vertex.x.value
        let dy = focus.y.value - vertex.y.value
        let length = sqrt(dx * dx + dy * dy)
        if length > 1e-10 {
            return SIMD2(dx / length, dy / length)
        }
        return SIMD2(1, 0)
    }
    
    public var rotation: Double {
        atan2(focus.y.value - vertex.y.value, focus.x.value - vertex.x.value)
    }
    
    public func value(_ t: Double, deriv: Int) -> DeriVector2 {
        let p = focalLength
        let theta = rotation
        let cos_theta = cos(theta)
        let sin_theta = sin(theta)
        
        let x_local = t * t / (4 * p)
        let y_local = t
        
        let x = vertex.x.value + x_local * cos_theta - y_local * sin_theta
        let y = vertex.y.value + x_local * sin_theta + y_local * cos_theta
        
        if deriv == 0 {
            return DeriVector2(x: x, y: y, dx: 0, dy: 0)
        } else {
            let dx_local = t / (2 * p)
            let dy_local = 1.0
            
            let dx = dx_local * cos_theta - dy_local * sin_theta
            let dy = dx_local * sin_theta + dy_local * cos_theta
            
            return DeriVector2(x: x, y: y, dx: dx, dy: dy)
        }
    }
    
    public func containsPoint(_ point: Point) -> Bool {
        let theta = rotation
        let cos_theta = cos(theta)
        let sin_theta = sin(theta)
        
        let dx = point.x.value - vertex.x.value
        let dy = point.y.value - vertex.y.value
        
        let x_local = dx * cos_theta + dy * sin_theta
        let y_local = -dx * sin_theta + dy * cos_theta
        
        let p = focalLength
        let expected_x = y_local * y_local / (4 * p)
        
        return abs(x_local - expected_x) < 1e-10
    }
}

public class ArcOfParabola: Parabola {
    public var startParam: ParameterRef
    public var endParam: ParameterRef
    public var startPoint: Point
    public var endPoint: Point
    
    public init(vertex: Point, focus: Point,
                startParam: ParameterRef, endParam: ParameterRef,
                startPoint: Point, endPoint: Point) {
        self.startParam = startParam
        self.endParam = endParam
        self.startPoint = startPoint
        self.endPoint = endPoint
        super.init(vertex: vertex, focus: focus)
    }
    
    public func paramInRange(_ param: Double) -> Bool {
        let start = startParam.value
        let end = endParam.value
        
        if start <= end {
            return param >= start && param <= end
        } else {
            return false
        }
    }
}