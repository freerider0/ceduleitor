import Foundation

public class ConstraintPointOnCircle: Constraint {
    public let type = ConstraintType.pointOnCircle
    public var parameters: [ParameterRef]
    public var scale: Double = 1.0
    public var tag: Int = 0
    
    public var point: Point
    public var circle: Circle
    
    public init(point: Point, circle: Circle) {
        self.point = point
        self.circle = circle
        self.parameters = [point.x, point.y, circle.center.x, circle.center.y, circle.radius]
    }
    
    public func error() -> Double {
        let dx = point.x.value - circle.center.x.value
        let dy = point.y.value - circle.center.y.value
        let dist = sqrt(dx * dx + dy * dy)
        return scale * (dist - circle.radius.value)
    }
    
    public func gradient() -> [Double] {
        let dx = point.x.value - circle.center.x.value
        let dy = point.y.value - circle.center.y.value
        let dist = sqrt(dx * dx + dy * dy)
        
        if dist < 1e-10 {
            return [0, 0, 0, 0, -scale]
        }
        
        let factor = scale / dist
        
        return [
            factor * dx,
            factor * dy,
            -factor * dx,
            -factor * dy,
            -scale
        ]
    }
}

public class ConstraintPointOnEllipse: Constraint {
    public let type = ConstraintType.pointOnCurve
    public var parameters: [ParameterRef]
    public var scale: Double = 1.0
    public var tag: Int = 0
    
    public var point: Point
    public var ellipse: Ellipse
    
    public init(point: Point, ellipse: Ellipse) {
        self.point = point
        self.ellipse = ellipse
        self.parameters = [point.x, point.y, ellipse.center.x, ellipse.center.y,
                           ellipse.focus1.x, ellipse.focus1.y, ellipse.radmin]
    }
    
    public func error() -> Double {
        let theta = ellipse.rotation
        let cos_theta = cos(theta)
        let sin_theta = sin(theta)
        
        let dx = point.x.value - ellipse.center.x.value
        let dy = point.y.value - ellipse.center.y.value
        
        let x_local = dx * cos_theta + dy * sin_theta
        let y_local = -dx * sin_theta + dy * cos_theta
        
        let a = ellipse.majorRadius
        let b = ellipse.minorRadius
        
        let result = (x_local * x_local) / (a * a) + (y_local * y_local) / (b * b) - 1.0
        return scale * result
    }
    
    public func gradient() -> [Double] {
        let theta = ellipse.rotation
        let cos_theta = cos(theta)
        let sin_theta = sin(theta)
        
        let dx = point.x.value - ellipse.center.x.value
        let dy = point.y.value - ellipse.center.y.value
        
        let x_local = dx * cos_theta + dy * sin_theta
        let y_local = -dx * sin_theta + dy * cos_theta
        
        let a = ellipse.majorRadius
        let b = ellipse.minorRadius
        
        let dF_dx_local = 2 * x_local / (a * a)
        let dF_dy_local = 2 * y_local / (b * b)
        
        let dF_dx = scale * (dF_dx_local * cos_theta - dF_dy_local * sin_theta)
        let dF_dy = scale * (dF_dx_local * sin_theta + dF_dy_local * cos_theta)
        
        return [
            dF_dx,
            dF_dy,
            -dF_dx,
            -dF_dy,
            0,
            0,
            0
        ]
    }
}

public class ConstraintPointOnHyperbola: Constraint {
    public let type = ConstraintType.pointOnCurve
    public var parameters: [ParameterRef]
    public var scale: Double = 1.0
    public var tag: Int = 0
    
    public var point: Point
    public var hyperbola: Hyperbola
    
    public init(point: Point, hyperbola: Hyperbola) {
        self.point = point
        self.hyperbola = hyperbola
        self.parameters = [point.x, point.y, hyperbola.center.x, hyperbola.center.y,
                           hyperbola.focus1.x, hyperbola.focus1.y, hyperbola.radmin]
    }
    
