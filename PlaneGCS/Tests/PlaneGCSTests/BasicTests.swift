import XCTest
@testable import PlaneGCS

final class BasicTests: XCTestCase {
    
    func testPointCreation() {
        let p1 = Point(x: 1.0, y: 2.0)
        XCTAssertEqual(p1.x.value, 1.0, accuracy: 1e-10)
        XCTAssertEqual(p1.y.value, 2.0, accuracy: 1e-10)
        
        let p2 = Point(x: 3.0, y: 4.0)
        let distance = p1.distance(to: p2)
        XCTAssertEqual(distance, sqrt(8.0), accuracy: 1e-10)
    }
    
    func testLineCreation() {
        let p1 = Point(x: 0.0, y: 0.0)
        let p2 = Point(x: 1.0, y: 1.0)
        let line = Line(p1: p1, p2: p2)
        
        let midpoint = line.value(0.5, deriv: 0)
        XCTAssertEqual(midpoint.x, 0.5, accuracy: 1e-10)
        XCTAssertEqual(midpoint.y, 0.5, accuracy: 1e-10)
        
        let direction = line.direction
        XCTAssertEqual(direction.x, sqrt(0.5), accuracy: 1e-10)
        XCTAssertEqual(direction.y, sqrt(0.5), accuracy: 1e-10)
    }
    
    func testCircleCreation() {
        let center = Point(x: 0.0, y: 0.0)
        let circle = Circle(center: center, radius: 5.0)
        
        let point0 = circle.value(0, deriv: 0)
        XCTAssertEqual(point0.x, 5.0, accuracy: 1e-10)
        XCTAssertEqual(point0.y, 0.0, accuracy: 1e-10)
        
        let point90 = circle.value(.pi / 2, deriv: 0)
        XCTAssertEqual(point90.x, 0.0, accuracy: 1e-10)
        XCTAssertEqual(point90.y, 5.0, accuracy: 1e-10)
    }
    
    func testEqualConstraint() {
        let param1 = ParameterRef(5.0)
        let param2 = ParameterRef(3.0)
        
        let constraint = ConstraintEqual(param1: param1, param2: param2)
        
        let errorBefore = constraint.error()
        XCTAssertEqual(errorBefore, 2.0, accuracy: 1e-10)
        
        let system = System()
        system.addConstraint(constraint)
        
        let status = system.solve()
        XCTAssertEqual(status, .success)
        
        XCTAssertEqual(param1.value, param2.value, accuracy: 1e-10)
    }
    
    func testDistanceConstraint() {
        let p1 = Point(x: 0.0, y: 0.0)
        let p2 = Point(x: 3.0, y: 4.0)
        let distance = ParameterRef(5.0)
        
        let constraint = ConstraintP2PDistance(p1: p1, p2: p2, distance: distance)
        
        let system = System()
        system.addConstraint(constraint)
        
        let status = system.solve()
        XCTAssertEqual(status, .success)
        
        let actualDistance = p1.distance(to: p2)
        XCTAssertEqual(actualDistance, 5.0, accuracy: 1e-10)
    }
    
    func testParallelConstraint() {
        let p1 = Point(x: 0.0, y: 0.0)
        let p2 = Point(x: 1.0, y: 1.0)
        let p3 = Point(x: 2.0, y: 0.0)
        let p4 = Point(x: 3.0, y: 2.0)
        
        let line1 = Line(p1: p1, p2: p2)
        let line2 = Line(p1: p3, p2: p4)
        
        let constraint = ConstraintParallel(line1: line1, line2: line2)
        
        let system = System()
        system.addConstraint(constraint)
        
        let status = system.solve()
        XCTAssertEqual(status, .success)
        
        let dir1 = line1.direction
        let dir2 = line2.direction
        
        let crossProduct = dir1.x * dir2.y - dir1.y * dir2.x
        XCTAssertEqual(crossProduct, 0.0, accuracy: 1e-10)
    }
    
    func testPerpendicularConstraint() {
        let p1 = Point(x: 0.0, y: 0.0)
        let p2 = Point(x: 1.0, y: 0.0)
        let p3 = Point(x: 1.0, y: 0.0)
        let p4 = Point(x: 1.0, y: 1.0)
        
        let line1 = Line(p1: p1, p2: p2)
        let line2 = Line(p1: p3, p2: p4)
        
        let constraint = ConstraintPerpendicular(line1: line1, line2: line2)
        
        let system = System()
        system.addConstraint(constraint)
        
        let status = system.solve()
        XCTAssertEqual(status, .success)
        
        let dir1 = line1.direction
        let dir2 = line2.direction
        
        let dotProduct = dir1.x * dir2.x + dir1.y * dir2.y
        XCTAssertEqual(dotProduct, 0.0, accuracy: 1e-10)
    }
    
