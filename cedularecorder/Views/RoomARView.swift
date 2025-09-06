import SwiftUI
import RealityKit
import ARKit
import Combine

// ================================================================================
// MARK: - Room AR View
// ================================================================================

/// Main AR view for room capture with real-time preview
struct RoomARView: UIViewRepresentable {
    @ObservedObject var detector: RoomShapeDetector
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Configure AR session for plane detection
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        arView.session.run(configuration)
        
        // Setup coordinator
        context.coordinator.arView = arView
        context.coordinator.setupGestures()
        context.coordinator.setupPreviewEntities()
        
        // Set session delegate for frame updates
        arView.session.delegate = context.coordinator
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.updateVisualization()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // ================================================================================
    // MARK: - Coordinator
    // ================================================================================
    
    class Coordinator: NSObject, ARSessionDelegate {
        let parent: RoomARView
        weak var arView: ARView?
        
        // Visualization entities
        var cornerMarkers: [AnchorEntity] = []
        var lineEntities: [Entity] = []
        
        // Preview entities
        var previewCircle: ModelEntity?
        var previewBeam: ModelEntity?
        var previewAnchor: AnchorEntity?
        
        // Wall mode preview ring
        var wallRingContainer: Entity?
        var wallRingAnchor: AnchorEntity?
        
        // Pre-created materials to avoid recreating every frame
        var greenMaterial: UnlitMaterial?
        var blueMaterial: UnlitMaterial?
        
        // Wall mode indicators
        var wallIndicator: AnchorEntity?
        
        private var cancellables = Set<AnyCancellable>()
        
        // MARK: - Initialization
        
        init(_ parent: RoomARView) {
            self.parent = parent
            super.init()
            
            // Subscribe to detector changes
            parent.detector.$corners
                .sink { [weak self] _ in
                    self?.updateVisualization()
                }
                .store(in: &cancellables)
        }
        
        deinit {
            // Cleanup if needed
        }
        
        // ================================================================================
        // MARK: - Setup Methods
        // ================================================================================
        
        /// Setup tap gesture for adding points
        func setupGestures() {
            guard let arView = arView else { return }
            
            let tapGesture = UITapGestureRecognizer(
                target: self,
                action: #selector(handleTap(_:))
            )
            arView.addGestureRecognizer(tapGesture)
        }
        
        /// Create preview entities (circle and vertical beam)
        @MainActor
        func setupPreviewEntities() {
            guard let arView = arView else { return }
            
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
            
            // Create wall ring for wall mode
            setupWallRing()
        }
        
        // ================================================================================
        // MARK: - ARSessionDelegate for Real-time Updates
        // ================================================================================
        
        /// Called every frame - use this for smooth updates
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            updatePreview()
        }
        
        /// Update preview position based on current raycast
        func updatePreview() {
            guard let arView = arView else { return }
            
            let centerPoint = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
            
            // Always try both horizontal and vertical raycasts to show ring
            let horizontalResults = arView.raycast(
                from: centerPoint,
                allowing: .existingPlaneGeometry,
                alignment: .horizontal
            )
            
            let verticalResults = arView.raycast(
                from: centerPoint,
                allowing: .existingPlaneGeometry,
                alignment: .vertical
            )
            
            // Update ring based on what surface we hit
            if let verticalResult = verticalResults.first {
                // Vertical surface - show green ring
                updateRingPosition(verticalResult, isVertical: true)
                
                if parent.detector.mode == .wallIntersection {
                    parent.detector.updateWallDetection(wallDetected: true)
                    updateWallIndicator(detected: true)
                }
            } else if let horizontalResult = horizontalResults.first {
                // Horizontal surface - show blue ring
                updateRingPosition(horizontalResult, isVertical: false)
                
                if parent.detector.mode == .cornerPointing {
                    updatePreviewPosition(horizontalResult)
                    parent.detector.updatePreview(from: horizontalResult)
                }
            } else {
                // No surface detected
                wallRingAnchor?.isEnabled = false
                previewAnchor?.isEnabled = false
                
                if parent.detector.mode == .wallIntersection {
                    parent.detector.updateWallDetection(wallDetected: false)
                    updateWallIndicator(detected: false)
                }
            }
            
            // Show/hide floor preview based on mode
            if parent.detector.mode == .cornerPointing && horizontalResults.first != nil {
                previewAnchor?.isEnabled = true
            } else {
                previewAnchor?.isEnabled = false
            }
        }
        