    public func error() -> Double {
        let theta = hyperbola.rotation
        let cos_theta = cos(theta)
        let sin_theta = sin(theta)
        
        let dx = point.x.value - hyperbola.center.x.value
        let dy = point.y.value - hyperbola.center.y.value
        
        let x_local = dx * cos_theta + dy * sin_theta
        let y_local = -dx * sin_theta + dy * cos_theta
        
        let a = hyperbola.majorRadius
        let b = hyperbola.minorRadius
        
        let result = (x_local * x_local) / (a * a) - (y_local * y_local) / (b * b) - 1.0
        return scale * result
    }
    
    public func gradient() -> [Double] {
        let theta = hyperbola.rotation
        let cos_theta = cos(theta)
        let sin_theta = sin(theta)
        
        let dx = point.x.value - hyperbola.center.x.value
        let dy = point.y.value - hyperbola.center.y.value
        
        let x_local = dx * cos_theta + dy * sin_theta
        let y_local = -dx * sin_theta + dy * cos_theta
        
        let a = hyperbola.majorRadius
        let b = hyperbola.minorRadius
        
        let dF_dx_local = 2 * x_local / (a * a)
        let dF_dy_local = -2 * y_local / (b * b)
        
        let dF_dx = scale * (dF_dx_local * cos_theta - dF_dy_local * sin_theta)
        let dF_dy = scale * (dF_dx_local * sin_theta + dF_dy_local * cos_theta)
        
        return [
            dF_dx,
            dF_dy,
            -dF_dx,
            -dF_dy,
            0,
            0,
            0
        ]
    }
}

public class ConstraintPointOnParabola: Constraint {
    public let type = ConstraintType.pointOnCurve
    public var parameters: [ParameterRef]
    public var scale: Double = 1.0
    public var tag: Int = 0
    
    public var point: Point
    public var parabola: Parabola
    
    public init(point: Point, parabola: Parabola) {
        self.point = point
        self.parabola = parabola
        self.parameters = [point.x, point.y, parabola.vertex.x, parabola.vertex.y,
                           parabola.focus.x, parabola.focus.y]
    }
    
    public func error() -> Double {
        let theta = parabola.rotation
        let cos_theta = cos(theta)
        let sin_theta = sin(theta)
        
        let dx = point.x.value - parabola.vertex.x.value
        let dy = point.y.value - parabola.vertex.y.value
        
        let x_local = dx * cos_theta + dy * sin_theta
        let y_local = -dx * sin_theta + dy * cos_theta
        
        let p = parabola.focalLength
        let result = x_local - y_local * y_local / (4 * p)
        
        return scale * result
    }
    
    public func gradient() -> [Double] {
        let theta = parabola.rotation
        let cos_theta = cos(theta)
        let sin_theta = sin(theta)
        
        let dx = point.x.value - parabola.vertex.x.value
        let dy = point.y.value - parabola.vertex.y.value
        
        let y_local = -dx * sin_theta + dy * cos_theta
        let p = parabola.focalLength
        
        let dF_dx_local = 1.0
        let dF_dy_local = -y_local / (2 * p)
        
        let dF_dx = scale * (dF_dx_local * cos_theta - dF_dy_local * sin_theta)
        let dF_dy = scale * (dF_dx_local * sin_theta + dF_dy_local * cos_theta)
        
        return [
            dF_dx,
            dF_dy,
            -dF_dx,
            -dF_dy,
            0,
            0
        ]
    }
}

public class ConstraintTangentCircumf: Constraint {
    public let type = ConstraintType.tangent
    public var parameters: [ParameterRef]
    public var scale: Double = 1.0
    public var tag: Int = 0
    
    public var circle1: Circle
    public var circle2: Circle
    public var `internal`: Bool
    
    public init(circle1: Circle, circle2: Circle, internal: Bool = false) {
        self.circle1 = circle1
        self.circle2 = circle2
        self.`internal` = `internal`
        self.parameters = [circle1.center.x, circle1.center.y, circle1.radius,
                           circle2.center.x, circle2.center.y, circle2.radius]
    }
    
