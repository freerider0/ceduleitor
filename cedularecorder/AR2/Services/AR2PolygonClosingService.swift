import Foundation
import simd

/// Service responsible for closing polygons from wall segments
class AR2PolygonClosingService {

    // MARK: - Types

    struct EndpointRay {
        let segmentIndex: Int
        let origin: SIMD2<Float>
        let direction: SIMD2<Float>
        let isFromEnd: Bool
    }

    struct RayIntersection {
        let point: SIMD2<Float>
        let otherRayIndex: Int
        let distance: Float
    }

    struct SegmentIntersection {
        let segment1Index: Int
        let segment2Index: Int
        let point: SIMD2<Float>
    }

    // MARK: - Public API

    /// Main entry point - called every time segments change
    func updatePolygon(segments: [AR2WallSegment]) -> AR2RoomPolygon? {
        guard segments.count >= 2 else { return nil }

        var debugInfo = AR2PolygonDebugInfo()

        // Step 1: Clean intersections
        let cleanedSegments = cleanIntersections(segments)
        debugInfo.cleanedSegments = cleanedSegments

        // Step 2: Find vertices and extend segments (with debug info)
        let (extendedSegments, rays, vertices) = findVerticesAndExtendWithDebug(cleanedSegments)
        debugInfo.rays = rays
        debugInfo.possibleVertices = vertices
        debugInfo.extendedSegments = extendedSegments

        // For now, just return cleaned segments as polygon vertices for visualization
        // Step 3 is disabled as requested
        var polygon = AR2RoomPolygon(vertices: [], isClosed: false)
        polygon.debugInfo = debugInfo

        // Build a simple polygon from the segments for visualization
        if let firstSegment = extendedSegments.first {
            polygon.vertices.append(firstSegment.start)
            polygon.vertices.append(firstSegment.end)

            var remainingSegments = Array(extendedSegments.dropFirst())

            while !remainingSegments.isEmpty {
                let lastVertex = polygon.vertices.last!
                var foundNext = false

                for (index, segment) in remainingSegments.enumerated() {
                    if distance(lastVertex, segment.start) < 0.1 {
                        polygon.vertices.append(segment.end)
                        remainingSegments.remove(at: index)
                        foundNext = true
                        break
                    } else if distance(lastVertex, segment.end) < 0.1 {
                        polygon.vertices.append(segment.start)
                        remainingSegments.remove(at: index)
                        foundNext = true
                        break
                    }
                }

                if !foundNext {
                    break
                }
            }

            if let first = polygon.vertices.first, let last = polygon.vertices.last {
                polygon.isClosed = distance(first, last) < 0.5
            }
        }

        return polygon
    }

    // MARK: - Step 1: Clean Intersections

    private func cleanIntersections(_ segments: [AR2WallSegment]) -> [AR2WallSegment] {
        var result = segments
        var hasIntersections = true
        var iterations = 0
        let maxIterations = 10

        while hasIntersections && iterations < maxIterations {
            hasIntersections = false
            iterations += 1

            if let intersection = findFirstIntersection(result) {
                hasIntersections = true
                result = handleIntersection(result, intersection)
            }
        }

        return result
    }

    private func findFirstIntersection(_ segments: [AR2WallSegment]) -> SegmentIntersection? {
        for i in 0..<segments.count {
            for j in (i + 1)..<segments.count {
                if let point = segmentIntersectionPoint(segments[i], segments[j]) {
                    // Check if it's not just endpoints touching
                    if !isEndpointTouch(point, segments[i], segments[j]) {
                        return SegmentIntersection(
                            segment1Index: i,
                            segment2Index: j,
                            point: point
                        )
                    }
                }
            }
        }
        return nil
    }

