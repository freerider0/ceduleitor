# Testing Strategy: Real Tests, No Mock Theater

## The Problem with Mock-Based Testing

AI tends to generate elaborate mock setups that test nothing:

```swift
// ❌ This tests that mocks work, not your code
class MockARSession: ARSession {
    var addWasCalled = false
    override func run(_ configuration: ARConfiguration) {
        addWasCalled = true  // Always true!
    }
}

func test_WallDetection() {
    let mockDetector = MockWallDetector()
    let walls = mockDetector.detectWalls()  // Returns fake walls
    XCTAssertEqual(walls.count, 1)  // Testing mock behavior!
}
```

## The Solution: Test Real Behavior

### Rule 1: Never Mock What You Don't Own
```swift
// ❌ NEVER mock iOS frameworks
class MockARSession      // NO!
class MockUIView         // NO!
class MockARSCNView      // NO!
class MockURLSession     // NO!

// ✅ Use real objects or skip the test
func test_ARViewCreation() {
    let arView = ARView(frame: .zero)  // Real object!
    XCTAssertNotNil(arView.session)
}
```

### Rule 2: Test Pure Functions
```swift
// ✅ ACTUALLY testable without mocks
func test_DistanceCalculation() {
    let point1 = SIMD3<Float>(0, 0, 0)
    let point2 = SIMD3<Float>(3, 4, 0)
    let distance = calculateDistance(point1, point2)
    XCTAssertEqual(distance, 5.0, accuracy: 0.01)
}

func test_WallAreaCalculation() {
    let area = calculateArea(width: 2.0, height: 3.0)
    XCTAssertEqual(area, 6.0)
}

func test_MeasurementFormatting() {
    XCTAssertEqual(formatDistance(1.234), "1.23 m")
    XCTAssertEqual(formatDistance(0.05), "5 cm")
}
```

### Rule 3: One Test Per Feature
```swift
// For an AR app with 4 features, you need 4 tests:

func test_AppLaunches() {
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(app.exists)
}

func test_DetectsWalls() {
    // Test actual detection if possible
    // or skip if requires real AR environment
}

func test_TapSelectsWall() {
    // UI test with real tap
}

func test_MeasuresDistance() {
    // Test the calculation, not the AR part
}
```

## What to Test vs What to Skip

### ✅ Test These
```swift
// Business Logic
- Distance calculations
- Data formatting
- Color mapping based on values
- Coordinate transformations
- Business rules

// Pure Functions
- Math operations
- String formatting
- Data transformations
- Sorting/filtering

// Critical Paths
- Payment calculations
- User data handling
- Security functions
```

### ❌ Skip These
```swift
// iOS Delegates
- ARSessionDelegate methods
- UITableViewDelegate methods
- UITextFieldDelegate methods

// View Creation
- View initialization
- Auto Layout
- View hierarchy

// Framework Integration
- ARKit plane detection
- RealityKit rendering
- Core Data setup
```

## Testing Patterns for AR Apps

### Pattern 1: Test Calculations, Not AR
```swift
// Instead of mocking AR detection...
// Test the math that processes AR data:

func test_WallDimensionsFromPlane() {
    let plane = TestPlaneData(width: 2.0, height: 3.0)
    let wall = Wall(from: plane)

    XCTAssertEqual(wall.width, 2.0)
    XCTAssertEqual(wall.height, 3.0)
    XCTAssertEqual(wall.area, 6.0)
}
```

### Pattern 2: Integration Tests Over Unit Tests
```swift
// One good integration test > 20 unit tests

func test_UserCanCompleteWallMeasurement() {
    let app = XCUIApplication()
    app.launch()

    // Wait for AR to initialize
    sleep(2)

    // Tap twice to measure
    app.tap()
    sleep(1)
    app.tap()

    // Check result appears
    XCTAssert(app.staticTexts.containing("meters").exists)
}
```

### Pattern 3: Test Data Structures, Not UI
```swift
// Test your data model logic
func test_WallStateManagement() {
    var wall = Wall(id: UUID())

    XCTAssertFalse(wall.isTracked)

    wall.track()
    XCTAssertTrue(wall.isTracked)

    wall.untrack()
    XCTAssertFalse(wall.isTracked)
}
```

## The Minimal Test Suite

For a typical AR app, you need about 5-10 tests total:

