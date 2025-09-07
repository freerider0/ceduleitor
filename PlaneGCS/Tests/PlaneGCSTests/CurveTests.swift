import XCTest
@testable import PlaneGCS

final class CurveTests: XCTestCase {
    
    func testEllipseCreation() {
        let center = Point(x: 0.0, y: 0.0)
        let focus = Point(x: 3.0, y: 0.0)
        let radmin = ParameterRef(4.0)
        
        let ellipse = Ellipse(center: center, focus1: focus, radmin: radmin)
        
        XCTAssertEqual(ellipse.majorRadius, 5.0, accuracy: 1e-10)
        XCTAssertEqual(ellipse.minorRadius, 4.0, accuracy: 1e-10)
        XCTAssertEqual(ellipse.eccentricity, 0.6, accuracy: 1e-10)
        
        let point0 = ellipse.value(0, deriv: 0)
        XCTAssertEqual(point0.x, 5.0, accuracy: 1e-10)
        XCTAssertEqual(point0.y, 0.0, accuracy: 1e-10)
        
        let point90 = ellipse.value(.pi / 2, deriv: 0)
        XCTAssertEqual(point90.x, 0.0, accuracy: 1e-10)
        XCTAssertEqual(point90.y, 4.0, accuracy: 1e-10)
    }
    
    func testHyperbolaCreation() {
        let center = Point(x: 0.0, y: 0.0)
        let focus = Point(x: 5.0, y: 0.0)
        let radmin = ParameterRef(3.0)
        
        let hyperbola = Hyperbola(center: center, focus1: focus, radmin: radmin)
        
        XCTAssertEqual(hyperbola.majorRadius, 4.0, accuracy: 1e-10)
        XCTAssertEqual(hyperbola.minorRadius, 3.0, accuracy: 1e-10)
        
        let point0 = hyperbola.value(0, deriv: 0)
        XCTAssertEqual(point0.x, 4.0, accuracy: 1e-10)
        XCTAssertEqual(point0.y, 0.0, accuracy: 1e-10)
    }
    
    func testParabolaCreation() {
        let vertex = Point(x: 0.0, y: 0.0)
        let focus = Point(x: 0.0, y: 1.0)
        
        let parabola = Parabola(vertex: vertex, focus: focus)
        
        XCTAssertEqual(parabola.focalLength, 1.0, accuracy: 1e-10)
        
        let point1 = parabola.value(2.0, deriv: 0)
        XCTAssertEqual(point1.x, 1.0, accuracy: 1e-10)
        XCTAssertEqual(point1.y, 2.0, accuracy: 1e-10)
    }
    
    func testBSplineCreation() {
        let poles = [
            Point(x: 0.0, y: 0.0),
            Point(x: 1.0, y: 1.0),
            Point(x: 2.0, y: 0.0),
            Point(x: 3.0, y: 1.0)
        ]
        
        let weights = poles.map { _ in ParameterRef(1.0) }
        let knots = [0.0, 0.0, 0.0, 0.5, 1.0, 1.0, 1.0]
        let degree = 2
        
        let bspline = BSpline(poles: poles, weights: weights, knots: knots, degree: degree)
        
        let startPoint = bspline.value(0.0, deriv: 0)
        XCTAssertEqual(startPoint.x, 0.0, accuracy: 1e-10)
        XCTAssertEqual(startPoint.y, 0.0, accuracy: 1e-10)
        
        let endPoint = bspline.value(1.0, deriv: 0)
        XCTAssertEqual(endPoint.x, 3.0, accuracy: 1e-10)
        XCTAssertEqual(endPoint.y, 1.0, accuracy: 1e-10)
    }
    
    func testPointOnEllipseConstraint() {
        let center = Point(x: 0.0, y: 0.0)
        let focus = Point(x: 3.0, y: 0.0)
        let radmin = ParameterRef(4.0)
        let ellipse = Ellipse(center: center, focus1: focus, radmin: radmin)
        
        let point = Point(x: 2.5, y: 3.0)
        
        let constraint = ConstraintPointOnEllipse(point: point, ellipse: ellipse)
        
        let system = System()
        system.addConstraint(constraint)
        
        let status = system.solve()
        XCTAssertEqual(status, .success)
        
        XCTAssertTrue(ellipse.containsPoint(point))
    }
    