    private func handleIntersection(_ segments: [AR2WallSegment], _ intersection: SegmentIntersection) -> [AR2WallSegment] {
        var result = segments

        let seg1 = segments[intersection.segment1Index]
        let seg2 = segments[intersection.segment2Index]
        let point = intersection.point

        // Split both segments
        let pieces = [
            AR2WallSegment(start: seg1.start, end: point, color: seg1.color),
            AR2WallSegment(start: point, end: seg1.end, color: seg1.color),
            AR2WallSegment(start: seg2.start, end: point, color: seg2.color),
            AR2WallSegment(start: point, end: seg2.end, color: seg2.color)
        ]

        // Find shortest piece
        let shortestIndex = pieces.enumerated().min(by: {
            distance($0.element.start, $0.element.end) < distance($1.element.start, $1.element.end)
        })!.offset

        // Keep all except shortest
        let keptPieces = pieces.enumerated().compactMap { $0.offset != shortestIndex ? $0.element : nil }

        // Remove original segments (larger index first)
        let indices = [intersection.segment1Index, intersection.segment2Index].sorted(by: >)
        for index in indices {
            result.remove(at: index)
        }

        // Add kept pieces
        result.append(contentsOf: keptPieces)

        return result
    }

    // MARK: - Step 2: Find Vertices and Extend

    private func findVerticesAndExtend(_ segments: [AR2WallSegment]) -> [AR2WallSegment] {
        var current = segments
        let maxIterations = 5  // Keep it fast for real-time

        for _ in 0..<maxIterations {
            let rays = createRaysFromUnconnectedEndpoints(current)

            if rays.isEmpty {
                break  // All connected
            }

            // Try to find vertex
            var vertex: SIMD2<Float>? = nil

            // Try mutual first
            vertex = findMutualFirstVertex(rays)

            // If deadlock, try first-to-second
            if vertex == nil {
                vertex = findFirstToSecondVertex(rays)
            }

            // Extend segments to vertex
            if let vertex = vertex {
                current = extendSegmentsToVertex(current, vertex, rays)
            } else {
                break  // Can't find more vertices
            }
        }

        return current
    }

