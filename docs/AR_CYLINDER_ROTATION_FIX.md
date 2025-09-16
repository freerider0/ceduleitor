# AR Cylinder Rotation Fix - Positioning Tubes Between Points

## Problem Description
When drawing tubes (cylinders) between vertices in AR to form a polygon outline on floor/ceiling, the tubes appeared at completely wrong positions even though:
- Vertices (spheres) were positioned correctly
- The tube center position was calculated correctly
- The tubes were visible but misaligned

## Root Cause
The issue was with the **rotation calculation** for the cylinders. RealityKit cylinders are created vertically (along Y-axis) by default. To position them between two arbitrary 3D points, they need to be rotated to align with the line between those points.

## The Wrong Approach (What Failed)
```swift
// INCORRECT - Two-step rotation
let horizontalRotation = simd_quatf(angle: Float.pi / 2, axis: SIMD3<Float>(0, 0, 1))
let dx = to.x - from.x
let dz = to.z - from.z
let angleY = atan2(dx, dz)
let yRotation = simd_quatf(angle: angleY, axis: SIMD3<Float>(0, 1, 0))
entity.orientation = yRotation * horizontalRotation
```

This approach:
1. First rotated 90° around Z-axis (making cylinder horizontal but pointing along X-axis)
2. Then rotated around Y-axis to aim toward target

**Why it failed:** The compound rotation doesn't correctly handle arbitrary 3D directions. The cylinder would end up pointing in wrong directions, making it appear at wrong positions even though its center was correct.

## The Correct Solution
```swift
// CORRECT - Direct single rotation
let direction = normalize(to - from)
let up = SIMD3<Float>(0, 1, 0)  // Cylinder's default orientation
let dot = simd_dot(up, direction)

if abs(dot - 1.0) < 0.001 {
    // Already aligned with Y axis
} else if abs(dot + 1.0) < 0.001 {
    // Opposite direction
    entity.orientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(1, 0, 0))
} else {
    let axis = normalize(simd_cross(up, direction))
    let angle = acos(dot)
    entity.orientation = simd_quatf(angle: angle, axis: axis)
}
```

This approach:
1. Calculates the direction vector from start to end point
2. Uses **cross product** to find the rotation axis (perpendicular to both up and direction)
3. Uses **dot product** to find the rotation angle
4. Creates a single quaternion rotation

## Key Concepts

### Cylinder Default Orientation
- RealityKit cylinders are created vertically (along positive Y-axis)
- Height extends along Y-axis
- To align between two points, must rotate from Y-up to the line direction

### Cross Product for Rotation Axis
- `cross(up, direction)` gives the axis perpendicular to both vectors
- This is the axis to rotate around to align up with direction

### Dot Product for Rotation Angle
- `dot(up, direction)` = cos(angle) between vectors
- `acos(dot)` gives the rotation angle needed

### Edge Cases
- When already aligned (dot ≈ 1): No rotation needed
- When opposite (dot ≈ -1): 180° rotation around any perpendicular axis
- Handle these to avoid NaN from acos or normalize

## Visual Debugging Tips

When cylinders appear mispositioned:

1. **Check center position first**
   - Add debug sphere at `(from + to) / 2`
   - If sphere is correct but cylinder isn't, it's a rotation issue

2. **Verify endpoints**
   - Add debug spheres at `from` and `to` points
   - Cylinder should connect these points

3. **Test with axis-aligned cases**
   - Try points along X, Y, or Z axes first
   - These simple cases help identify rotation issues

4. **Check coordinate spaces**
   - Ensure all points are in same coordinate system
   - ARKit world coordinates vs local coordinates can cause issues

## Common Pitfalls

1. **Multi-step rotations**: Avoid combining multiple rotations unless necessary
2. **Assuming 2D**: Floor/ceiling polygons are still in 3D space
3. **Wrong rotation order**: Quaternion multiplication order matters
4. **Not normalizing**: Always normalize direction vectors before cross/dot products

## Application in this Project

This fix was crucial for displaying room polygons in AR:
- Tubes connect wall vertices to show room outline
- Displayed on detected floor and ceiling planes
- Creates visual feedback as user scans walls
- Shows both original walls and extended/closed polygons

The correct rotation ensures tubes align perfectly with vertices, creating a coherent polygon visualization that helps users understand the room shape being captured.