    func testPointOnLineConstraint() {
        let p1 = Point(x: 0.0, y: 0.0)
        let p2 = Point(x: 2.0, y: 2.0)
        let line = Line(p1: p1, p2: p2)
        
        let point = Point(x: 1.0, y: 0.5)
        
        let constraint = ConstraintPointOnLine(point: point, line: line)
        
        let system = System()
        system.addConstraint(constraint)
        
        let status = system.solve()
        XCTAssertEqual(status, .success)
        
        let distanceToLine = line.distanceToPoint(point)
        XCTAssertEqual(distanceToLine, 0.0, accuracy: 1e-10)
    }
    
    func testPointOnCircleConstraint() {
        let center = Point(x: 0.0, y: 0.0)
        let circle = Circle(center: center, radius: 5.0)
        
        let point = Point(x: 3.0, y: 3.0)
        
        let constraint = ConstraintPointOnCircle(point: point, circle: circle)
        
        let system = System()
        system.addConstraint(constraint)
        
        let status = system.solve()
        XCTAssertEqual(status, .success)
        
        let distanceToCenter = point.distance(to: center)
        XCTAssertEqual(distanceToCenter, 5.0, accuracy: 1e-10)
    }
    
    func testAngleConstraint() {
        let p1 = Point(x: 0.0, y: 0.0)
        let p2 = Point(x: 1.0, y: 0.0)
        let p3 = Point(x: 0.0, y: 0.0)
        let p4 = Point(x: 1.0, y: 1.0)
        
        let line1 = Line(p1: p1, p2: p2)
        let line2 = Line(p1: p3, p2: p4)
        
        let angle = ParameterRef(.pi / 4)
        let constraint = ConstraintL2LAngle(line1: line1, line2: line2, angle: angle)
        
        let system = System()
        system.addConstraint(constraint)
        
        let status = system.solve()
        XCTAssertEqual(status, .success)
    }
    
    func testComplexSystem() {
        let p1 = Point(x: 0.0, y: 0.0)
        let p2 = Point(x: 1.0, y: 0.0)
        let p3 = Point(x: 1.0, y: 1.0)
        let p4 = Point(x: 0.0, y: 1.0)
        
        let system = System()
        
        system.addConstraint(ConstraintP2PDistance(p1: p1, p2: p2, distance: ParameterRef(1.0)))
        system.addConstraint(ConstraintP2PDistance(p2: p2, p3: p3, distance: ParameterRef(1.0)))
        system.addConstraint(ConstraintP2PDistance(p3: p3, p4: p4, distance: ParameterRef(1.0)))
        system.addConstraint(ConstraintP2PDistance(p4: p4, p1: p1, distance: ParameterRef(1.0)))
        
        let line1 = Line(p1: p1, p2: p2)
        let line2 = Line(p1: p2, p2: p3)
        system.addConstraint(ConstraintPerpendicular(line1: line1, line2: line2))
        
        let status = system.solve()
        XCTAssertEqual(status, .success)
        
        XCTAssertEqual(p1.distance(to: p2), 1.0, accuracy: 1e-10)
        XCTAssertEqual(p2.distance(to: p3), 1.0, accuracy: 1e-10)
        XCTAssertEqual(p3.distance(to: p4), 1.0, accuracy: 1e-10)
        XCTAssertEqual(p4.distance(to: p1), 1.0, accuracy: 1e-10)
    }
    
    func testDiagnostics() {
        let system = System()
        
        let p1 = Point(x: 0.0, y: 0.0)
        let p2 = Point(x: 1.0, y: 0.0)
        
        system.addConstraint(ConstraintP2PDistance(p1: p1, p2: p2, distance: ParameterRef(1.0)))
        
        let diagnostic = system.diagnose()
        
        switch diagnostic {
        case .underConstrained(let dof):
            XCTAssertEqual(dof, 2)
        default:
            XCTFail("Expected under-constrained system")
        }
        
        system.addConstraint(ConstraintEqual(param1: p1.x, param2: ParameterRef(0)))
        system.addConstraint(ConstraintEqual(param1: p1.y, param2: ParameterRef(0)))
        system.addConstraint(ConstraintEqual(param1: p2.y, param2: ParameterRef(0)))
        
        let diagnostic2 = system.diagnose()
        
        switch diagnostic2 {
        case .wellConstrained:
            break
        default:
            XCTFail("Expected well-constrained system")
        }
    }
    
    func testSolverAlgorithms() {
        let p1 = Point(x: 0.0, y: 0.0)
        let p2 = Point(x: 3.0, y: 4.0)
        let distance = ParameterRef(5.0)
        
        let algorithms: [Algorithm] = [.bfgs, .levenbergMarquardt, .dogLeg]
        
        for algorithm in algorithms {
            p2.x.value = 3.0
            p2.y.value = 4.0
            
            let system = System()
            var params = SolverParameters()
            params.algorithm = algorithm
            system.setParameters(params)
            
            system.addConstraint(ConstraintP2PDistance(p1: p1, p2: p2, distance: distance))
            
            let status = system.solve()
            XCTAssertEqual(status, .success, "Algorithm \(algorithm) failed")
            
            let actualDistance = p1.distance(to: p2)
            XCTAssertEqual(actualDistance, 5.0, accuracy: 1e-9, "Algorithm \(algorithm) produced incorrect result")
        }
    }
}