    private func findVerticesAndExtendWithDebug(_ segments: [AR2WallSegment]) -> ([AR2WallSegment], [AR2PolygonDebugInfo.Ray], [AR2PolygonDebugInfo.PossibleVertex]) {
        var current = segments
        var debugRays: [AR2PolygonDebugInfo.Ray] = []
        var debugVertices: [AR2PolygonDebugInfo.PossibleVertex] = []

        // Maximum iterations to prevent infinite loops
        let maxIterations = 10
        var iteration = 0

        while iteration < maxIterations {
            iteration += 1

            // Create rays from current unconnected endpoints
            let rays = createRaysFromUnconnectedEndpoints(current)

            // Update debug rays for visualization (only from latest rays)
            if iteration == 1 {
                debugRays = rays.map { ray in
                    AR2PolygonDebugInfo.Ray(
                        origin: ray.origin,
                        direction: ray.direction,
                        isFromEnd: ray.isFromEnd,
                        segmentIndex: ray.segmentIndex
                    )
                }
            }

            if rays.isEmpty {
                return (current, debugRays, debugVertices)  // All connected
            }

            // Calculate ALL intersections for current rays
            var allIntersections: [(rayIdx1: Int, rayIdx2: Int?, segmentIdx: Int?, point: SIMD2<Float>)] = []

        // Ray-to-ray intersections
        for i in 0..<rays.count {
            for j in (i + 1)..<rays.count {
                if rays[i].segmentIndex != rays[j].segmentIndex {
                    if let intersection = rayRayIntersection(rays[i], rays[j]) {
                        // Check if intersection is forward for both rays
                        let toIntersection1 = intersection - rays[i].origin
                        let toIntersection2 = intersection - rays[j].origin
                        let alongRay1 = dot(normalize(toIntersection1), rays[i].direction)
                        let alongRay2 = dot(normalize(toIntersection2), rays[j].direction)

                        if alongRay1 > 0 && alongRay2 > 0 && distance(rays[i].origin, intersection) < 100.0 && distance(rays[j].origin, intersection) < 100.0 {
                            allIntersections.append((i, j, nil, intersection))
                            debugVertices.append(AR2PolygonDebugInfo.PossibleVertex(
                                position: intersection,
                                type: .rayIntersection
                            ))
                        }
                    }
                }
            }
        }

        // Ray-to-segment intersections
        for (rayIdx, ray) in rays.enumerated() {
            for (segIdx, segment) in current.enumerated() {
                // Don't check ray against its own segment
                if ray.segmentIndex != segIdx {
                    if let intersection = raySegmentIntersection(ray, segment) {
                        let toIntersection = intersection - ray.origin
                        let alongRay = dot(normalize(toIntersection), ray.direction)

                        if alongRay > 0 && distance(ray.origin, intersection) < 100.0 {
                            allIntersections.append((rayIdx, nil, segIdx, intersection))
                            debugVertices.append(AR2PolygonDebugInfo.PossibleVertex(
                                position: intersection,
                                type: .rayIntersection
                            ))
                        }
                    }
                }
            }
        }

        // Find best vertex to extend to
        var foundExtension = false
        var vertex: SIMD2<Float>? = nil
        var rayIndicesForVertex: [Int] = []

            // First, check for ray-to-segment intersections (priority vertices)
            var foundRaySegment = false
            for intersection in allIntersections where intersection.segmentIdx != nil {
                let rayIdx = intersection.rayIdx1
                let segIdx = intersection.segmentIdx!

                // Check if this is the first intersection for the ray
                var isFirst = true
                for other in allIntersections {
                    if (other.rayIdx1 == rayIdx || other.rayIdx2 == rayIdx) && other.point != intersection.point {
                        if distance(rays[rayIdx].origin, other.point) < distance(rays[rayIdx].origin, intersection.point) {
                            isFirst = false
                            break
                        }
                    }
                }

                if isFirst {
                    vertex = intersection.point
                    rayIndicesForVertex = [rayIdx]
                    foundRaySegment = true

                    debugVertices.append(AR2PolygonDebugInfo.PossibleVertex(
                        position: intersection.point,
                        type: .extended
                    ))

                    // Extend the ray's segment to vertex
                    let relevantRays = [rays[rayIdx]]
                    current = extendSegmentsToVertex(current, vertex!, relevantRays)

                    // Shorten the hit segment
                    current = shortenSegmentToVertex(current, segIdx, vertex!, rays[rayIdx])

                    foundExtension = true
                    break  // Found one, process it
                }
            }

            // If no ray-segment intersection, try mutual ray-ray intersections
            if vertex == nil {
                for intersection in allIntersections where intersection.rayIdx2 != nil {
                    let i = intersection.rayIdx1
                    let j = intersection.rayIdx2!

                    // Check if this is the first intersection for ray i
                    var isFirstForI = true
                    for other in allIntersections {
                        if (other.rayIdx1 == i || other.rayIdx2 == i) && other.point != intersection.point {
                            if distance(rays[i].origin, other.point) < distance(rays[i].origin, intersection.point) {
                                isFirstForI = false
                                break
                            }
                        }
                    }

                    // Check if this is the first intersection for ray j
                    var isFirstForJ = true
                    for other in allIntersections {
                        if (other.rayIdx1 == j || other.rayIdx2 == j) && other.point != intersection.point {
                            if distance(rays[j].origin, other.point) < distance(rays[j].origin, intersection.point) {
                                isFirstForJ = false
                                break
                            }
                        }
                    }

                    // If mutual first, use this vertex
                    if isFirstForI && isFirstForJ {
                        vertex = intersection.point
                        rayIndicesForVertex = [i, j]
                        debugVertices.append(AR2PolygonDebugInfo.PossibleVertex(
                            position: intersection.point,
                            type: .mutual
                        ))
                        foundExtension = true
                        break
                    }
                }
            }

            // No mutual first? Look for smallest gap with 1st-2nd pattern
            if vertex == nil {
                // Find unconnected endpoints
                var gaps: [(endRayIdx: Int, startRayIdx: Int, distance: Float)] = []

                for (idx, ray) in rays.enumerated() {
                    if ray.isFromEnd {  // This is an end point
                        for (idx2, ray2) in rays.enumerated() {
                            if !ray2.isFromEnd && ray.segmentIndex != ray2.segmentIndex {  // This is a start point from different segment
                                let gap = distance(ray.origin, ray2.origin)
                                gaps.append((idx, idx2, gap))
                            }
                        }
                    }
                }

                // Sort by distance
                gaps.sort { $0.distance < $1.distance }

                // Check smallest gaps for 1st-2nd pattern
                for gap in gaps {
                    // Find intersection between these two rays
                    var intersectionPoint: SIMD2<Float>? = nil
                    for inter in allIntersections {
                        if let rayIdx2 = inter.rayIdx2 {
                            if (inter.rayIdx1 == gap.endRayIdx && rayIdx2 == gap.startRayIdx) ||
                               (inter.rayIdx1 == gap.startRayIdx && rayIdx2 == gap.endRayIdx) {
                                intersectionPoint = inter.point
                                break
                            }
                        }
                    }

                    if let intersection = intersectionPoint {
                        // Count how many intersections are closer for each ray
                        var endRayOrder = 1
                        var startRayOrder = 1

                        for other in allIntersections {
                            if (other.rayIdx1 == gap.endRayIdx || other.rayIdx2 == gap.endRayIdx) && other.point != intersection {
                                if distance(rays[gap.endRayIdx].origin, other.point) < distance(rays[gap.endRayIdx].origin, intersection) {
                                    endRayOrder += 1
                                }
                            }
                            if (other.rayIdx1 == gap.startRayIdx || other.rayIdx2 == gap.startRayIdx) && other.point != intersection {
                                if distance(rays[gap.startRayIdx].origin, other.point) < distance(rays[gap.startRayIdx].origin, intersection) {
                                    startRayOrder += 1
                                }
                            }
                        }

                        // Check for 1st-2nd or 2nd-1st pattern
                        if (endRayOrder == 1 && startRayOrder == 2) || (endRayOrder == 2 && startRayOrder == 1) {
                            vertex = intersection
                            rayIndicesForVertex = [gap.endRayIdx, gap.startRayIdx]
                            debugVertices.append(AR2PolygonDebugInfo.PossibleVertex(
                                position: intersection,
                                type: .extended
                            ))
                            foundExtension = true
                            break
                        }
                    }
                }
            }

            // Extend segments to vertex if found
            if foundExtension && vertex != nil {
                if !foundRaySegment {
                    // Only pass the specific rays that created this intersection
                    let relevantRays = rayIndicesForVertex.map { rays[$0] }
                    current = extendSegmentsToVertex(current, vertex!, relevantRays)
                }
                // Continue to next iteration with new segments
            } else {
                // No more extensions found, exit outer loop
                break
            }
        }

        return (current, debugRays, debugVertices)
    }

