import Foundation

public enum ConstraintType {
    case equal
    case difference
    case distance
    case angle
    case parallel
    case perpendicular
    case tangent
    case pointOnLine
    case pointOnCircle
    case pointOnCurve
    case symmetric
    case midpoint
    case horizontal
    case vertical
    case coincident
    case internalAlignment
    case snell
}

public protocol Constraint: AnyObject {
    var type: ConstraintType { get }
    var parameters: [ParameterRef] { get }
    var scale: Double { get set }
    var tag: Int { get set }
    
    func error() -> Double
    func gradient() -> [Double]
    func rescale()
}

public extension Constraint {
    func rescale() {
        let err = abs(error())
        if err > 1e-10 {
            scale = 1.0 / err
        } else {
            scale = 1.0
        }
    }
}

public class ConstraintEqual: Constraint {
    public let type = ConstraintType.equal
    public var parameters: [ParameterRef]
    public var scale: Double = 1.0
    public var tag: Int = 0
    
    public var param1: ParameterRef
    public var param2: ParameterRef
    
    public init(param1: ParameterRef, param2: ParameterRef) {
        self.param1 = param1
        self.param2 = param2
        self.parameters = [param1, param2]
    }
    
    public func error() -> Double {
        return scale * (param1.value - param2.value)
    }
    
    public func gradient() -> [Double] {
        return [scale, -scale]
    }
}

public class ConstraintDifference: Constraint {
    public let type = ConstraintType.difference
    public var parameters: [ParameterRef]
    public var scale: Double = 1.0
    public var tag: Int = 0
    
    public var param1: ParameterRef
    public var param2: ParameterRef
    public var difference: ParameterRef
    
    public init(param1: ParameterRef, param2: ParameterRef, difference: ParameterRef) {
        self.param1 = param1
        self.param2 = param2
        self.difference = difference
        self.parameters = [param1, param2, difference]
    }
    
    public func error() -> Double {
        return scale * (param1.value - param2.value - difference.value)
    }
    
    public func gradient() -> [Double] {
        return [scale, -scale, -scale]
    }
}

public class ConstraintP2PDistance: Constraint {
    public let type = ConstraintType.distance
    public var parameters: [ParameterRef]
    public var scale: Double = 1.0
    public var tag: Int = 0
    
    public var p1: Point
    public var p2: Point
    public var distance: ParameterRef
    
    public init(p1: Point, p2: Point, distance: ParameterRef) {
        self.p1 = p1
        self.p2 = p2
        self.distance = distance
        self.parameters = [p1.x, p1.y, p2.x, p2.y, distance]
    }
    
    public func error() -> Double {
        let dx = p1.x.value - p2.x.value
        let dy = p1.y.value - p2.y.value
        let currentDist = sqrt(dx * dx + dy * dy)
        return scale * (currentDist - distance.value)
    }
    
    public func gradient() -> [Double] {
        let dx = p1.x.value - p2.x.value
        let dy = p1.y.value - p2.y.value
        let currentDist = sqrt(dx * dx + dy * dy)
        
        if currentDist < 1e-10 {
            return [0, 0, 0, 0, -scale]
        }
        
        let factor = scale / currentDist
        return [
            factor * dx,
            factor * dy,
            -factor * dx,
            -factor * dy,
            -scale
        ]
    }
}

public class ConstraintP2LDistance: Constraint {
    public let type = ConstraintType.distance
    public var parameters: [ParameterRef]
    public var scale: Double = 1.0
    public var tag: Int = 0
    
    public var point: Point
    public var line: Line
    public var distance: ParameterRef
    
    public init(point: Point, line: Line, distance: ParameterRef) {
        self.point = point
        self.line = line
        self.distance = distance
        self.parameters = [point.x, point.y, line.p1.x, line.p1.y, line.p2.x, line.p2.y, distance]
    }
    
    public func error() -> Double {
        let currentDist = line.distanceToPoint(point)
        return scale * (currentDist - distance.value)
    }
    
    public func gradient() -> [Double] {
        let A = line.p2.y.value - line.p1.y.value
        let B = line.p1.x.value - line.p2.x.value
        let C = line.p2.x.value * line.p1.y.value - line.p1.x.value * line.p2.y.value
        
        let denominator = sqrt(A * A + B * B)
        if denominator < 1e-10 {
            return [0, 0, 0, 0, 0, 0, -scale]
        }
        
        let distValue = A * point.x.value + B * point.y.value + C
        let sign = distValue >= 0 ? 1.0 : -1.0
        let factor = scale * sign / denominator
        
        return [
            factor * A / denominator,
            factor * B / denominator,
            factor * (point.y.value - line.p2.y.value) / denominator,
            factor * (line.p2.x.value - point.x.value) / denominator,
            factor * (line.p1.y.value - point.y.value) / denominator,
            factor * (point.x.value - line.p1.x.value) / denominator,
            -scale
        ]
    }
}

