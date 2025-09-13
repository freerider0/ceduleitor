import Foundation
import simd

// MARK: - Basic Types

struct DSPoint: Equatable {
    let x: Float
    let y: Float
    
    func distance(to other: DSPoint) -> Float {
        sqrt(pow(x - other.x, 2) + pow(y - other.y, 2))
    }
}

struct Vector {
    let x: Float
    let y: Float
    
    var normalized: Vector {
        let length = sqrt(x * x + y * y)
        guard length > 0 else { return self }
        return Vector(x: x / length, y: y / length)
    }
}

// MARK: - Core Classes

class Fragment {
    let id: String
    let start: DSPoint
    let end: DSPoint
    
    init(id: String, start: DSPoint, end: DSPoint) {
        self.id = id
        self.start = start
        self.end = end
    }
    
    func getDirectionVector(normalize: Bool = true) -> Vector {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let vector = Vector(x: dx, y: dy)
        return normalize ? vector.normalized : vector
    }
}

class Ray: Hashable {
    let fragmentId: String
    let origin: DSPoint
    let direction: Vector
    let fromEnd: Bool
    let id = UUID()  // Unique identifier for hashing
    
    init(fragmentId: String, origin: DSPoint, direction: Vector, fromEnd: Bool) {
        self.fragmentId = fragmentId
        self.origin = origin
        self.direction = direction
        self.fromEnd = fromEnd
    }
    
    static func == (lhs: Ray, rhs: Ray) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    func intersect(with other: Ray) -> DSPoint? {
        let o1x = origin.x
        let o1y = origin.y
        let d1x = direction.x
        let d1y = direction.y
        
        let o2x = other.origin.x
        let o2y = other.origin.y
        let d2x = other.direction.x
        let d2y = other.direction.y
        
        let denom = d1x * d2y - d1y * d2x
        guard abs(denom) >= 1e-10 else { return nil }
        
        let t1 = ((o2x - o1x) * d2y - (o2y - o1y) * d2x) / denom
        let t2 = ((o2x - o1x) * d1y - (o2y - o1y) * d1x) / denom
        
        guard t1 >= 1e-10 && t2 >= 1e-10 else { return nil }
        
        return DSPoint(x: o1x + t1 * d1x, y: o1y + t1 * d1y)
    }
}

struct Intersection {
    let ray1: Ray
    let ray2: Ray
    let point: DSPoint
}

struct MutualConnection {
    let point: DSPoint
    let rays: [Ray]
}

// MARK: - Algorithm State

class AlgorithmState {
    var rays: [Ray] = []
    var vertices: [DSPoint] = []
    var connections: [(String, String)] = []
    var iteration: Int = 0
    var isRunning: Bool = false
    var completed: Bool = false
}

// MARK: - Diamond Solid Algorithm

class DiamondSolidAlgorithm {
    private var fragments: [Fragment] = []
    private var state = AlgorithmState()
    
    // MARK: - Public Interface
    
    func addFragment(_ fragment: Fragment) {
        fragments.append(fragment)
    }
    
    func reset() {
        fragments.removeAll()
        state = AlgorithmState()
    }
    
    func execute() -> (vertices: [DSPoint], connections: [(String, String)]) {
        guard fragments.count >= 2 else {
            print("[DiamondSolid] Need at least 2 fragments")
            return ([], [])
        }
        
        state = AlgorithmState()
        state.isRunning = true
        
        // Generate all rays from fragments
        let allRays = generateRays(from: fragments)
        
        // Step 1: Pre-expansion
        let preResult = performPreExpansion(rays: allRays)
        state.vertices = preResult.vertices
        state.connections = preResult.connections
        state.rays = preResult.remainingRays
        state.iteration = 1
        
        // Step 2: Main algorithm loop
        while !state.rays.isEmpty && state.iteration < 100 {
            runAlgorithmStep()
            state.iteration += 1
        }
        
        state.completed = true
        state.isRunning = false
        
        return (state.vertices, state.connections)
    }
    
    // MARK: - Ray Generation
    
    private func generateRays(from fragments: [Fragment]) -> [Ray] {
        var rays: [Ray] = []
        
        for fragment in fragments {
            let direction = fragment.getDirectionVector()
            
            // Ray from start going backwards
            rays.append(Ray(
                fragmentId: fragment.id,
                origin: fragment.start,
                direction: Vector(x: -direction.x, y: -direction.y),
                fromEnd: false
            ))
            
            // Ray from end going forward
            rays.append(Ray(
                fragmentId: fragment.id,
                origin: fragment.end,
                direction: direction,
                fromEnd: true
            ))
        }
        
        return rays
    }
    