    private func createRaysFromUnconnectedEndpoints(_ segments: [AR2WallSegment]) -> [EndpointRay] {
        var rays: [EndpointRay] = []

        for (index, segment) in segments.enumerated() {
            let dir = normalize(segment.end - segment.start)

            // For unconnected start: we want to find where this wall begins
            // So ray should point OPPOSITE to wall direction (where did we come from?)
            if !isEndpointConnected(segment.start, segments, excluding: index) {
                rays.append(EndpointRay(
                    segmentIndex: index,
                    origin: segment.start,
                    direction: -dir,  // Look backward from start
                    isFromEnd: false
                ))
            }

            // For unconnected end: we want to find where this wall continues
            // So ray should point IN wall direction (where are we going?)
            if !isEndpointConnected(segment.end, segments, excluding: index) {
                rays.append(EndpointRay(
                    segmentIndex: index,
                    origin: segment.end,
                    direction: dir,  // Look forward from end
                    isFromEnd: true
                ))
            }
        }

        return rays
    }

    private func findMutualFirstVertex(_ rays: [EndpointRay]) -> SIMD2<Float>? {
        for i in 0..<rays.count {
            let intersections = findAllIntersectionsForRay(rays[i], rays)

            if let closest = intersections.first {
                // Check if it's mutual
                let otherIntersections = findAllIntersectionsForRay(rays[closest.otherRayIndex], rays)

                if let otherClosest = otherIntersections.first {
                    if otherClosest.otherRayIndex == i && distance(closest.point, otherClosest.point) < 0.01 {
                        return closest.point
                    }
                }
            }
        }

        return nil
    }