public class ConstraintPointOnLine: Constraint {
    public let type = ConstraintType.pointOnLine
    public var parameters: [ParameterRef]
    public var scale: Double = 1.0
    public var tag: Int = 0
    
    public var point: Point
    public var line: Line
    
    public init(point: Point, line: Line) {
        self.point = point
        self.line = line
        self.parameters = [point.x, point.y, line.p1.x, line.p1.y, line.p2.x, line.p2.y]
    }
    
    public func error() -> Double {
        let A = line.p2.y.value - line.p1.y.value
        let B = line.p1.x.value - line.p2.x.value
        let C = line.p2.x.value * line.p1.y.value - line.p1.x.value * line.p2.y.value
        
        return scale * (A * point.x.value + B * point.y.value + C)
    }
    
    public func gradient() -> [Double] {
        let A = line.p2.y.value - line.p1.y.value
        let B = line.p1.x.value - line.p2.x.value
        
        return [
            scale * A,
            scale * B,
            scale * (point.y.value - line.p2.y.value),
            scale * (line.p2.x.value - point.x.value),
            scale * (line.p1.y.value - point.y.value),
            scale * (point.x.value - line.p1.x.value)
        ]
    }
}

public class ConstraintParallel: Constraint {
    public let type = ConstraintType.parallel
    public var parameters: [ParameterRef]
    public var scale: Double = 1.0
    public var tag: Int = 0
    
    public var line1: Line
    public var line2: Line
    
    public init(line1: Line, line2: Line) {
        self.line1 = line1
        self.line2 = line2
        self.parameters = [line1.p1.x, line1.p1.y, line1.p2.x, line1.p2.y,
                           line2.p1.x, line2.p1.y, line2.p2.x, line2.p2.y]
    }
    
    public func error() -> Double {
        let dx1 = line1.p2.x.value - line1.p1.x.value
        let dy1 = line1.p2.y.value - line1.p1.y.value
        let dx2 = line2.p2.x.value - line2.p1.x.value
        let dy2 = line2.p2.y.value - line2.p1.y.value
        
        return scale * (dx1 * dy2 - dy1 * dx2)
    }
    
    public func gradient() -> [Double] {
        let dy2 = line2.p2.y.value - line2.p1.y.value
        let dx2 = line2.p2.x.value - line2.p1.x.value
        let dy1 = line1.p2.y.value - line1.p1.y.value
        let dx1 = line1.p2.x.value - line1.p1.x.value
        
        return [
            -scale * dy2,
            scale * dx2,
            scale * dy2,
            -scale * dx2,
            scale * dy1,
            -scale * dx1,
            -scale * dy1,
            scale * dx1
        ]
    }
}

public class ConstraintPerpendicular: Constraint {
    public let type = ConstraintType.perpendicular
    public var parameters: [ParameterRef]
    public var scale: Double = 1.0
    public var tag: Int = 0
    
    public var line1: Line
    public var line2: Line
    
    public init(line1: Line, line2: Line) {
        self.line1 = line1
        self.line2 = line2
        self.parameters = [line1.p1.x, line1.p1.y, line1.p2.x, line1.p2.y,
                           line2.p1.x, line2.p1.y, line2.p2.x, line2.p2.y]
    }
    
    public func error() -> Double {
        let dx1 = line1.p2.x.value - line1.p1.x.value
        let dy1 = line1.p2.y.value - line1.p1.y.value
        let dx2 = line2.p2.x.value - line2.p1.x.value
        let dy2 = line2.p2.y.value - line2.p1.y.value
        
        return scale * (dx1 * dx2 + dy1 * dy2)
    }
    
    public func gradient() -> [Double] {
        let dx2 = line2.p2.x.value - line2.p1.x.value
        let dy2 = line2.p2.y.value - line2.p1.y.value
        let dx1 = line1.p2.x.value - line1.p1.x.value
        let dy1 = line1.p2.y.value - line1.p1.y.value
        
        return [
            -scale * dx2,
            -scale * dy2,
            scale * dx2,
            scale * dy2,
            -scale * dx1,
            -scale * dy1,
            scale * dx1,
            scale * dy1
        ]
    }
}