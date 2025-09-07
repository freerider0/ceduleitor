import Foundation

public class ConstraintL2LAngle: Constraint {
    public let type = ConstraintType.angle
    public var parameters: [ParameterRef]
    public var scale: Double = 1.0
    public var tag: Int = 0
    
    public var line1: Line
    public var line2: Line
    public var angle: ParameterRef
    
    public init(line1: Line, line2: Line, angle: ParameterRef) {
        self.line1 = line1
        self.line2 = line2
        self.angle = angle
        self.parameters = [line1.p1.x, line1.p1.y, line1.p2.x, line1.p2.y,
                           line2.p1.x, line2.p1.y, line2.p2.x, line2.p2.y, angle]
    }
    
    public func error() -> Double {
        let dx1 = line1.p2.x.value - line1.p1.x.value
        let dy1 = line1.p2.y.value - line1.p1.y.value
        let dx2 = line2.p2.x.value - line2.p1.x.value
        let dy2 = line2.p2.y.value - line2.p1.y.value
        
        let len1 = sqrt(dx1 * dx1 + dy1 * dy1)
        let len2 = sqrt(dx2 * dx2 + dy2 * dy2)
        
        if len1 < 1e-10 || len2 < 1e-10 {
            return 0
        }
        
        let cosAngle = (dx1 * dx2 + dy1 * dy2) / (len1 * len2)
        let sinAngle = (dx1 * dy2 - dy1 * dx2) / (len1 * len2)
        
        let actualAngle = atan2(sinAngle, cosAngle)
        
        return scale * (actualAngle - angle.value)
    }
    
    public func gradient() -> [Double] {
        let dx1 = line1.p2.x.value - line1.p1.x.value
        let dy1 = line1.p2.y.value - line1.p1.y.value
        let dx2 = line2.p2.x.value - line2.p1.x.value
        let dy2 = line2.p2.y.value - line2.p1.y.value
        
        let len1Sq = dx1 * dx1 + dy1 * dy1
        let len2Sq = dx2 * dx2 + dy2 * dy2
        
        if len1Sq < 1e-10 || len2Sq < 1e-10 {
            return Array(repeating: 0, count: 9)
        }
        
        let dotProduct = dx1 * dx2 + dy1 * dy2
        let crossProduct = dx1 * dy2 - dy1 * dx2
        
        let denom = len1Sq * len2Sq - dotProduct * dotProduct
        if abs(denom) < 1e-10 {
            return Array(repeating: 0, count: 9)
        }
        
        let factor = scale / sqrt(denom)
        
        return [
            factor * (-dy2 * len1Sq + dy1 * dotProduct) / len1Sq,
            factor * (dx2 * len1Sq - dx1 * dotProduct) / len1Sq,
            factor * (dy2 * len1Sq - dy1 * dotProduct) / len1Sq,
            factor * (-dx2 * len1Sq + dx1 * dotProduct) / len1Sq,
            factor * (dy1 * len2Sq - dy2 * dotProduct) / len2Sq,
            factor * (-dx1 * len2Sq + dx2 * dotProduct) / len2Sq,
            factor * (-dy1 * len2Sq + dy2 * dotProduct) / len2Sq,
            factor * (dx1 * len2Sq - dx2 * dotProduct) / len2Sq,
            -scale
        ]
    }
}

public class ConstraintP2PAngle: Constraint {
    public let type = ConstraintType.angle
    public var parameters: [ParameterRef]
    public var scale: Double = 1.0
    public var tag: Int = 0
    
    public var p1: Point
    public var p2: Point
    public var angle: ParameterRef
    
    public init(p1: Point, p2: Point, angle: ParameterRef) {
        self.p1 = p1
        self.p2 = p2
        self.angle = angle
        self.parameters = [p1.x, p1.y, p2.x, p2.y, angle]
    }
    
    public func error() -> Double {
        let dx = p2.x.value - p1.x.value
        let dy = p2.y.value - p1.y.value
        let actualAngle = atan2(dy, dx)
        
        var diff = actualAngle - angle.value
        
        while diff > .pi {
            diff -= 2 * .pi
        }
        while diff < -.pi {
            diff += 2 * .pi
        }
        
        return scale * diff
    }
    
    public func gradient() -> [Double] {
        let dx = p2.x.value - p1.x.value
        let dy = p2.y.value - p1.y.value
        let distSq = dx * dx + dy * dy
        
        if distSq < 1e-10 {
            return [0, 0, 0, 0, -scale]
        }
        
        let factor = scale / distSq
        
        return [
            factor * dy,
            -factor * dx,
            -factor * dy,
            factor * dx,
            -scale
        ]
    }
}

public class ConstraintAngleViaPoint: Constraint {
    public let type = ConstraintType.angle
    public var parameters: [ParameterRef]
    public var scale: Double = 1.0
    public var tag: Int = 0
    
    public var center: Point
    public var p1: Point
    public var p2: Point
    public var angle: ParameterRef
    
    public init(center: Point, p1: Point, p2: Point, angle: ParameterRef) {
        self.center = center
        self.p1 = p1
        self.p2 = p2
        self.angle = angle
        self.parameters = [center.x, center.y, p1.x, p1.y, p2.x, p2.y, angle]
    }
    
    public func error() -> Double {
        let dx1 = p1.x.value - center.x.value
        let dy1 = p1.y.value - center.y.value
        let dx2 = p2.x.value - center.x.value
        let dy2 = p2.y.value - center.y.value
        
        let angle1 = atan2(dy1, dx1)
        let angle2 = atan2(dy2, dx2)
        
        var diff = angle2 - angle1 - angle.value
        
        while diff > .pi {
            diff -= 2 * .pi
        }
        while diff < -.pi {
            diff += 2 * .pi
        }
        
        return scale * diff
    }
    
    public func gradient() -> [Double] {
        let dx1 = p1.x.value - center.x.value
        let dy1 = p1.y.value - center.y.value
        let dx2 = p2.x.value - center.x.value
        let dy2 = p2.y.value - center.y.value
        
        let dist1Sq = dx1 * dx1 + dy1 * dy1
        let dist2Sq = dx2 * dx2 + dy2 * dy2
        
        if dist1Sq < 1e-10 || dist2Sq < 1e-10 {
            return Array(repeating: 0, count: 7)
        }
        
        let factor1 = scale / dist1Sq
        let factor2 = scale / dist2Sq
        
        return [
            factor1 * dy1 - factor2 * dy2,
            -factor1 * dx1 + factor2 * dx2,
            -factor1 * dy1,
            factor1 * dx1,
            factor2 * dy2,
            -factor2 * dx2,
            -scale
        ]
    }
}