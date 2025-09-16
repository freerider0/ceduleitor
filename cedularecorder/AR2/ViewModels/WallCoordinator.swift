import Foundation
import ARKit
import RealityKit
import Combine

class AR2WallCoordinator: ObservableObject {
    @Published var trackingState: ARCamera.TrackingState = .notAvailable
    @Published var trackedWallCount: Int = 0
    @Published var currentRoomPolygon: AR2RoomPolygon?
    @Published var userPosition: SIMD2<Float> = .zero
    @Published var userRotation: Float = 0

    private let arService: AR2Service
    private let persistenceService: AR2PersistenceService
    private let analyticsService: AR2AnalyticsService
    private let geometryService: AR2GeometryService
    private let polygonVisualizationService = AR2PolygonVisualizationService()

    private let wallTrackingUseCase: AR2WallTrackingUseCase
    private let roomCreationUseCase: AR2RoomCreationUseCase
    private let wallInteractionUseCase: AR2WallInteractionUseCase

    private let storage = AR2WallStorage()
    private let wallTracker: AR2WallTracker
    private lazy var arDelegate: AR2Delegate = {
        AR2Delegate(tracker: wallTracker, coordinator: self, storage: storage)
    }()

    // Polygon visualization entities
    private var floorPolygonAnchor: AnchorEntity?
    private var ceilingPolygonAnchor: AnchorEntity?
    private weak var arView: ARView?

    init(arService: AR2Service = AR2Service(),
         persistenceService: AR2PersistenceService = AR2PersistenceService(),
         analyticsService: AR2AnalyticsService = AR2AnalyticsService(),
         geometryService: AR2GeometryService = AR2GeometryService()) {

        self.arService = arService
        self.persistenceService = persistenceService
        self.analyticsService = analyticsService
        self.geometryService = geometryService

        let wallTrackingUseCase = AR2WallTrackingUseCase(storage: storage)
        self.wallTrackingUseCase = wallTrackingUseCase
        self.roomCreationUseCase = AR2RoomCreationUseCase(storage: storage, geometryService: geometryService)
        self.wallInteractionUseCase = AR2WallInteractionUseCase(storage: storage, trackingUseCase: wallTrackingUseCase)

        self.wallTracker = AR2WallTracker(storage: storage, analyticsService: analyticsService)
    }

    func setupAR(arView: ARView) {
        self.arView = arView
        arService.configureSession(arView: arView, delegate: arDelegate)
        wallTracker.arView = arView
    }

    // MARK: - Public API

    func getTrackedWalls() -> [AR2Wall] {
        storage.getTracked()
    }

    func getWallSegmentsForMiniMap() -> [AR2WallSegment] {
        storage.getTracked().map { $0.get2DSegment() }
    }

    func getTrackingQuality() -> String {
        switch trackingState {
        case .normal:
            return "Good"
        case .limited(let reason):
            return "Limited: \(reason)"
        case .notAvailable:
            return "Not Available"
        }
    }

    func handleTap(at location: CGPoint, in arView: ARView) {
        // Always raycast from center of screen
        let screenCenter = CGPoint(x: arView.bounds.width / 2, y: arView.bounds.height / 2)
        guard let result = arService.raycast(from: screenCenter, in: arView) else { return }

        guard let planeAnchor = result.anchor as? ARPlaneAnchor else { return }
        let wallID = planeAnchor.identifier

        // Check if wall already tracked
        if storage.trackedWalls.contains(wallID) {
            // Untrack existing wall
            wallTracker.stopTracking(wallID)
            updatePublishedState()
        } else {
            // Create new wall from ARPlaneAnchor and track it
            wallTracker.addPlane(planeAnchor)
            wallTracker.startTracking(wallID, in: arView)
            updatePublishedState()
        }
    }

    func handleLongPress(at location: CGPoint, in arView: ARView) {
        // Always raycast from center of screen
        let screenCenter = CGPoint(x: arView.bounds.width / 2, y: arView.bounds.height / 2)
        guard let result = arService.raycast(from: screenCenter, in: arView) else { return }

        guard let planeAnchor = result.anchor as? ARPlaneAnchor else { return }
        let wallID = planeAnchor.identifier

        if storage.trackedWalls.contains(wallID) {
            if wallInteractionUseCase.canDeleteWall(wallID) {
                wallTracker.stopTracking(wallID)
                storage.remove(wallID)
                updatePublishedState()
            }
        }
    }