    // MARK: - Intersection Calculations
    
    private func calculateIntersections(rays: [Ray]) -> [Intersection] {
        var intersections: [Intersection] = []
        
        for i in 0..<rays.count {
            for j in (i+1)..<rays.count {
                // Skip rays from same fragment
                if rays[i].fragmentId == rays[j].fragmentId { continue }
                
                if let point = rays[i].intersect(with: rays[j]) {
                    intersections.append(Intersection(
                        ray1: rays[i],
                        ray2: rays[j],
                        point: point
                    ))
                }
            }
        }
        
        return intersections
    }
    
    private func findFirstIntersections(rays: [Ray], intersections: [Intersection]) -> [Ray: DSPoint] {
        var firstIntersections: [Ray: DSPoint] = [:]
        
        for ray in rays {
            var closest: DSPoint?
            var minDistance = Float.infinity
            
            for intersection in intersections {
                if intersection.ray1 === ray || intersection.ray2 === ray {
                    let distance = ray.origin.distance(to: intersection.point)
                    if distance < minDistance && distance > 1e-6 {
                        minDistance = distance
                        closest = intersection.point
                    }
                }
            }
            
            if let closest = closest {
                firstIntersections[ray] = closest
            }
        }
        
        return firstIntersections
    }
    
    private func findMutualConnections(rays: [Ray], firstIntersections: [Ray: DSPoint]) -> [MutualConnection] {
        var groups: [String: (point: DSPoint, rays: [Ray])] = [:]
        
        for (ray, point) in firstIntersections {
            let key = "\(Int(point.x * 1000000))/\(Int(point.y * 1000000))"
            if groups[key] == nil {
                groups[key] = (point: point, rays: [])
            }
            groups[key]?.rays.append(ray)
        }
        
        var mutualConnections: [MutualConnection] = []
        for (_, group) in groups {
            if group.rays.count == 2 {
                mutualConnections.append(MutualConnection(
                    point: group.point,
                    rays: group.rays
                ))
            }
        }
        
        return mutualConnections
    }
    
    // MARK: - Pre-expansion
    
    private func performPreExpansion(rays: [Ray]) -> (vertices: [DSPoint], connections: [(String, String)], remainingRays: [Ray]) {
        print("[DiamondSolid] === PRE-EXPANSION ===")
        var vertices: [DSPoint] = []
        var connections: [(String, String)] = []
        var usedRays = Set<ObjectIdentifier>()
        
        let allIntersections = calculateIntersections(rays: rays)
        let firstIntersections = findFirstIntersections(rays: rays, intersections: allIntersections)
        
        for ray1 in rays {
            if usedRays.contains(ObjectIdentifier(ray1)) { continue }
            
            guard let first1 = firstIntersections[ray1] else { continue }
            
            for ray2 in rays {
                if ray1 === ray2 || ray1.fragmentId == ray2.fragmentId { continue }
                if usedRays.contains(ObjectIdentifier(ray2)) { continue }
                
                guard let first2 = firstIntersections[ray2] else { continue }
                
                if first1.distance(to: first2) < 0.1 {  // 10cm tolerance for AR
                    if let intersection = ray1.intersect(with: ray2),
                       intersection.distance(to: first1) < 0.1 {
                        vertices.append(intersection)
                        connections.append((ray1.fragmentId, ray2.fragmentId))
                        usedRays.insert(ObjectIdentifier(ray1))
                        usedRays.insert(ObjectIdentifier(ray2))
                        print("[DiamondSolid] Pre-expansion: \(ray1.fragmentId) ↔ \(ray2.fragmentId)")
                    }
                }
            }
        }
        
        let remainingRays = rays.filter { !usedRays.contains(ObjectIdentifier($0)) }
        print("[DiamondSolid] Pre-expansion completed: \(vertices.count) vertices, \(remainingRays.count) rays remaining")
        
        return (vertices, connections, remainingRays)
    }
    
    // MARK: - Deadlock Resolution
    
