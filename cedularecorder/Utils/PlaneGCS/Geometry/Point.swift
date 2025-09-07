import Foundation

public class Point {
    public var x: ParameterRef
    public var y: ParameterRef
    
    public init(x: ParameterRef, y: ParameterRef) {
        self.x = x
        self.y = y
    }
    
    public convenience init(x: Double, y: Double) {
        self.init(x: ParameterRef(x), y: ParameterRef(y))
    }
    
    public var vector: SIMD2<Double> {
        SIMD2(x.value, y.value)
    }
    
    public func distance(to other: Point) -> Double {
        let dx = x.value - other.x.value
        let dy = y.value - other.y.value
        return sqrt(dx * dx + dy * dy)
    }
}