import UIKit

// MARK: - Protocols
protocol CADGestureDelegate: AnyObject {
    func gestureHandler(_ handler: CADGestureHandler, didPanBy translation: CGPoint)
    func gestureHandler(_ handler: CADGestureHandler, didPinchWithScale scale: CGFloat)
    func gestureHandler(_ handler: CADGestureHandler, didTapAt point: CGPoint)
    func gestureHandler(_ handler: CADGestureHandler, didDoubleTapAt point: CGPoint)
}

// MARK: - CADGestureHandler
class CADGestureHandler: NSObject {
    
    // MARK: - Properties
    weak var delegate: CADGestureDelegate?
    private weak var canvasView: CADCanvasView?
    
    // Gesture state
    private var initialPinchScale: CGFloat = 1.0
    private var lastPanTranslation: CGPoint = .zero
    private var isPanning = false
    private var isPinching = false
    
    // Touch tracking for smooth interaction
    private var activeTouches: Set<UITouch> = []
    private var lastTouchLocation: CGPoint = .zero
    
    // MARK: - Initialization
    init(canvasView: CADCanvasView) {
        self.canvasView = canvasView
        super.init()
    }
    
    // MARK: - Pan Gesture
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view else { return }
        
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        
        switch gesture.state {
        case .began:
            isPanning = true
            lastPanTranslation = .zero
            
        case .changed:
            let delta = CGPoint(
                x: translation.x - lastPanTranslation.x,
                y: translation.y - lastPanTranslation.y
            )
            
            // Apply smoothing for better touch response
            let smoothedDelta = smoothDelta(delta, velocity: velocity)
            delegate?.gestureHandler(self, didPanBy: smoothedDelta)
            
            lastPanTranslation = translation
            
        case .ended, .cancelled:
            isPanning = false
            
            // Apply inertia
            applyInertia(with: velocity)
            
        default:
            break
        }
    }
    
    // MARK: - Pinch Gesture
    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            isPinching = true
            initialPinchScale = 1.0
            
        case .changed:
            let scale = gesture.scale / initialPinchScale
            delegate?.gestureHandler(self, didPinchWithScale: scale)
            initialPinchScale = gesture.scale
            
        case .ended, .cancelled:
            isPinching = false
            
        default:
            break
        }
    }
    
    // MARK: - Tap Gestures
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: gesture.view)
        delegate?.gestureHandler(self, didTapAt: location)
    }
    
    @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: gesture.view)
        delegate?.gestureHandler(self, didDoubleTapAt: location)
    }
    
    // MARK: - Helper Methods
    private func smoothDelta(_ delta: CGPoint, velocity: CGPoint) -> CGPoint {
        // Apply smoothing based on velocity
        let smoothingFactor: CGFloat = 1.0
        let velocityFactor = min(1.0, hypot(velocity.x, velocity.y) / 1000.0)
        let smooth = 1.0 - (velocityFactor * smoothingFactor * 0.5)
        
        return CGPoint(
            x: delta.x * smooth,
            y: delta.y * smooth
        )
    }
    
    private func applyInertia(with velocity: CGPoint) {
        guard hypot(velocity.x, velocity.y) > 100 else { return }
        
        let decelerationRate: CGFloat = 0.95
        var currentVelocity = velocity
        let timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] timer in
            currentVelocity.x *= decelerationRate
            currentVelocity.y *= decelerationRate
            
            if hypot(currentVelocity.x, currentVelocity.y) < 10 {
                timer.invalidate()
                return
            }
            
            let delta = CGPoint(
                x: currentVelocity.x * 0.016,
                y: currentVelocity.y * 0.016
            )
            
            self?.delegate?.gestureHandler(self!, didPanBy: delta)
        }
        
        RunLoop.current.add(timer, forMode: .common)
    }
}

// MARK: - UIGestureRecognizerDelegate
extension CADGestureHandler: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow pan and pinch to work together
        if gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPinchGestureRecognizer {
            return true
        }
        if gestureRecognizer is UIPinchGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer {
            return true
        }
        return false
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Prevent pan gesture from starting during pinch
        if gestureRecognizer is UIPanGestureRecognizer && isPinching {
            return false
        }
        return true
    }
}