    func startNewRoom() {
        _ = roomCreationUseCase.createRoom(name: nil, wallIDs: Array(storage.trackedWalls))
        updatePublishedState()
    }

    func reset() {
        arService.resetSession()
        storage.walls.removeAll()
        storage.rooms.removeAll()
        storage.trackedWalls.removeAll()
        currentRoomPolygon = nil
        removePolygonVisualization()
        updatePublishedState()
    }

    // MARK: - Internal

    func updateTrackingState(_ state: ARCamera.TrackingState) {
        trackingState = state
    }

    private func executeWallAction(_ action: AR2WallAction, in arView: ARView) {
        switch action {
        case .track(let wallID):
            wallTracker.startTracking(wallID, in: arView)
            updatePublishedState()
        case .untrack(let wallID):
            wallTracker.stopTracking(wallID)
            updatePublishedState()
        case .showError(let reason):
            print("Error: \(reason)")
        case .none:
            break
        }
    }

    private func updatePublishedState() {
        trackedWallCount = storage.trackedWalls.count

        // Update polygon from tracked walls
        let segments = getWallSegmentsForMiniMap()
        if segments.count >= 2 {
            currentRoomPolygon = geometryService.completePolygon(from: segments)
            updatePolygonVisualization()
        } else {
            currentRoomPolygon = nil
            removePolygonVisualization()
        }
    }

    private func updatePolygonVisualization() {
        guard let arView = arView,
              let polygon = currentRoomPolygon else { return }

        // Remove old visualizations
        removePolygonVisualization()

        // Use extended segments if available (same as vertices), otherwise use original
        let segmentsToShow = polygon.debugInfo?.extendedSegments ?? getWallSegmentsForMiniMap()

        let vertices = polygon.vertices

        // Only visualize if we have segments
        guard !segmentsToShow.isEmpty else { return }

        // Find floor and ceiling planes
        let floorPlane = storage.getByClassification(.floor).first
        let ceilingPlane = storage.getByClassification(.ceiling).first

        // Create visualization on floor
        if let floor = floorPlane {
            let floorHeight = floor.transform.columns.3.y

            // Debug: print segment coordinates and wall positions
            print("DEBUG: Floor height: \(floorHeight)")
            print("DEBUG: Floor position: \(floor.transform.columns.3)")
            for (i, segment) in segmentsToShow.enumerated() {
                print("DEBUG: Segment \(i): start(\(segment.start.x), \(segment.start.y)) end(\(segment.end.x), \(segment.end.y))")
            }

            // Also print actual wall positions
            for wall in storage.getTracked() {
                let pos = wall.transform.columns.3
                print("DEBUG: Wall \(wall.id) position: (\(pos.x), \(pos.y), \(pos.z))")
            }

            let floorEntity = polygonVisualizationService.createPolygonVisualization(
                segments: segmentsToShow,
                vertices: vertices,
                isClosed: polygon.isClosed,
                at: floorHeight
            )

            let floorAnchor = AnchorEntity()
            floorAnchor.addChild(floorEntity)
            arView.scene.addAnchor(floorAnchor)
            floorPolygonAnchor = floorAnchor
        }

        // Create visualization on ceiling
        if let ceiling = ceilingPlane {
            let ceilingHeight = ceiling.transform.columns.3.y
            let ceilingEntity = polygonVisualizationService.createPolygonVisualization(
                segments: segmentsToShow,
                vertices: vertices,
                isClosed: polygon.isClosed,
                at: ceilingHeight
            )

            let ceilingAnchor = AnchorEntity()
            ceilingAnchor.addChild(ceilingEntity)
            arView.scene.addAnchor(ceilingAnchor)
            ceilingPolygonAnchor = ceilingAnchor
        }
    }

    private func removePolygonVisualization() {
        floorPolygonAnchor?.removeFromParent()
        floorPolygonAnchor = nil
        ceilingPolygonAnchor?.removeFromParent()
        ceilingPolygonAnchor = nil
    }
}