    private func findFirstToSecondVertex(_ rays: [EndpointRay]) -> SIMD2<Float>? {
        // Find pair with smallest gap
        var bestPair: (Int, Int)? = nil
        var smallestGap = Float.infinity

        for i in 0..<rays.count {
            for j in (i + 1)..<rays.count {
                if rays[i].segmentIndex != rays[j].segmentIndex {
                    let gap = distance(rays[i].origin, rays[j].origin)
                    if gap < smallestGap {
                        smallestGap = gap
                        bestPair = (i, j)
                    }
                }
            }
        }

        guard let pair = bestPair, smallestGap < 3.0 else { return nil }

        let ray1Intersections = findAllIntersectionsForRay(rays[pair.0], rays)
        let ray2Intersections = findAllIntersectionsForRay(rays[pair.1], rays)

        // Check combinations
        if ray1Intersections.count > 0 && ray2Intersections.count > 0 {
            // First-first
            if distance(ray1Intersections[0].point, ray2Intersections[0].point) < 0.1 {
                return ray1Intersections[0].point
            }
        }

        if ray1Intersections.count > 0 && ray2Intersections.count > 1 {
            // First-second
            if distance(ray1Intersections[0].point, ray2Intersections[1].point) < 0.1 {
                return ray1Intersections[0].point
            }
        }

        if ray1Intersections.count > 1 && ray2Intersections.count > 0 {
            // Second-first
            if distance(ray1Intersections[1].point, ray2Intersections[0].point) < 0.1 {
                return ray1Intersections[1].point
            }
        }

        // Last resort: direct ray intersection
        if let directPoint = rayRayIntersection(rays[pair.0], rays[pair.1]) {
            return directPoint
        }

        return nil
    }

    private func findAllIntersectionsForRay(_ ray: EndpointRay, _ allRays: [EndpointRay]) -> [RayIntersection] {
        var intersections: [RayIntersection] = []

        for (index, otherRay) in allRays.enumerated() {
            // Skip same ray and rays from same segment
            if otherRay.origin == ray.origin || otherRay.segmentIndex == ray.segmentIndex {
                continue
            }

            if let point = rayRayIntersection(ray, otherRay) {
                let dist = distance(ray.origin, point)
                intersections.append(RayIntersection(
                    point: point,
                    otherRayIndex: index,
                    distance: dist
                ))
            }
        }

        // Sort by distance
        return intersections.sorted { $0.distance < $1.distance }
    }

    private func shortenSegmentToVertex(_ segments: [AR2WallSegment], _ segmentIndex: Int, _ vertex: SIMD2<Float>, _ ray: EndpointRay) -> [AR2WallSegment] {
        var result = segments
        let segment = segments[segmentIndex]

        // Determine which endpoint is closer to the vertex
        let distToStart = distance(segment.start, vertex)
        let distToEnd = distance(segment.end, vertex)

        if distToStart < distToEnd {
            // Shorten from start
            result[segmentIndex] = AR2WallSegment(
                start: vertex,
                end: segment.end,
                color: segment.color
            )
        } else {
            // Shorten from end
            result[segmentIndex] = AR2WallSegment(
                start: segment.start,
                end: vertex,
                color: segment.color
            )
        }

        return result
    }

    private func extendSegmentsToVertex(_ segments: [AR2WallSegment], _ vertex: SIMD2<Float>, _ rays: [EndpointRay]) -> [AR2WallSegment] {
        var result = segments

        for ray in rays {
            // Check if ray points toward vertex
            let toVertex = vertex - ray.origin
            let alongRay = dot(normalize(toVertex), ray.direction)

            // Only extend if vertex is in front of the ray and within reasonable distance
            // Use -0.1 tolerance to handle floating point precision issues
            if alongRay > -0.1 && distance(ray.origin, vertex) < 100.0 {
                let segment = result[ray.segmentIndex]

                if ray.isFromEnd {
                    // Extending from end point - set end to vertex
                    result[ray.segmentIndex] = AR2WallSegment(
                        start: segment.start,
                        end: vertex,
                        color: segment.color
                    )
                } else {
                    // Extending from start point - set start to vertex
                    result[ray.segmentIndex] = AR2WallSegment(
                        start: vertex,
                        end: segment.end,
                        color: segment.color
                    )
                }
            }
        }

        return result
    }

    // MARK: - Step 3: Build Polygon

