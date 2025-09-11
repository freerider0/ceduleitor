function getVirtualLinesFromSegment(segmentStart, segmentEnd, segmentId) {
    // Calculate center point
    const centerX = (segmentStart.x + segmentEnd.x) / 2;
    const centerY = (segmentStart.y + segmentEnd.y) / 2;
    
    // Calculate direction unit vector
    const dx = segmentEnd.x - segmentStart.x;
    const dy = segmentEnd.y - segmentStart.y;
    const length = Math.sqrt(dx * dx + dy * dy);
    const unitX = dx / length;
    const unitY = dy / length;
    
    // Create yellow virtual line (extends from center toward start)
    const yellowLine = {
        center: { x: centerX, y: centerY },
        direction: { x: unitX, y: unitY },
        type: 'yellow',
        segmentId: segmentId,
        getLinePoints: function() {
            return {
                start: {
                    x: this.center.x - this.direction.x * 5000,
                    y: this.center.y - this.direction.y * 5000
                },
                end: this.center
            };
        }
    };
    
    // Create pink virtual line (extends from center toward end)
    const pinkLine = {
        center: { x: centerX, y: centerY },
        direction: { x: unitX, y: unitY },
        type: 'pink',
        segmentId: segmentId,
        getLinePoints: function() {
            return {
                start: this.center,
                end: {
                    x: this.center.x + this.direction.x * 5000,
                    y: this.center.y + this.direction.y * 5000
                }
            };
        }
    };
    
    return {
        yellowLine: yellowLine,
        pinkLine: pinkLine
    };
}

// Example usage:
const start = { x: 100, y: 100 };
const end = { x: 300, y: 200 };
const virtualLines = getVirtualLinesFromSegment(start, end, 0);
console.log(virtualLines.yellowLine);
console.log(virtualLines.pinkLine);




function getAllIntersectionPoints(segments) {
    const intersections = [];
    
    // Helper function to calculate intersection of two infinite lines
    function getLineIntersection(line1Start, line1End, line2Start, line2End) {
        const x1 = line1Start.x;
        const y1 = line1Start.y;
        const x2 = line1End.x;
        const y2 = line1End.y;
        
        const x3 = line2Start.x;
        const y3 = line2Start.y;
        const x4 = line2End.x;
        const y4 = line2End.y;
        
        const denominator = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4);
        
        // Lines are parallel
        if (Math.abs(denominator) < 0.0001) {
            return null;
        }
        
        const t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denominator;
        
        // Calculate intersection point
        const intersectionX = x1 + t * (x2 - x1);
        const intersectionY = y1 + t * (y2 - y1);
        
        return { x: intersectionX, y: intersectionY };
    }
    
    // Get all virtual lines from all segments
    const allVirtualLines = [];
    segments.forEach((segment, segmentIndex) => {
        // Calculate center and direction for this segment
        const centerX = (segment.start.x + segment.end.x) / 2;
        const centerY = (segment.start.y + segment.end.y) / 2;
        const dx = segment.end.x - segment.start.x;
        const dy = segment.end.y - segment.start.y;
        const length = Math.sqrt(dx * dx + dy * dy);
        const unitX = dx / length;
        const unitY = dy / length;
        
        // Add yellow line (extends toward start)
        allVirtualLines.push({
            start: {
                x: centerX - unitX * 5000,
                y: centerY - unitY * 5000
            },
            end: { x: centerX, y: centerY },
            type: 'yellow',
            segmentId: segmentIndex
        });
        
        // Add pink line (extends toward end)
        allVirtualLines.push({
            start: { x: centerX, y: centerY },
            end: {
                x: centerX + unitX * 5000,
                y: centerY + unitY * 5000
            },
            type: 'pink',
            segmentId: segmentIndex
        });
    });
    
    // Find all intersections between virtual lines
    for (let i = 0; i < allVirtualLines.length; i++) {
        for (let j = i + 1; j < allVirtualLines.length; j++) {
            const line1 = allVirtualLines[i];
            const line2 = allVirtualLines[j];
            
            // Don't calculate intersection between lines from same segment
            if (line1.segmentId === line2.segmentId) continue;
            
            const intersection = getLineIntersection(
                line1.start, line1.end,
                line2.start, line2.end
            );
            
            if (intersection) {
                intersections.push({
                    point: intersection,
                    line1: {
                        type: line1.type,
                        segmentId: line1.segmentId
                    },
                    line2: {
                        type: line2.type,
                        segmentId: line2.segmentId
                    }
                });
            }
        }
    }
    
    return intersections;
}

// Example usage:
const segments = [
    { start: { x: 100, y: 100 }, end: { x: 300, y: 200 } },
    { start: { x: 100, y: 300 }, end: { x: 300, y: 100 } }
];

const allIntersections = getAllIntersectionPoints(segments);
console.log(allIntersections);
// Returns array of intersection objects, each with:
// - point: {x, y}
// - line1: {type: 'yellow'|'pink', segmentId: number}
// - line2: {type: 'yellow'|'pink', segmentId: number}


function getUniqueIntersectionPoints(segments) {
    const allIntersections = getAllIntersectionPoints(segments);
    const uniquePoints = new Map();
    
    allIntersections.forEach(intersection => {
        const key = `${Math.round(intersection.point.x)}_${Math.round(intersection.point.y)}`;
        if (!uniquePoints.has(key)) {
            uniquePoints.set(key, intersection.point);
        }
    });
    
    return Array.from(uniquePoints.values());
}