    private func resolveDeadlock(rays: [Ray], intersections: [Intersection], firstIntersections: [Ray: DSPoint]) 
        -> (vertex: DSPoint, connection: (String, String), ray1: Ray, ray2: Ray)? {
        
        print("[DiamondSolid] === RESOLVING DEADLOCK ===")
        
        // Find connected ends
        var connectedEnds = Set<String>()
        
        for (index, connection) in state.connections.enumerated() {
            guard index < state.vertices.count else { continue }
            let vertex = state.vertices[index]
            
            for fragment in fragments {
                if fragment.id == connection.0 || fragment.id == connection.1 {
                    let distToStart = fragment.start.distance(to: vertex)
                    let distToEnd = fragment.end.distance(to: vertex)
                    
                    let endKey = distToStart < distToEnd ? "\(fragment.id)_start" : "\(fragment.id)_end"
                    connectedEnds.insert(endKey)
                }
            }
        }
        
        // Find unconnected rays
        var unconnectedRays: [(ray: Ray, endpoint: DSPoint, fragmentId: String, fromEnd: Bool)] = []
        
        for ray in rays {
            guard let fragment = fragments.first(where: { $0.id == ray.fragmentId }) else { continue }
            
            let endKey = ray.fromEnd ? "\(fragment.id)_end" : "\(fragment.id)_start"
            
            if !connectedEnds.contains(endKey) {
                unconnectedRays.append((
                    ray: ray,
                    endpoint: ray.fromEnd ? fragment.end : fragment.start,
                    fragmentId: fragment.id,
                    fromEnd: ray.fromEnd
                ))
            }
        }
        
        print("[DiamondSolid] Unconnected rays: \(unconnectedRays.count)")
        
        // Find best pair with minimum gap
        var minGap = Float.infinity
        var bestPair: (ray1: Ray, ray2: Ray, gap: Float)?
        
        for i in 0..<unconnectedRays.count {
            for j in (i+1)..<unconnectedRays.count {
                let ray1Data = unconnectedRays[i]
                let ray2Data = unconnectedRays[j]
                
                if ray1Data.fragmentId == ray2Data.fragmentId { continue }
                
                let gap = ray1Data.endpoint.distance(to: ray2Data.endpoint)
                
                if gap < minGap {
                    minGap = gap
                    bestPair = (ray1: ray1Data.ray, ray2: ray2Data.ray, gap: gap)
                }
            }
        }
        
        guard let pair = bestPair else {
            print("[DiamondSolid] No pairs found to resolve")
            return nil
        }
        
        print("[DiamondSolid] Smallest gap: \(pair.gap)m")
        
        // Look for second intersection with reciprocity
        for ray in [pair.ray1, pair.ray2] {
            var rayIntersections: [(otherRay: Ray, point: DSPoint, distance: Float)] = []
            
            for intersection in intersections {
                if intersection.ray1 === ray {
                    rayIntersections.append((
                        otherRay: intersection.ray2,
                        point: intersection.point,
                        distance: ray.origin.distance(to: intersection.point)
                    ))
                } else if intersection.ray2 === ray {
                    rayIntersections.append((
                        otherRay: intersection.ray1,
                        point: intersection.point,
                        distance: ray.origin.distance(to: intersection.point)
                    ))
                }
            }
            
            rayIntersections.sort { $0.distance < $1.distance }
            
            if rayIntersections.count >= 2 {
                let second = rayIntersections[1]
                if let otherFirst = firstIntersections[second.otherRay],
                   otherFirst.distance(to: second.point) < 0.1 {
                    print("[DiamondSolid] ✅ Reciprocal connection: \(ray.fragmentId) ↔ \(second.otherRay.fragmentId)")
                    
                    return (
                        vertex: second.point,
                        connection: (ray.fragmentId, second.otherRay.fragmentId),
                        ray1: ray,
                        ray2: second.otherRay
                    )
                }
            }
        }
        
        print("[DiamondSolid] No reciprocal connection found")
        return nil
    }
    
    // MARK: - Main Algorithm Step
    
    private func runAlgorithmStep() {
        let currentRays = state.rays
        
        guard !currentRays.isEmpty else { return }
        
        let intersections = calculateIntersections(rays: currentRays)
        let firstIntersections = findFirstIntersections(rays: currentRays, intersections: intersections)
        let mutualConnections = findMutualConnections(rays: currentRays, firstIntersections: firstIntersections)
        
        if mutualConnections.isEmpty && !currentRays.isEmpty {
            // Deadlock - try to resolve
            if let fallback = resolveDeadlock(rays: currentRays, intersections: intersections, firstIntersections: firstIntersections) {
                state.vertices.append(fallback.vertex)
                state.connections.append(fallback.connection)
                state.rays = currentRays.filter { $0 !== fallback.ray1 && $0 !== fallback.ray2 }
            } else {
                print("[DiamondSolid] Deadlock not resolved, terminating")
                state.rays = []
            }
        } else {
            // Process mutual connections
            var raysToRemove: [Ray] = []
            
            for connection in mutualConnections {
                state.vertices.append(connection.point)
                state.connections.append((connection.rays[0].fragmentId, connection.rays[1].fragmentId))
                raysToRemove.append(contentsOf: connection.rays)
            }
            
            state.rays = currentRays.filter { ray in
                !raysToRemove.contains { $0 === ray }
            }
        }
    }
}