```swift
class ARAppMinimalTests: XCTestCase {

    // Test 1: Core calculation
    func test_DistanceCalculation() {
        let distance = measure(from: .zero, to: SIMD3(1,1,1))
        XCTAssertEqual(distance, 1.732, accuracy: 0.01)
    }

    // Test 2: Data formatting
    func test_FormatsMeasurements() {
        XCTAssertEqual(format(1.5), "1.50 m")
        XCTAssertEqual(format(0.03), "3 cm")
    }

    // Test 3: Business logic
    func test_WallSelectionLogic() {
        let manager = WallManager()
        manager.selectWall(id: UUID())
        XCTAssertEqual(manager.selectedCount, 1)
    }

    // Test 4: Critical path (if exists)
    func test_ExportData() {
        let data = exportMeasurements([1.0, 2.0, 3.0])
        XCTAssertTrue(data.contains("1.0"))
    }

    // Test 5: Regression (after fixing bugs)
    func test_HandlesZeroDistance() {
        let distance = measure(from: .zero, to: .zero)
        XCTAssertEqual(distance, 0.0)
    }
}
```

## Red Flags in Test Code

### 🚩 Delete These Immediately
```swift
// Protocols just for mocking
protocol WallRepositoryProtocol  // DELETE

// Mock classes
class MockARSessionDelegate      // DELETE
class StubGestureRecognizer     // DELETE

// Tracking mock behavior
var wasCalledFlag = false       // DELETE
var numberOfTimesCalled = 0     // DELETE

// Tests that test mocks
XCTAssertTrue(mockObject.wasMethodCalled)  // DELETE
XCTAssertEqual(mockCalls.count, 1)         // DELETE
```

## Prompting for Simple Tests

### Get Tests Without Mocks
```
"Write a test for [feature] with these constraints:
- NO mocks or stubs
- Use real objects only
- If real objects can't be used, test pure functions instead
- If no pure functions, skip the test
- Maximum 10 lines"
```

### Fix Mock-Heavy Tests
```
"This test uses mocks which test nothing. Rewrite to:
1. Test actual calculations/logic OR
2. Test with real objects OR
3. Tell me this doesn't need a test"
```

### Request Minimal Tests
```
"For this AR app with [list features], write the minimal test suite:
- One test per major feature
- Test calculations, not AR
- No mocks
- Total under 50 lines"
```

## The Testing Philosophy

### When to Write Tests
```
Week 1-4: Zero tests, just ship features
Week 5: Add 3-5 tests for core logic
Ongoing: Add test ONLY when you fix bugs
```

### Test-to-Code Ratio
```
Good: 50 lines of tests for 500 lines of code (1:10)
OK: 100 lines of tests for 500 lines of code (1:5)
Bad: 500 lines of tests for 500 lines of code (1:1)
Terrible: 1000 lines of tests for 500 lines of code (2:1)
```

### The One-Line Decision Tree
```
If test needs mocks → Don't test it
If test needs DI just for testing → Don't test it
If test is longer than the code → Don't test it
If test tests the mock → Don't test it
If it's a pure function → Test it!
```

## Example: Real Tests for AR Wall App

```swift
// The ENTIRE test suite for a wall detection app:

class WallAppTests: XCTestCase {

    // Math/Logic Tests (no mocks needed)
    func test_CalculatesWallArea() {
        XCTAssertEqual(calculateArea(2, 3), 6)
    }

    func test_FormatsDistance() {
        XCTAssertEqual(formatDistance(1.234), "1.23m")
    }

    func test_CalculatesDistance() {
        let d = distance(SIMD3(0,0,0), SIMD3(1,1,0))
        XCTAssertEqual(d, 1.414, accuracy: 0.01)
    }

    // State Management (real objects)
    func test_WallSelection() {
        let manager = WallManager()
        manager.select(UUID())
        XCTAssertEqual(manager.selectedWalls.count, 1)
    }

    // That's it! 4 tests, 20 lines total
}
```

## Remember

> "A test that uses mocks is usually testing that the mocks work, not that your code works."

> "The best test is a user successfully using your app."

> "If you can't test it without mocks, it probably doesn't need testing."

## The Bottom Line

- Test behavior, not implementation
- Test calculations, not iOS frameworks
- One test per feature is often enough
- Integration tests > unit tests for simple apps
- No test is better than a mock test that always passes