///////////////////////////////////////

/**
 * Finds all vertices that have exactly two segments starting or ending at them
 * @param {Array} segments - Array of segments, where each segment is [[x1, y1], [x2, y2]]
 * @param {Object} options - Configuration options
 * @param {boolean} options.detailed - If true, returns segment indices with each vertex (default: false)
 * @param {number} options.tolerance - Tolerance for vertex comparison (default: 0 for exact match)
 * @param {number} options.segmentCount - Number of segments a vertex must have (default: 2)
 * @returns {Array} Array of vertices or detailed vertex information based on options
 */
function getVerticesBySegmentCount(segments, options = {}) {
  // Default options
  const {
    detailed = false,
    tolerance = 0,
    segmentCount = 2
  } = options;
  
  // Use Map for exact matching, Array for tolerance-based matching
  const useTolerance = tolerance > 0;
  const vertexData = useTolerance ? [] : new Map();
  
  // Helper for exact matching
  const getVertexKey = (x, y) => `${x},${y}`;
  
  // Helper for tolerance-based matching
  const findOrCreateVertex = (x, y, segmentIndex) => {
    let vertex = vertexData.find(v =>
      Math.abs(v.point[0] - x) <= tolerance &&
      Math.abs(v.point[1] - y) <= tolerance
    );
    
    if (!vertex) {
      vertex = { point: [x, y], segments: [] };
      vertexData.push(vertex);
    }
    
    if (!vertex.segments.includes(segmentIndex)) {
      vertex.segments.push(segmentIndex);
    }
    
    return vertex;
  };
  
  // Helper for exact matching
  const addToMap = (x, y, segmentIndex) => {
    const key = getVertexKey(x, y);
    if (!vertexData.has(key)) {
      vertexData.set(key, {
        point: [x, y],
        segments: []
      });
    }
    vertexData.get(key).segments.push(segmentIndex);
  };
  
  // Process all segments
  segments.forEach((segment, index) => {
    const [[x1, y1], [x2, y2]] = segment;
    
    if (useTolerance) {
      findOrCreateVertex(x1, y1, index);
      findOrCreateVertex(x2, y2, index);
    } else {
      addToMap(x1, y1, index);
      addToMap(x2, y2, index);
    }
  });
  
  // Filter vertices by segment count
  let filteredVertices = [];
  
  if (useTolerance) {
    filteredVertices = vertexData.filter(v => v.segments.length === segmentCount);
  } else {
    vertexData.forEach((data) => {
      if (data.segments.length === segmentCount) {
        filteredVertices.push(data);
      }
    });
  }
  
  // Return based on detailed option
  if (detailed) {
    return filteredVertices.map(v => ({
      vertex: v.point,
      connectedSegments: v.segments
    }));
  } else {
    return filteredVertices.map(v => v.point);
  }
}

/**
 * Convenience functions for common use cases
 */
const getVerticesWithTwoSegments = (segments) =>
  getVerticesBySegmentCount(segments);

const getVerticesWithTwoSegmentsDetailed = (segments) =>
  getVerticesBySegmentCount(segments, { detailed: true });

const getEndpoints = (segments) =>
  getVerticesBySegmentCount(segments, { segmentCount: 1 });

const getJunctions = (segments, minConnections = 3) =>
  getVerticesBySegmentCount(segments, { segmentCount: minConnections });

// Example usage:
const exampleSegments = [
  [[0, 0], [1, 1]],   // Segment 0
  [[1, 1], [2, 0]],   // Segment 1
  [[1, 1], [1, 2]],   // Segment 2
  [[2, 0], [3, 0]],   // Segment 3
  [[3, 0], [4, 1]],   // Segment 4
  [[0, 0], [0, 1]]    // Segment 5
];

console.log("=== BASIC USAGE ===");
console.log("Vertices with exactly 2 segments:");
console.log(getVerticesBySegmentCount(exampleSegments));

console.log("\n=== DETAILED OUTPUT ===");
console.log("Vertices with 2 segments (detailed):");
console.log(getVerticesBySegmentCount(exampleSegments, { detailed: true }));

console.log("\n=== WITH TOLERANCE ===");
// Example with floating point coordinates
const floatSegments = [
  [[0.0001, 0], [1, 1]],
  [[0, 0.0001], [1, 2]],  // Should be treated as same starting point with tolerance
  [[1, 1], [2, 0]]
];
console.log("Without tolerance:");
console.log(getVerticesBySegmentCount(floatSegments));
console.log("With tolerance 0.001:");
console.log(getVerticesBySegmentCount(floatSegments, { tolerance: 0.001 }));

console.log("\n=== DIFFERENT SEGMENT COUNTS ===");
console.log("Endpoints (1 segment):");
console.log(getVerticesBySegmentCount(exampleSegments, { segmentCount: 1 }));

console.log("\nJunctions (3+ segments):");
console.log(getVerticesBySegmentCount(exampleSegments, { segmentCount: 3 }));

console.log("\n=== CONVENIENCE FUNCTIONS ===");
console.log("Using convenience function for endpoints:");
console.log(getEndpoints(exampleSegments));

console.log("\nUsing convenience function for detailed two-segment vertices:");
console.log(getVerticesWithTwoSegmentsDetailed(exampleSegments));


////////////////////