    func testPointOnHyperbolaConstraint() {
        let center = Point(x: 0.0, y: 0.0)
        let focus = Point(x: 5.0, y: 0.0)
        let radmin = ParameterRef(3.0)
        let hyperbola = Hyperbola(center: center, focus1: focus, radmin: radmin)
        
        let point = Point(x: 4.0, y: 1.0)
        
        let constraint = ConstraintPointOnHyperbola(point: point, hyperbola: hyperbola)
        
        let system = System()
        system.addConstraint(constraint)
        
        let status = system.solve()
        XCTAssertEqual(status, .success)
        
        XCTAssertTrue(hyperbola.containsPoint(point))
    }
    
    func testPointOnParabolaConstraint() {
        let vertex = Point(x: 0.0, y: 0.0)
        let focus = Point(x: 0.0, y: 1.0)
        let parabola = Parabola(vertex: vertex, focus: focus)
        
        let point = Point(x: 1.0, y: 2.0)
        
        let constraint = ConstraintPointOnParabola(point: point, parabola: parabola)
        
        let system = System()
        system.addConstraint(constraint)
        
        let status = system.solve()
        XCTAssertEqual(status, .success)
        
        XCTAssertTrue(parabola.containsPoint(point))
    }
    
    func testTangentCircles() {
        let center1 = Point(x: 0.0, y: 0.0)
        let circle1 = Circle(center: center1, radius: 3.0)
        
        let center2 = Point(x: 5.0, y: 0.0)
        let circle2 = Circle(center: center2, radius: 2.0)
        
        let constraint = ConstraintTangentCircumf(circle1: circle1, circle2: circle2, internal: false)
        
        let system = System()
        system.addConstraint(constraint)
        
        let status = system.solve()
        XCTAssertEqual(status, .success)
        
        let centerDistance = center1.distance(to: center2)
        XCTAssertEqual(centerDistance, 5.0, accuracy: 1e-10)
    }
    
    func testArcCreation() {
        let center = Point(x: 0.0, y: 0.0)
        let radius = ParameterRef(5.0)
        let startAngle = ParameterRef(0.0)
        let endAngle = ParameterRef(.pi / 2)
        let startPoint = Point(x: 5.0, y: 0.0)
        let endPoint = Point(x: 0.0, y: 5.0)
        
        let arc = Arc(center: center, radius: radius,
                      startAngle: startAngle, endAngle: endAngle,
                      startPoint: startPoint, endPoint: endPoint)
        
        XCTAssertTrue(arc.angleInRange(0.0))
        XCTAssertTrue(arc.angleInRange(.pi / 4))
        XCTAssertTrue(arc.angleInRange(.pi / 2))
        XCTAssertFalse(arc.angleInRange(.pi))
    }
    
    func testArcOfEllipseCreation() {
        let center = Point(x: 0.0, y: 0.0)
        let focus = Point(x: 3.0, y: 0.0)
        let radmin = ParameterRef(4.0)
        let startAngle = ParameterRef(0.0)
        let endAngle = ParameterRef(.pi)
        let startPoint = Point(x: 5.0, y: 0.0)
        let endPoint = Point(x: -5.0, y: 0.0)
        
        let arcEllipse = ArcOfEllipse(center: center, focus1: focus, radmin: radmin,
                                       startAngle: startAngle, endAngle: endAngle,
                                       startPoint: startPoint, endPoint: endPoint)
        
        XCTAssertTrue(arcEllipse.angleInRange(0.0))
        XCTAssertTrue(arcEllipse.angleInRange(.pi / 2))
        XCTAssertTrue(arcEllipse.angleInRange(.pi))
        XCTAssertFalse(arcEllipse.angleInRange(3 * .pi / 2))
    }
    
    func testCurveValueConstraint() {
        let center = Point(x: 0.0, y: 0.0)
        let circle = Circle(center: center, radius: 5.0)
        
        let u = ParameterRef(.pi / 2)
        let point = Point(x: 0.0, y: 5.0)
        
        let constraint = ConstraintCurveValue(curve: circle, u: u, point: point)
        
        let system = System()
        system.addConstraint(constraint)
        
        let status = system.solve()
        XCTAssertEqual(status, .success)
        
        let curvePoint = circle.value(u.value, deriv: 0)
        XCTAssertEqual(curvePoint.x, point.x.value, accuracy: 1e-10)
        XCTAssertEqual(curvePoint.y, point.y.value, accuracy: 1e-10)
    }
}