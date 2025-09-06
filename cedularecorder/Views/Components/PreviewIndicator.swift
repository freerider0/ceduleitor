import RealityKit
import ARKit
import simd

// ================================================================================
// MARK: - Preview Indicator Component
// ================================================================================

/// Manages the preview circle and vertical beam for corner placement
final class PreviewIndicator {
    
    // MARK: - Properties
    
    private var previewCircle: ModelEntity?
    private var previewBeam: ModelEntity?
    private var previewAnchor: AnchorEntity?
    
    // MARK: - Setup
    
    /// Setup preview entities in the AR scene
    func setup(in arView: ARView) {
        // Create preview circle (flat plane on floor)
        let circleMesh = MeshResource.generatePlane(
            width: 0.15,
            depth: 0.15,
            cornerRadius: 0.075
        )
        let circleMaterial = SimpleMaterial(
            color: UIColor.red.withAlphaComponent(0.6),
            isMetallic: false
        )
        previewCircle = ModelEntity(mesh: circleMesh, materials: [circleMaterial])
        previewCircle?.transform.rotation = simd_quatf(angle: -.pi/2, axis: [1, 0, 0])
        
        // Create vertical beam (thin cylinder)
        let beamMesh = MeshResource.generateCylinder(height: 3.0, radius: 0.02)
        let beamMaterial = SimpleMaterial(
            color: UIColor.red.withAlphaComponent(0.3),
            isMetallic: false
        )
        previewBeam = ModelEntity(mesh: beamMesh, materials: [beamMaterial])
        previewBeam?.position.y = 1.5  // Center at 1.5m height
        
        // Create anchor for preview
        previewAnchor = AnchorEntity(world: .zero)
        if let circle = previewCircle, let beam = previewBeam {
            previewAnchor?.addChild(circle)
            previewAnchor?.addChild(beam)
        }
        
        // Initially hide preview
        previewAnchor?.isEnabled = false
        
        if let anchor = previewAnchor {
            arView.scene.addAnchor(anchor)
        }
    }
    
    // MARK: - Update
    
    /// Update preview position based on raycast result
    func update(with result: ARRaycastResult) {
        let position = simd_float3(
            result.worldTransform.columns.3.x,
            result.worldTransform.columns.3.y,
            result.worldTransform.columns.3.z
        )
        
        previewAnchor?.position = position
        previewAnchor?.isEnabled = true
        
        // Keep beam vertical
        if let beam = previewBeam {
            beam.transform.rotation = simd_quatf(angle: 0, axis: [1, 0, 0])
        }
    }
    
    /// Show or hide the preview
    func setVisible(_ visible: Bool) {
        previewAnchor?.isEnabled = visible
    }
    
    /// Flash the preview green briefly for feedback
    func flash() {
        guard let circle = previewCircle else { return }
        
        // Flash green
        let greenMaterial = SimpleMaterial(
            color: UIColor.green.withAlphaComponent(0.8),
            isMetallic: false
        )
        circle.model?.materials = [greenMaterial]
        
        // Return to red after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            let redMaterial = SimpleMaterial(
                color: UIColor.red.withAlphaComponent(0.6),
                isMetallic: false
            )
            self?.previewCircle?.model?.materials = [redMaterial]
        }
    }
}