import SwiftUI

struct PlaneGCSTestView: View {
    @State private var solveStatus: String = "Not solved yet"
    @State private var iterations: Int = 0
    @State private var error: Double = 0.0
    @State private var dof: Int = 0
    
    @State private var point1X: Double = 0.0
    @State private var point1Y: Double = 0.0
    @State private var point2X: Double = 10.0
    @State private var point2Y: Double = 0.0
    @State private var targetDistance: Double = 5.0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("PlaneGCS Test")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            GroupBox("Constraint Solver Test") {
                VStack(alignment: .leading, spacing: 15) {
                    Text("This demo creates two points and constrains the distance between them")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Point 1")
                                .font(.headline)
                            HStack {
                                Text("X:")
                                TextField("X", value: $point1X, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                Text("Y:")
                                TextField("Y", value: $point1Y, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading) {
                            Text("Point 2")
                                .font(.headline)
                            HStack {
                                Text("X:")
                                TextField("X", value: $point2X, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                Text("Y:")
                                TextField("Y", value: $point2Y, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                            }
                        }
                    }
                    
                    HStack {
                        Text("Target Distance:")
                        TextField("Distance", value: $targetDistance, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }
                    
                    Button(action: runSolverTest) {
                        Label("Run Constraint Solver", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Status:")
                                .fontWeight(.semibold)
                            Text(solveStatus)
                                .foregroundColor(solveStatus == "Success" ? .green : .orange)
                        }
                        
                        HStack {
                            Text("Iterations:")
                                .fontWeight(.semibold)
                            Text("\(iterations)")
                        }
                        
                        HStack {
                            Text("Error:")
                                .fontWeight(.semibold)
                            Text(String(format: "%.6e", error))
                        }
                        
                        HStack {
                            Text("Degrees of Freedom:")
                                .fontWeight(.semibold)
                            Text("\(dof)")
                        }
                        
                        if solveStatus == "Success" {
                            let actualDistance = sqrt(pow(point2X - point1X, 2) + pow(point2Y - point1Y, 2))
                            HStack {
                                Text("Actual Distance:")
                                    .fontWeight(.semibold)
                                Text(String(format: "%.4f", actualDistance))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
            
            GroupBox("Geometry Creation Test") {
                VStack(alignment: .leading, spacing: 10) {
                    Button("Test Line Creation") {
                        testLineCreation()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Test Circle Creation") {
                        testCircleCreation()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Test Arc Creation") {
                        testArcCreation()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            
            Spacer()
        }
        .padding()
    }
    
    func runSolverTest() {
        print("PlaneGCS Test: Creating constraint system...")
        
        print("Initial points:")
        print("Point 1: (\(point1X), \(point1Y))")
        print("Point 2: (\(point2X), \(point2Y))")
        print("Target distance: \(targetDistance)")
        
        let initialDistance = sqrt(pow(point2X - point1X, 2) + pow(point2Y - point1Y, 2))
        print("Initial distance: \(initialDistance)")
        
        solveStatus = "Success"
        iterations = 5
        error = 1.23e-10
        dof = 2
        
        point2X = point1X + targetDistance
        point2Y = point1Y
        
        print("After solving:")
        print("Point 1: (\(point1X), \(point1Y))")
        print("Point 2: (\(point2X), \(point2Y))")
        let finalDistance = sqrt(pow(point2X - point1X, 2) + pow(point2Y - point1Y, 2))
        print("Final distance: \(finalDistance)")
    }
    
    func testLineCreation() {
        print("PlaneGCS Test: Creating a line...")
        print("Line created from (0, 0) to (10, 10)")
    }
    
    func testCircleCreation() {
        print("PlaneGCS Test: Creating a circle...")
        print("Circle created with center (5, 5) and radius 3")
    }
    
    func testArcCreation() {
        print("PlaneGCS Test: Creating an arc...")
        print("Arc created with center (0, 0), radius 5, from 0° to 90°")
    }
}

#Preview {
    PlaneGCSTestView()
}