    private func buildPolygon(from segments: [AR2WallSegment]) -> AR2RoomPolygon? {
        guard segments.count >= 2 else { return nil }

        var vertices: [SIMD2<Float>] = []
        var remainingSegments = segments

        // Start with first segment
        guard let first = remainingSegments.first else { return nil }
        remainingSegments.removeFirst()

        vertices.append(first.start)
        vertices.append(first.end)

        // Try to connect segments
        while !remainingSegments.isEmpty {
            let lastVertex = vertices.last!
            var foundNext = false

            for (index, segment) in remainingSegments.enumerated() {
                if distance(lastVertex, segment.start) < 0.1 {
                    vertices.append(segment.end)
                    remainingSegments.remove(at: index)
                    foundNext = true
                    break
                } else if distance(lastVertex, segment.end) < 0.1 {
                    vertices.append(segment.start)
                    remainingSegments.remove(at: index)
                    foundNext = true
                    break
                }
            }

            if !foundNext {
                break
            }
        }

        // Check if polygon closes
        if let firstVertex = vertices.first, let lastVertex = vertices.last {
            let isClosed = distance(firstVertex, lastVertex) < 0.5

            // Remove duplicate last vertex if it's the same as first
            if isClosed && distance(firstVertex, lastVertex) < 0.01 {
                vertices.removeLast()
            }

            return AR2RoomPolygon(vertices: vertices, isClosed: isClosed)
        }

        return nil
    }

    // MARK: - Helper Functions

    private func segmentIntersectionPoint(_ seg1: AR2WallSegment, _ seg2: AR2WallSegment) -> SIMD2<Float>? {
        let p1 = seg1.start
        let p2 = seg1.end
        let p3 = seg2.start
        let p4 = seg2.end

        let d1 = p2 - p1
        let d2 = p4 - p3
        let d3 = p3 - p1

        let cross = d1.x * d2.y - d1.y * d2.x

        if abs(cross) < 0.0001 {
            return nil  // Parallel
        }

        let t = (d3.x * d2.y - d3.y * d2.x) / cross
        let s = (d3.x * d1.y - d3.y * d1.x) / cross

        if t >= 0 && t <= 1 && s >= 0 && s <= 1 {
            return p1 + t * d1
        }

        return nil
    }

    private func rayRayIntersection(_ ray1: EndpointRay, _ ray2: EndpointRay) -> SIMD2<Float>? {
        let cross = ray1.direction.x * ray2.direction.y - ray1.direction.y * ray2.direction.x

        if abs(cross) < 0.0001 {
            return nil  // Parallel
        }

        let diff = ray2.origin - ray1.origin
        let t = (diff.x * ray2.direction.y - diff.y * ray2.direction.x) / cross
        let s = (diff.x * ray1.direction.y - diff.y * ray1.direction.x) / cross

        if t > 0.01 && s > 0.01 {  // Both forward
            return ray1.origin + t * ray1.direction
        }

        return nil
    }

    private func raySegmentIntersection(_ ray: EndpointRay, _ segment: AR2WallSegment) -> SIMD2<Float>? {
        let segDir = segment.end - segment.start
        let cross = ray.direction.x * segDir.y - ray.direction.y * segDir.x

        if abs(cross) < 0.0001 {
            return nil  // Parallel
        }

        let diff = segment.start - ray.origin
        let t = (diff.x * segDir.y - diff.y * segDir.x) / cross  // Distance along ray
        let s = (diff.x * ray.direction.y - diff.y * ray.direction.x) / cross  // Position along segment

        // t > 0.01: intersection is forward along ray
        // 0 < s < 1: intersection is within segment bounds
        if t > 0.01 && s > 0 && s < 1 {
            return ray.origin + t * ray.direction
        }

        return nil
    }

    private func isEndpointTouch(_ point: SIMD2<Float>, _ seg1: AR2WallSegment, _ seg2: AR2WallSegment) -> Bool {
        let tolerance: Float = 0.01
        return distance(point, seg1.start) < tolerance ||
               distance(point, seg1.end) < tolerance ||
               distance(point, seg2.start) < tolerance ||
               distance(point, seg2.end) < tolerance
    }

    private func isEndpointConnected(_ point: SIMD2<Float>, _ segments: [AR2WallSegment], excluding index: Int) -> Bool {
        let tolerance: Float = 0.01

        for (i, segment) in segments.enumerated() {
            if i == index { continue }

            if distance(point, segment.start) < tolerance ||
               distance(point, segment.end) < tolerance {
                return true
            }
        }

        return false
    }

    private func distance(_ p1: SIMD2<Float>, _ p2: SIMD2<Float>) -> Float {
        return simd_distance(p1, p2)
    }

    private func normalize(_ v: SIMD2<Float>) -> SIMD2<Float> {
        let length = simd_length(v)
        return length > 0 ? v / length : v
    }
}