    public func error() -> Double {
        let dx = circle2.center.x.value - circle1.center.x.value
        let dy = circle2.center.y.value - circle1.center.y.value
        let dist = sqrt(dx * dx + dy * dy)
        
        if `internal` {
            return scale * (dist - abs(circle1.radius.value - circle2.radius.value))
        } else {
            return scale * (dist - (circle1.radius.value + circle2.radius.value))
        }
    }
    
    public func gradient() -> [Double] {
        let dx = circle2.center.x.value - circle1.center.x.value
        let dy = circle2.center.y.value - circle1.center.y.value
        let dist = sqrt(dx * dx + dy * dy)
        
        if dist < 1e-10 {
            return [0, 0, 0, 0, 0, 0]
        }
        
        let factor = scale / dist
        
        if `internal` {
            let sign = circle1.radius.value > circle2.radius.value ? 1.0 : -1.0
            return [
                -factor * dx,
                -factor * dy,
                -scale * sign,
                factor * dx,
                factor * dy,
                scale * sign
            ]
        } else {
            return [
                -factor * dx,
                -factor * dy,
                -scale,
                factor * dx,
                factor * dy,
                -scale
            ]
        }
    }
}

public class ConstraintCurveValue: Constraint {
    public let type = ConstraintType.pointOnCurve
    public var parameters: [ParameterRef]
    public var scale: Double = 1.0
    public var tag: Int = 0
    
    public var curve: Curve
    public var u: ParameterRef
    public var point: Point
    
    public init(curve: Curve, u: ParameterRef, point: Point) {
        self.curve = curve
        self.u = u
        self.point = point
        self.parameters = [u, point.x, point.y]
    }
    
    public func error() -> Double {
        let curvePoint = curve.value(u.value, deriv: 0)
        let dx = curvePoint.x - point.x.value
        let dy = curvePoint.y - point.y.value
        return scale * sqrt(dx * dx + dy * dy)
    }
    
    public func gradient() -> [Double] {
        let curvePoint = curve.value(u.value, deriv: 1)
        let dx = curvePoint.x - point.x.value
        let dy = curvePoint.y - point.y.value
        let dist = sqrt(dx * dx + dy * dy)
        
        if dist < 1e-10 {
            return [0, 0, 0]
        }
        
        let factor = scale / dist
        
        return [
            factor * (curvePoint.dx * dx + curvePoint.dy * dy),
            -factor * dx,
            -factor * dy
        ]
    }
}

public class ConstraintSnell: Constraint {
    public let type = ConstraintType.snell
    public var parameters: [ParameterRef]
    public var scale: Double = 1.0
    public var tag: Int = 0
    
    public var line1: Line
    public var line2: Line
    public var boundary: Line
    public var n1: ParameterRef
    public var n2: ParameterRef
    
    public init(line1: Line, line2: Line, boundary: Line, n1: ParameterRef, n2: ParameterRef) {
        self.line1 = line1
        self.line2 = line2
        self.boundary = boundary
        self.n1 = n1
        self.n2 = n2
        self.parameters = [line1.p1.x, line1.p1.y, line1.p2.x, line1.p2.y,
                           line2.p1.x, line2.p1.y, line2.p2.x, line2.p2.y,
                           boundary.p1.x, boundary.p1.y, boundary.p2.x, boundary.p2.y,
                           n1, n2]
    }
    
    public func error() -> Double {
        let boundaryNormal = boundary.normal(0)
        let dir1 = line1.direction
        let dir2 = line2.direction
        
        let sin1 = abs(dir1.x * boundaryNormal.x + dir1.y * boundaryNormal.y)
        let sin2 = abs(dir2.x * boundaryNormal.x + dir2.y * boundaryNormal.y)
        
        return scale * (n1.value * sin1 - n2.value * sin2)
    }
    
    public func gradient() -> [Double] {
        return Array(repeating: 0, count: 14)
    }
}