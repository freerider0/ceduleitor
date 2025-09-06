import RealityKit
import ARKit
import simd

// ================================================================================
// MARK: - Ring Indicator Component
// ================================================================================

/// Manages the ring indicator that shows where the user is pointing
final class RingIndicator {
    
    // MARK: - Properties
    
    private var ringEntity: Entity?
    private var ringAnchor: AnchorEntity?
    private let greenMaterial: UnlitMaterial
    private let blueMaterial: UnlitMaterial
    
    // MARK: - Initialization
    
    init() {
        // Pre-create materials to avoid recreating every frame
        self.greenMaterial = UnlitMaterial(color: .green)
        self.blueMaterial = UnlitMaterial(color: .systemBlue)
    }
    
    // ================================================================================
    // MARK: - Setup
    // ================================================================================
    
    /// Setup the ring indicator in the AR scene
    @MainActor
    func setup(in arView: ARView) {
        // Create ring mesh using LowLevelMesh
        guard let ringMesh = createRingMesh() else {
            print("Failed to create ring mesh")
            return
        }
        
        // Create the ring model
        let ring = ModelEntity(mesh: ringMesh, materials: [greenMaterial])
        ringEntity = ring
        
        // Create anchor for ring
        ringAnchor = AnchorEntity(world: .zero)
        ringAnchor?.addChild(ring)
        ringAnchor?.isEnabled = false // Initially hidden
        
        // Add to scene
        arView.scene.addAnchor(ringAnchor!)
    }
    
    // ================================================================================
    // MARK: - Update
    // ================================================================================
    
    /// Update ring position and appearance based on raycast result
    func update(with result: ARRaycastResult, isVertical: Bool) {
        guard let ring = ringEntity as? ModelEntity,
              let anchor = ringAnchor else { return }
        
        // Get exact hit position from raycast
        let hitPosition = simd_float3(
            result.worldTransform.columns.3.x,
            result.worldTransform.columns.3.y,
            result.worldTransform.columns.3.z
        )
        
        // Get surface normal
        let normal = simd_float3(
            result.worldTransform.columns.2.x,
            result.worldTransform.columns.2.y,
            result.worldTransform.columns.2.z
        )
        
        // The raycast transform has Z pointing OUT from the surface
        // We need to rotate the ring to lie flat on the surface
        anchor.transform = Transform(matrix: result.worldTransform)
        
        // Rotate -90 degrees around local X axis to flip the ring down onto the surface
        let rotation = simd_quatf(angle: -.pi/2, axis: [1, 0, 0])
        anchor.orientation = anchor.orientation * rotation
        
        // Set position with small offset to prevent z-fighting
        anchor.position = hitPosition + normal * 0.001
        
        // Update material based on surface type
        ring.model?.materials = isVertical ? [greenMaterial] : [blueMaterial]
        
        // Show the ring
        anchor.isEnabled = true
    }
    
    /// Hide the ring indicator
    func hide() {
        ringAnchor?.isEnabled = false
    }
    
    /// Flash the ring for visual feedback
    func flash() {
        guard let anchor = ringAnchor else { return }
        
        // Quick scale animation
        let originalScale = anchor.scale
        anchor.scale = originalScale * 1.3
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.ringAnchor?.scale = originalScale
        }
    }
    
    // ================================================================================
    // MARK: - Mesh Creation
    // ================================================================================
    
    /// Create a flat ring mesh using LowLevelMesh
    @MainActor
    private func createRingMesh() -> MeshResource? {
        let innerRadius: Float = 0.08
        let outerRadius: Float = 0.12
        let segments: Int = 64
        
        // Calculate vertex count: (segments + 1) * 2 for inner and outer circles
        let vertexCount = (segments + 1) * 2
        let indexCount = segments * 2 * 3 // 2 triangles per segment, 3 indices per triangle
        
        // Define vertex attributes
        let positionAttribute = LowLevelMesh.Attribute(
            semantic: .position,
            format: .float3,
            offset: 0
        )
        let normalAttribute = LowLevelMesh.Attribute(
            semantic: .normal,
            format: .float3,
            offset: MemoryLayout<simd_float3>.size
        )
        
        let vertexAttributes = [positionAttribute, normalAttribute]
        let vertexStride = MemoryLayout<simd_float3>.size * 2
        let vertexLayouts = [LowLevelMesh.Layout(bufferIndex: 0, bufferStride: vertexStride)]
        
        // Create mesh descriptor
        let meshDescriptor = LowLevelMesh.Descriptor(
            vertexCapacity: vertexCount,
            vertexAttributes: vertexAttributes,
            vertexLayouts: vertexLayouts,
            indexCapacity: indexCount
        )
        
        // Create the low-level mesh
        guard let mesh = try? LowLevelMesh(descriptor: meshDescriptor) else {
            print("Failed to create LowLevelMesh")
            return nil
        }
        
        // Fill vertex buffer
        mesh.withUnsafeMutableBytes(bufferIndex: 0) { rawBytes in
            let vertexData = rawBytes.bindMemory(to: simd_float3.self)
            var vertexIndex = 0
            
            for i in 0...segments {
                let angle = Float(i) * (2.0 * .pi) / Float(segments)
                let cosA = cos(angle)
                let sinA = sin(angle)
                
                // Outer circle vertex
                vertexData[vertexIndex] = simd_float3(cosA * outerRadius, sinA * outerRadius, 0)
                vertexData[vertexIndex + 1] = simd_float3(0, 0, 1) // normal
                vertexIndex += 2
                
                // Inner circle vertex
                vertexData[vertexIndex] = simd_float3(cosA * innerRadius, sinA * innerRadius, 0)
                vertexData[vertexIndex + 1] = simd_float3(0, 0, 1) // normal
                vertexIndex += 2
            }
        }
        
        // Fill index buffer
        mesh.withUnsafeMutableIndices { rawIndices in
            guard let indices = rawIndices.baseAddress?.assumingMemoryBound(to: UInt32.self) else { return }
            
            var idx = 0
            for i in 0..<segments {
                let outerCurrent = UInt32(i * 2)
                let innerCurrent = UInt32(i * 2 + 1)
                let outerNext = UInt32((i + 1) * 2)
                let innerNext = UInt32((i + 1) * 2 + 1)
                
                // First triangle (counterclockwise)
                indices[idx] = outerCurrent
                indices[idx + 1] = outerNext
                indices[idx + 2] = innerCurrent
                
                // Second triangle (counterclockwise)
                indices[idx + 3] = innerCurrent
                indices[idx + 4] = outerNext
                indices[idx + 5] = innerNext
                
                idx += 6
            }
        }
        
        // Set mesh parts
        let bounds = BoundingBox(
            min: [-outerRadius, -outerRadius, -0.01],
            max: [outerRadius, outerRadius, 0.01]
        )
        
        mesh.parts.replaceAll([
            LowLevelMesh.Part(
                indexCount: indexCount,
                topology: .triangle,
                bounds: bounds
            )
        ])
        
        return try? MeshResource(from: mesh)
    }
}