        /// Update preview circle and beam position
        private func updatePreviewPosition(_ result: ARRaycastResult) {
            let position = simd_float3(
                result.worldTransform.columns.3.x,
                result.worldTransform.columns.3.y,
                result.worldTransform.columns.3.z
            )
            
            // Move preview anchor to new position smoothly
            previewAnchor?.position = position
            previewAnchor?.isEnabled = true
            
            // Adjust beam height if needed
            if let beam = previewBeam {
                // Keep beam vertical
                beam.transform.rotation = simd_quatf(angle: 0, axis: [1, 0, 0])
            }
        }
        
        /// Update wall detection indicator
        private func updateWallIndicator(detected: Bool) {
            // Wall ring visibility is handled in updateWallRingPosition
        }
        
        /// Create a simple ring image for testing
        private func createSimpleRingImage() -> UIImage? {
            let size = CGSize(width: 512, height: 512)
            
            // Create opaque context (no transparency)
            UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
            guard let context = UIGraphicsGetCurrentContext() else { return nil }
            
            // Fill entire image with bright green
            context.setFillColor(UIColor.green.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            
            // Draw a red circle in center for testing
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius: CGFloat = size.width / 4
            
            context.setFillColor(UIColor.red.cgColor)
            context.fillEllipse(in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
            
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return image
        }
        
        /// Create a ring texture programmatically
        private func createRingTexture(color: UIColor) -> UIImage? {
            let size = CGSize(width: 512, height: 512)
            
            // Create context with NO alpha (opaque background)
            UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
            guard let context = UIGraphicsGetCurrentContext() else { return nil }
            
            // Fill with black background (will be transparent in shader)
            context.setFillColor(UIColor.black.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            
            // Set up ring parameters
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outerRadius: CGFloat = size.width / 2 * 0.9
            let innerRadius: CGFloat = size.width / 2 * 0.4
            let lineWidth = outerRadius - innerRadius
            
            // Draw the ring
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(lineWidth)
            
            let ringRadius = (outerRadius + innerRadius) / 2
            context.strokeEllipse(in: CGRect(
                x: center.x - ringRadius,
                y: center.y - ringRadius,
                width: ringRadius * 2,
                height: ringRadius * 2
            ))
            
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return image
        }
        
        /// Create a flat ring mesh using LowLevelMesh plane approach
        @MainActor
        private func createRingLowLevelMesh() -> LowLevelMesh? {
            let innerRadius: Float = 0.08
            let outerRadius: Float = 0.12
            let segments: Int = 64
            
            // Calculate vertex count: (segments + 1) * 2 for inner and outer circles
            let vertexCount = (segments + 1) * 2
            let trianglesPerSegment = 2
            let indexCount = segments * trianglesPerSegment * 3
            
            // Define vertex attributes - position and normal
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
            
            // Define vertex layout
            let vertexStride = MemoryLayout<simd_float3>.size * 2  // position + normal
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
                
                // Generate vertices for ring
                for i in 0...segments {
                    let angle = Float(i) * (2.0 * .pi) / Float(segments)
                    let cosA = cos(angle)
                    let sinA = sin(angle)
                    
                    // Outer circle vertex
                    vertexData[vertexIndex] = simd_float3(cosA * outerRadius, sinA * outerRadius, 0)  // position
                    vertexData[vertexIndex + 1] = simd_float3(0, 0, 1)  // normal pointing up
                    vertexIndex += 2
                    
                    // Inner circle vertex
                    vertexData[vertexIndex] = simd_float3(cosA * innerRadius, sinA * innerRadius, 0)  // position
                    vertexData[vertexIndex + 1] = simd_float3(0, 0, 1)  // normal pointing up
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
            
            return mesh
        }
        
        /// Setup simple ring for surface detection
        @MainActor
        private func setupWallRing() {
            guard let arView = arView else { return }
            
            // Create ring mesh using LowLevelMesh
            guard let lowLevelMesh = createRingLowLevelMesh(),
                  let ringMesh = try? MeshResource(from: lowLevelMesh) else {
                print("Failed to create ring mesh")
                return
            }
            
            // Create bright unlit materials to avoid shadows
            greenMaterial = UnlitMaterial(color: .green)
            blueMaterial = UnlitMaterial(color: .systemBlue)
            
            // Create the ring model
            let ring = ModelEntity(mesh: ringMesh, materials: [greenMaterial!])
            wallRingContainer = ring
            
            // Create anchor for ring
            if let ring = wallRingContainer {
                wallRingAnchor = AnchorEntity(world: .zero)
                wallRingAnchor?.addChild(ring)
            }
            
            // Initially hide wall ring
            wallRingAnchor?.isEnabled = false
            
            if let anchor = wallRingAnchor {
                arView.scene.addAnchor(anchor)
            }
        }
        
        /// Helper function to recursively update materials
        private func updateEntityMaterials(entity: Entity, material: RealityKit.Material) {
            if let modelEntity = entity as? ModelEntity {
                modelEntity.model?.materials = [material]
            }
            for child in entity.children {
                updateEntityMaterials(entity: child, material: material)
            }
        }
        
        /// Update ring position and color based on surface type
        private func updateRingPosition(_ result: ARRaycastResult, isVertical: Bool) {
            guard let ring = wallRingContainer as? ModelEntity else { return }
            
            // Get exact hit position from raycast
            let hitPosition = simd_float3(
                result.worldTransform.columns.3.x,
                result.worldTransform.columns.3.y,
                result.worldTransform.columns.3.z
            )
            
            // Set anchor to exact hit position
            wallRingAnchor?.position = hitPosition
            
            // Get surface normal
            let normal = simd_float3(
                result.worldTransform.columns.2.x,
                result.worldTransform.columns.2.y,
                result.worldTransform.columns.2.z
            )
            
            // The raycast transform has Z pointing OUT from the surface (the normal)
            // Our ring is in XY plane with Z as its normal
            // So using the transform directly makes the ring perpendicular!
            // We need to rotate it 90 degrees to lie flat
            
            wallRingAnchor?.transform = Transform(matrix: result.worldTransform)
            
            // Rotate -90 degrees around local X axis to flip the ring down onto the surface (showing front)
            let rotation = simd_quatf(angle: -.pi/2, axis: [1, 0, 0])
            wallRingAnchor?.orientation = wallRingAnchor!.orientation * rotation
            
            wallRingAnchor?.position = hitPosition
            
            // Very small offset to prevent z-fighting (1mm)
            wallRingAnchor?.position += normal * 0.001
            
            // Update material based on surface type
            ring.model?.materials = isVertical ? [greenMaterial!] : [blueMaterial!]
            
            // Show the ring
            wallRingAnchor?.isEnabled = true
        }
        
        // ================================================================================
        // MARK: - User Interaction
        // ================================================================================
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView = arView else { return }
            
            let centerPoint = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
            
            if parent.detector.mode == .cornerPointing {
                // Corner mode - add point at floor
                let results = arView.raycast(
                    from: centerPoint,
                    allowing: .existingPlaneGeometry,
                    alignment: .horizontal
                )
                
                if let result = results.first {
                    _ = parent.detector.addCornerPoint(from: result)
                    flashPreview()  // Visual feedback
                }
            } else {
                // Wall mode - capture wall
                let results = arView.raycast(
                    from: centerPoint,
                    allowing: .existingPlaneGeometry,
                    alignment: .vertical
                )
                
                if let result = results.first {
                    _ = parent.detector.captureWall(from: result)
                    flashPreview()  // Visual feedback
                }
            }
        }
        
        /// Flash preview green briefly for feedback
        private func flashPreview() {
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
        
        // ================================================================================
        // MARK: - Visualization Updates
        // ================================================================================
        
        /// Update corner markers and connecting lines
        func updateVisualization() {
            clearVisualization()
            
            guard let arView = arView else { return }
            
            // Add corner markers
            for (index, corner) in parent.detector.corners.enumerated() {
                addCornerMarker(at: corner, index: index, arView: arView)
            }
            
            // Add connecting lines
            if parent.detector.corners.count >= 2 {
                for i in 0..<parent.detector.corners.count - 1 {
                    guard i < parent.detector.corners.count,
                          i + 1 < parent.detector.corners.count else { continue }
                    
                    addLine(
                        from: parent.detector.corners[i],
                        to: parent.detector.corners[i + 1],
                        arView: arView
                    )
                }
                
                // Add closing line if shape is complete
                if parent.detector.isComplete,
                   parent.detector.corners.count >= 3,
                   let first = parent.detector.corners.first,
                   let last = parent.detector.corners.last {
                    addLine(from: last, to: first, arView: arView)
                }
            }
        }
        
        /// Clear all visualization entities
        func clearVisualization() {
            cornerMarkers.forEach { $0.removeFromParent() }
            cornerMarkers.removeAll()
            lineEntities.forEach { $0.removeFromParent() }
            lineEntities.removeAll()
        }
        
        /// Add a corner marker (flat circle with number)
        func addCornerMarker(at position: simd_float3, index: Int, arView: ARView) {
            // Create flat circle
            let radius: Float = 0.1
            let mesh = MeshResource.generatePlane(
                width: radius * 2,
                depth: radius * 2,
                cornerRadius: radius
            )
            
            // Color: green for first, blue for others
            let color = index == 0 ? 
                UIColor.green.withAlphaComponent(0.8) : 
                UIColor.blue.withAlphaComponent(0.8)
            let material = SimpleMaterial(color: color, isMetallic: false)
            let circle = ModelEntity(mesh: mesh, materials: [material])
            
            // Rotate to lay flat
            circle.transform.rotation = simd_quatf(angle: -.pi/2, axis: [1, 0, 0])
            
            // Add number label
            let textMesh = MeshResource.generateText(
                "\(index + 1)",
                extrusionDepth: 0.01,
                font: .systemFont(ofSize: 0.15),
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byClipping
            )
            let textMaterial = SimpleMaterial(color: .white, isMetallic: false)
            let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
            textEntity.position = [0, 0.02, 0]
            
            // Create anchor
            let anchor = AnchorEntity(world: position)
            anchor.addChild(circle)
            anchor.addChild(textEntity)
            
            arView.scene.addAnchor(anchor)
            cornerMarkers.append(anchor)
        }
        
        /// Add a line between two points
        func addLine(from start: simd_float3, to end: simd_float3, arView: ARView) {
            let distance = simd_distance(start, end)
            let midpoint = (start + end) / 2
            
            // Create cylinder as line
            let mesh = MeshResource.generateCylinder(height: distance, radius: 0.01)
            let material = SimpleMaterial(color: .yellow, isMetallic: false)
            let cylinder = ModelEntity(mesh: mesh, materials: [material])
            
            // Calculate rotation
            let direction = normalize(end - start)
            let up = simd_float3(0, 1, 0)
            
            
            if abs(dot(direction, up)) < 0.999 {
                let rotation = simd_quatf(from: up, to: direction)
                cylinder.transform.rotation = rotation
            }
            
            // Add distance label
            let distanceText = String(format: "%.2fm", distance)
            let textMesh = MeshResource.generateText(
                distanceText,
                extrusionDepth: 0.005,
                font: .systemFont(ofSize: 0.05),
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byClipping
            )
            let textMaterial = SimpleMaterial(color: .white, isMetallic: false)
            let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
            textEntity.position = [0, 0.1, 0]
            
            // Create anchor at midpoint
            let anchor = AnchorEntity(world: midpoint)
            anchor.addChild(cylinder)
            anchor.addChild(textEntity)
            
            arView.scene.addAnchor(anchor)
            cornerMarkers.append(anchor)
        }
    }
}

// ================================================================================
// MARK: - Helper Extensions
// ================================================================================

// Already defined in RealityKitARView.swift, commenting out to avoid duplication
// extension simd_float3 { ... }
// extension simd_quatf { ... }
