# PlaneGCS - Swift Implementation

A complete Swift implementation of the PlaneGCS (Plane Geometric Constraint Solver) library, providing powerful 2D geometric constraint solving capabilities for CAD, engineering, and geometric modeling applications.

## Features

### Geometric Primitives
- **Point**: 2D points with parameter references
- **Line**: Lines defined by two points
- **Circle**: Circles with center and radius
- **Arc**: Circular arcs with angular bounds

### Conic Sections
- **Ellipse**: Full ellipse and arc support
- **Hyperbola**: Hyperbolic curves and arcs
- **Parabola**: Parabolic curves and arcs

### Advanced Curves
- **B-Spline**: NURBS curves with arbitrary degree
  - Control points (poles)
  - Weights for rational curves
  - Knot vectors
  - Periodic/non-periodic support

### Constraint Types

#### Basic Constraints
- **Equal**: Force two parameters to be equal
- **Difference**: Maintain specific difference between parameters
- **Distance**: Point-to-point and point-to-line distances
- **Angle**: Angles between lines and points

#### Geometric Relationships
- **Parallel**: Ensure lines are parallel
- **Perpendicular**: Ensure lines are perpendicular
- **Point on Line**: Constrain point to lie on line
- **Point on Circle**: Constrain point to lie on circle
- **Point on Curve**: Generic curve constraints

#### Advanced Constraints
- **Tangent**: Tangency between circles
- **Point on Ellipse/Hyperbola/Parabola**: Conic section constraints
- **Curve Value**: Parametric curve constraints
- **Snell's Law**: Optical refraction constraints

### Optimization Algorithms

#### BFGS (Broyden–Fletcher–Goldfarb–Shanno)
- Quasi-Newton method
- Hessian approximation
- Line search with Wolfe conditions
- Suitable for unconstrained optimization

#### Levenberg-Marquardt
- Hybrid gradient/Newton method
- Adaptive damping parameter
- Robust for nonlinear least squares
- Automatic trust region adjustment

#### Dog Leg
- Trust region method
- Combines steepest descent and Newton steps
- Adaptive trust radius
- Excellent for ill-conditioned problems

### System Features

#### Constraint Management
- Automatic parameter tracking
- Constraint partitioning for efficiency
- Subsystem decomposition
- Automatic rescaling

#### Diagnostics
- Degrees of freedom analysis
- Conflicting constraint detection
- Redundant constraint identification
- Constraint sensitivity analysis
- Parameter sensitivity analysis
- Rank deficiency analysis

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(path: "./PlaneGCS")
]
```

## Usage Examples

### Basic Distance Constraint

```swift
import PlaneGCS

// Create two points
let p1 = Point(x: 0.0, y: 0.0)
let p2 = Point(x: 3.0, y: 4.0)

// Create distance constraint
let distance = ParameterRef(5.0)
let constraint = ConstraintP2PDistance(p1: p1, p2: p2, distance: distance)

// Create system and solve
let system = System()
system.addConstraint(constraint)

let status = system.solve()
if status == .success {
    print("Distance: \(p1.distance(to: p2))")  // 5.0
}
```

### Creating a Rectangle

```swift
// Create four corner points
let p1 = Point(x: 0.0, y: 0.0)
let p2 = Point(x: 1.0, y: 0.0)
let p3 = Point(x: 1.0, y: 1.0)
let p4 = Point(x: 0.0, y: 1.0)

let system = System()

// Add distance constraints for sides
system.addConstraint(ConstraintP2PDistance(p1: p1, p2: p2, distance: ParameterRef(2.0)))
system.addConstraint(ConstraintP2PDistance(p2: p2, p3: p3, distance: ParameterRef(3.0)))
system.addConstraint(ConstraintP2PDistance(p3: p3, p4: p4, distance: ParameterRef(2.0)))
system.addConstraint(ConstraintP2PDistance(p4: p4, p1: p1, distance: ParameterRef(3.0)))

// Add perpendicular constraints
let line1 = Line(p1: p1, p2: p2)
let line2 = Line(p1: p2, p2: p3)
system.addConstraint(ConstraintPerpendicular(line1: line1, line2: line2))

// Solve the system
let status = system.solve()
```

### Working with Curves

```swift
// Create an ellipse
let center = Point(x: 0.0, y: 0.0)
let focus = Point(x: 3.0, y: 0.0)
let radmin = ParameterRef(4.0)
let ellipse = Ellipse(center: center, focus1: focus, radmin: radmin)

// Constrain a point to lie on the ellipse
let point = Point(x: 2.5, y: 3.0)
let constraint = ConstraintPointOnEllipse(point: point, ellipse: ellipse)

let system = System()
system.addConstraint(constraint)
system.solve()
```

### Configuring Solver Parameters

```swift
var params = SolverParameters()
params.algorithm = .dogLeg
params.maxIterations = 200
params.convergenceTolerance = 1e-12
params.rescaleConstraints = true

let system = System()
system.setParameters(params)
```

### System Diagnostics

```swift
let system = System()
// Add constraints...

// Analyze system
let diagnostic = system.diagnose()

switch diagnostic {
case .wellConstrained:
    print("System is well-constrained")
case .underConstrained(let dof):
    print("System is under-constrained with \(dof) degrees of freedom")
case .overConstrained(let conflicting):
    print("System has \(conflicting.count) conflicting constraints")
case .redundant(let redundant):
    print("System has \(redundant.count) redundant constraints")
}

// Find problematic constraints
let conflicting = system.findConflictingConstraints()
let redundant = system.findRedundantConstraints()
```

## Architecture

The library is organized into several modules:

- **Core**: Main system and subsystem management
- **Geometry**: Geometric primitives and curves
- **Constraints**: All constraint implementations
- **Solvers**: Optimization algorithms
- **Utils**: Mathematical utilities and matrix operations

## Performance Considerations

- Uses Apple's Accelerate framework for optimized linear algebra
- Automatic constraint partitioning for large systems
- Efficient Jacobian computation with sparse matrix support
- Adaptive solver selection based on problem characteristics

## Requirements

- Swift 5.9+
- macOS 13.0+ / iOS 16.0+
- Accelerate framework (included in Apple platforms)

## Testing

Run the test suite:

```bash
swift test
```

## License

This Swift implementation maintains compatibility with the original PlaneGCS library's mathematical algorithms and constraint solving capabilities.

## Contributing

Contributions are welcome! Please ensure all tests pass and add new tests for any new features.