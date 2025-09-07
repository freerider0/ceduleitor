import UIKit
import Combine
import simd

class FloorPlanViewController: UIViewController {
    
    // MARK: - Properties
    private var canvasView: CADCanvasView!
    private var viewModel: FloorPlanViewModel!
    private var coordinator: FloorPlanCoordinator!
    private var cancellables = Set<AnyCancellable>()
    
    // UI Elements
    private var plusButton: UIBarButtonItem?
    private var modeLabel: UILabel!
    private var solverInfoLabel: UILabel!
    private var constraintPanel: UIView!
    private var constraintTextField: UITextField!
    private var constraintTypeSegment: UISegmentedControl!
    private var selectedEdgeIndex: Int = -1
    private var constraintPanelBottomConstraint: NSLayoutConstraint!
    
    // Gesture State
    private var lastPanTranslation: CGPoint = .zero
    private var lastPinchScale: CGFloat = 1.0
    private var pinchCenter: CGPoint = .zero
    private var lastRotationAngle: CGFloat = 0
    private var lastTapTime: TimeInterval = 0
    
    // Vertex dragging state
    private var isDraggingVertex = false
    private var draggedVertexIndex: Int = -1
    private var draggedRoom: CADRoom?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewModel()
        setupViews()  // Move this before coordinator to ensure views are initialized
        setupCoordinator()
        setupGestures()
        setupBindings()
        setupNavigationBar()
        setupKeyboardObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        canvasView.frame = view.bounds
    }
    
    // MARK: - Setup
    
    private func setupViewModel() {
        viewModel = FloorPlanViewModel()
    }
    
    private func setupCoordinator() {
        coordinator = FloorPlanCoordinator()
        coordinator.viewController = self
        
        coordinator.onModeChange = { [weak self] mode in
            self?.viewModel.currentMode = mode
            self?.updateUIForMode(mode)
        }
    }
    
    private func setupViews() {
        view.backgroundColor = .systemBackground
        
        // Canvas
        canvasView = CADCanvasView(frame: view.bounds)
        canvasView.dataSource = self
        canvasView.delegate = self
        view.addSubview(canvasView)
        
        // Mode label
        modeLabel = UILabel()
        modeLabel.font = .systemFont(ofSize: 12, weight: .medium)
        modeLabel.textColor = .secondaryLabel
        modeLabel.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        modeLabel.layer.cornerRadius = 8
        modeLabel.layer.masksToBounds = true
        modeLabel.textAlignment = .center
        modeLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(modeLabel)
        
        NSLayoutConstraint.activate([
            modeLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            modeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            modeLabel.heightAnchor.constraint(equalToConstant: 30),
            modeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100)
        ])
        
        // Solver info label
        solverInfoLabel = UILabel()
        solverInfoLabel.font = .systemFont(ofSize: 10, weight: .regular)
        solverInfoLabel.textColor = .tertiaryLabel
        solverInfoLabel.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        solverInfoLabel.layer.cornerRadius = 6
        solverInfoLabel.layer.masksToBounds = true
        solverInfoLabel.textAlignment = .center
        solverInfoLabel.numberOfLines = 0
        solverInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(solverInfoLabel)
        
        // Update solver info label
        updateSolverInfo()
        
        NSLayoutConstraint.activate([
            solverInfoLabel.topAnchor.constraint(equalTo: modeLabel.bottomAnchor, constant: 5),
            solverInfoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            solverInfoLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            solverInfoLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
        
        // Setup constraint panel (initially hidden)
        setupConstraintPanel()
    }
    
    private func setupConstraintPanel() {
        // Create constraint panel
        constraintPanel = UIView()
        constraintPanel.backgroundColor = UIColor.secondarySystemBackground
        constraintPanel.layer.cornerRadius = 12
        constraintPanel.layer.borderWidth = 1
        constraintPanel.layer.borderColor = UIColor.separator.cgColor
        constraintPanel.layer.shadowColor = UIColor.black.cgColor
        constraintPanel.layer.shadowOpacity = 0.3
        constraintPanel.layer.shadowOffset = CGSize(width: 0, height: 4)
        constraintPanel.layer.shadowRadius = 12
        constraintPanel.translatesAutoresizingMaskIntoConstraints = false
        constraintPanel.isHidden = true
        view.addSubview(constraintPanel)
        
        // Create title label
        let titleLabel = UILabel()
        titleLabel.text = "Set Edge Constraint"
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        constraintPanel.addSubview(titleLabel)
        
        // Create segmented control for constraint type
        constraintTypeSegment = UISegmentedControl(items: ["Length", "Horiz", "Vert"])
        constraintTypeSegment.selectedSegmentIndex = 0
        constraintTypeSegment.translatesAutoresizingMaskIntoConstraints = false
        constraintTypeSegment.addTarget(self, action: #selector(constraintTypeChanged), for: .valueChanged)
        constraintPanel.addSubview(constraintTypeSegment)
        
        // Create text field
        constraintTextField = UITextField()
        constraintTextField.placeholder = "Length (cm)"
        constraintTextField.keyboardType = .decimalPad
        constraintTextField.borderStyle = .roundedRect
        constraintTextField.font = .systemFont(ofSize: 18)
        constraintTextField.textAlignment = .center
        constraintTextField.translatesAutoresizingMaskIntoConstraints = false
        
        // Add toolbar to text field
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(applyConstraint))
        toolbar.items = [flexSpace, doneButton]
        constraintTextField.inputAccessoryView = toolbar
        
        constraintPanel.addSubview(constraintTextField)
        
        // Create apply button
        let applyButton = UIButton(type: .system)
        applyButton.setTitle("Apply", for: .normal)
        applyButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        applyButton.backgroundColor = .systemBlue
        applyButton.setTitleColor(.white, for: .normal)
        applyButton.layer.cornerRadius = 8
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        applyButton.addTarget(self, action: #selector(applyConstraint), for: .touchUpInside)
        constraintPanel.addSubview(applyButton)
        
        // Create cancel button
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelConstraint), for: .touchUpInside)
        constraintPanel.addSubview(cancelButton)
        
        // Create bottom constraint separately so we can animate it
        constraintPanelBottomConstraint = constraintPanel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        
        // Layout
        NSLayoutConstraint.activate([
            // Panel
            constraintPanel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            constraintPanelBottomConstraint,
            constraintPanel.widthAnchor.constraint(equalToConstant: 280),
            constraintPanel.heightAnchor.constraint(equalToConstant: 200),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: constraintPanel.topAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: constraintPanel.centerXAnchor),
            
            // Segmented control
            constraintTypeSegment.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            constraintTypeSegment.leadingAnchor.constraint(equalTo: constraintPanel.leadingAnchor, constant: 20),
            constraintTypeSegment.trailingAnchor.constraint(equalTo: constraintPanel.trailingAnchor, constant: -20),
            
            // Text field
            constraintTextField.topAnchor.constraint(equalTo: constraintTypeSegment.bottomAnchor, constant: 12),
            constraintTextField.leadingAnchor.constraint(equalTo: constraintPanel.leadingAnchor, constant: 20),
            constraintTextField.trailingAnchor.constraint(equalTo: constraintPanel.trailingAnchor, constant: -20),
            constraintTextField.heightAnchor.constraint(equalToConstant: 40),
            
            // Buttons
            cancelButton.bottomAnchor.constraint(equalTo: constraintPanel.bottomAnchor, constant: -16),
            cancelButton.leadingAnchor.constraint(equalTo: constraintPanel.leadingAnchor, constant: 20),
            cancelButton.widthAnchor.constraint(equalToConstant: 80),
            cancelButton.heightAnchor.constraint(equalToConstant: 36),
            
            applyButton.bottomAnchor.constraint(equalTo: constraintPanel.bottomAnchor, constant: -16),
            applyButton.trailingAnchor.constraint(equalTo: constraintPanel.trailingAnchor, constant: -20),
            applyButton.widthAnchor.constraint(equalToConstant: 80),
            applyButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }
    
    private func setupNavigationBar() {
        // Only setup navigation bar if we have a navigation controller
        guard navigationController != nil else {
            // Create a floating button instead when there's no navigation controller
            setupFloatingButton()
            return
        }
        
        // Plus button
        plusButton = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: self,
            action: #selector(plusButtonTapped)
        )
        navigationItem.rightBarButtonItem = plusButton!
    }
    
    private func setupFloatingButton() {
        // Create a floating button as an alternative to navigation bar button
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        button.tintColor = .systemBlue
        button.backgroundColor = .systemBackground
        button.layer.cornerRadius = 25
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.2
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(plusButtonTapped), for: .touchUpInside)
        
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 50),
            button.heightAnchor.constraint(equalToConstant: 50),
            button.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20)
        ])
        
        // Store reference for later use (create a dummy bar button item)
        plusButton = UIBarButtonItem()
        plusButton?.customView = button
    }
    
    private func setupGestures() {
        // Pan gesture
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.delegate = self
        canvasView.addGestureRecognizer(panGesture)
        
        // Pinch gesture
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinchGesture.delegate = self
        canvasView.addGestureRecognizer(pinchGesture)
        
        // Rotation gesture
        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        rotationGesture.delegate = self
        canvasView.addGestureRecognizer(rotationGesture)
        
        // Tap gesture - optimize for speed
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGesture.delegate = self
        tapGesture.cancelsTouchesInView = false // Allow touches to pass through
        tapGesture.delaysTouchesBegan = false // No delay
        tapGesture.delaysTouchesEnded = false // No delay
        canvasView.addGestureRecognizer(tapGesture)
        
        // Double tap gesture
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        doubleTapGesture.delegate = self
        canvasView.addGestureRecognizer(doubleTapGesture)
        
        // Long press gesture for deleting vertices
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        longPressGesture.delegate = self
        canvasView.addGestureRecognizer(longPressGesture)
        
        // Remove the requirement that causes delay
        // tapGesture.require(toFail: doubleTapGesture) // This causes delay!
    }
    
    private func setupBindings() {
        // Observe mode changes
        viewModel.$currentMode
            .sink { [weak self] mode in
                self?.updateUIForMode(mode)
            }
            .store(in: &cancellables)
        
        // Observe drawing corners
        viewModel.$drawingCorners
            .sink { [weak self] _ in
                self?.canvasView?.setNeedsDisplay()
            }
            .store(in: &cancellables)
        
        // Observe room changes
        viewModel.$floorPlan
            .sink { [weak self] _ in
                self?.canvasView?.setNeedsDisplay()
            }
            .store(in: &cancellables)
        
        // Observe selected room
        viewModel.$selectedRoom
            .sink { [weak self] _ in
                self?.canvasView?.setNeedsDisplay()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - UI Updates
    
    private func updateUIForMode(_ mode: CADMode) {
        modeLabel.text = "  \(mode.description)  "
        
        // Update button image - check if plusButton exists and whether it's a floating button or bar button
        guard let plusButton = plusButton else { return }
        
        if let button = plusButton.customView as? UIButton {
            // Floating button case
            switch mode {
            case .viewing:
                button.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
                button.tintColor = .systemBlue
                modeLabel.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
                modeLabel.textColor = .secondaryLabel
                
            case .drawingRoom:
                button.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .normal)
                button.tintColor = .systemGreen
                modeLabel.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.9)
                modeLabel.textColor = .white
                
            case .editingRoom:
                // Show Done/Check button to exit edit mode
                button.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .normal)
                button.tintColor = .systemGreen
                modeLabel.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.9)
                modeLabel.textColor = .white
                
            case .attachingMedia:
                button.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
                button.tintColor = .systemRed
                modeLabel.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.9)
                modeLabel.textColor = .white
            }
        } else if navigationController != nil {
            // Navigation bar button case
            switch mode {
            case .viewing:
                plusButton.image = UIImage(systemName: "plus")
                modeLabel.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
                modeLabel.textColor = .secondaryLabel
                
            case .drawingRoom:
                plusButton.image = UIImage(systemName: "checkmark")
                modeLabel.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.9)
                modeLabel.textColor = .white
                
            case .editingRoom:
                // Show Done/Check button to exit edit mode
                plusButton.image = UIImage(systemName: "checkmark.circle")
                modeLabel.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.9)
                modeLabel.textColor = .white
                
            case .attachingMedia:
                plusButton.image = UIImage(systemName: "xmark")
                modeLabel.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.9)
                modeLabel.textColor = .white
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func plusButtonTapped() {
        guard let plusButton = plusButton else { return }
        
        switch viewModel.currentMode {
        case .viewing:
            // Show main menu
            coordinator.showMainMenu(from: plusButton)
            
        case .drawingRoom:
            // Show finish/media menu
            if viewModel.canCloseDrawing {
                viewModel.finishDrawingRoom()
            } else if let lastRoom = viewModel.currentRooms.last {
                coordinator.showMediaMenu(from: plusButton, for: lastRoom)
            }
            
        case .editingRoom:
            // Exit edit mode and return to viewing
            viewModel.selectRoom(nil)
            viewModel.currentMode = .viewing
            
        case .attachingMedia:
            // Cancel media attachment
            coordinator.exitEditMode()
        }
    }
    
    // MARK: - Gesture Handlers
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: canvasView)
        let worldPoint = canvasView.screenToWorld(location)
        let translation = gesture.translation(in: canvasView)
        
        switch gesture.state {
        case .began:
            lastPanTranslation = .zero
            
            // Check if we're starting to drag a vertex in edit mode
            if case .editingRoom(let room) = viewModel.currentMode {
                // Check if we're near a vertex
                if let vertexIndex = findNearestVertex(in: room, at: worldPoint) {
                    // Start dragging this vertex
                    isDraggingVertex = true
                    draggedVertexIndex = vertexIndex
                    draggedRoom = room
                } else {
                    isDraggingVertex = false
                    draggedVertexIndex = -1
                    draggedRoom = nil
                }
            }
            
        case .changed:
            let deltaX = translation.x - lastPanTranslation.x
            let deltaY = translation.y - lastPanTranslation.y
            let delta = CGPoint(x: deltaX, y: deltaY)
            
            switch viewModel.currentMode {
            case .viewing:
                // Pan the canvas
                canvasView.panBy(delta)
                
            case .editingRoom:
                if isDraggingVertex, let room = draggedRoom, draggedVertexIndex >= 0 {
                    // Move the selected vertex - update position directly
                    viewModel.moveVertex(at: draggedVertexIndex, in: room, to: worldPoint)
                    canvasView.setNeedsDisplay()
                } else if !isDraggingVertex {
                    // Only pan if we explicitly determined we're not dragging a vertex
                    // This prevents accidental panning when starting near a vertex
                    canvasView.panBy(delta)
                }
                
            default:
                // Pan canvas in other modes
                canvasView.panBy(delta)
            }
            
            lastPanTranslation = translation
            
        case .ended, .cancelled:
            lastPanTranslation = .zero
            isDraggingVertex = false
            draggedVertexIndex = -1
            draggedRoom = nil
            
        default:
            break
        }
    }
    
    // Helper function to find the nearest vertex
    private func findNearestVertex(in room: CADRoom, at worldPoint: CGPoint) -> Int? {
        // Increased touch threshold for easier vertex selection
        let threshold: CGFloat = 40 // Increased from 20 to 40 pixels
        var closestIndex: Int?
        var closestDistance = CGFloat.greatestFiniteMagnitude
        
        for (index, corner) in room.transformedCorners.enumerated() {
            let screenCorner = canvasView.worldToScreen(corner)
            let screenPoint = canvasView.worldToScreen(worldPoint)
            let distance = hypot(screenPoint.x - screenCorner.x, screenPoint.y - screenCorner.y)
            
            if distance < threshold && distance < closestDistance {
                closestDistance = distance
                closestIndex = index
            }
        }
        
        return closestIndex
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            lastPinchScale = 1.0
            pinchCenter = gesture.location(in: canvasView)
            
        case .changed:
            let scale = gesture.scale / lastPinchScale
            canvasView.zoomBy(scale, at: pinchCenter)
            lastPinchScale = gesture.scale
            
        case .ended, .cancelled:
            lastPinchScale = 1.0
            
        default:
            break
        }
    }
    
    @objc private func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        guard case .editingRoom = viewModel.currentMode else { return }
        
        switch gesture.state {
        case .began:
            lastRotationAngle = 0
            
        case .changed:
            let deltaAngle = gesture.rotation - lastRotationAngle
            viewModel.rotateSelectedRoom(by: deltaAngle)
            lastRotationAngle = gesture.rotation
            canvasView.setNeedsDisplay()
            
        case .ended, .cancelled:
            lastRotationAngle = 0
            
        default:
            break
        }
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        
        let location = gesture.location(in: canvasView)
        let worldPoint = canvasView.screenToWorld(location)
        
        switch viewModel.currentMode {
        case .viewing:
            // In viewing mode, we might want to wait for double tap
            // but for now, make it immediate
            if let room = viewModel.roomAt(point: worldPoint) {
                viewModel.selectRoom(room)
            } else {
                viewModel.selectRoom(nil)
            }
            
        case .drawingRoom:
            // Add corner immediately for drawing mode
            viewModel.addDrawingCorner(worldPoint)
            
        case .editingRoom(let room):
            // Add new vertex immediately - no delay!
            viewModel.addVertexToRoom(room, at: worldPoint)
            canvasView.setNeedsDisplay()
            
        case .attachingMedia:
            // Place media pin at location
            // TODO: Implement media placement
            break
        }
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        lastTapTime = 0 // Reset to indicate double tap occurred
        canvasView.resetTransform()
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        
        let location = gesture.location(in: canvasView)
        let worldPoint = canvasView.screenToWorld(location)
        
        switch viewModel.currentMode {
        case .editingRoom(let room):
            // Check if long press is on an edge
            if let edgeIndex = findEdgeAt(point: worldPoint, in: room) {
                print("Long press detected on edge \(edgeIndex)")
                // Show constraint panel for this edge
                showConstraintPanel(for: room, edgeIndex: edgeIndex)
            } else {
                print("Long press not on edge, checking for vertex deletion")
                // Delete vertex at long press location
                viewModel.deleteVertexFromRoom(room, at: worldPoint)
                canvasView.setNeedsDisplay()
            }
            
        default:
            print("Long press in mode: \(viewModel.currentMode)")
            break
        }
    }
    
    // MARK: - Keyboard Handling
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard constraintPanel.isHidden == false else { return }
        
        if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            let keyboardHeight = keyboardFrame.height
            let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
            
            // Move panel above keyboard
            constraintPanelBottomConstraint.constant = -keyboardHeight - 10
            
            UIView.animate(withDuration: animationDuration) {
                self.view.layoutIfNeeded()
            }
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        
        // Reset panel position
        constraintPanelBottomConstraint.constant = -20
        
        UIView.animate(withDuration: animationDuration) {
            self.view.layoutIfNeeded()
        }
    }
    
    // MARK: - Constraint Panel Methods
    
    private func showConstraintPanel(for room: CADRoom, edgeIndex: Int) {
        print("Showing constraint panel for edge \(edgeIndex)")
        selectedEdgeIndex = edgeIndex
        
        // Get current edge length
        if let currentLength = viewModel.getEdgeLength(for: room, edgeIndex: edgeIndex) {
            constraintTextField.text = String(format: "%.1f", currentLength)
            print("Current edge length: \(currentLength)")
        }
        
        // Check if there's an existing constraint
        if let constraint = viewModel.getConstraint(for: room, edgeIndex: edgeIndex),
           constraint.type == .length,
           let targetValue = constraint.targetValue {
            constraintTextField.text = String(format: "%.1f", targetValue)
            print("Existing constraint length: \(targetValue)")
        }
        
        // Bring panel to front
        view.bringSubviewToFront(constraintPanel)
        
        // Show panel with animation
        print("Panel frame: \(constraintPanel.frame)")
        constraintPanel.alpha = 0
        constraintPanel.isHidden = false
        
        // Show keyboard first (this will trigger position adjustment)
        constraintTextField.becomeFirstResponder()
        
        // Then fade in the panel
        UIView.animate(withDuration: 0.3) {
            self.constraintPanel.alpha = 1
            print("Animating panel to visible")
        }
    }
    
    @objc private func constraintTypeChanged() {
        // Update text field visibility based on constraint type
        let needsValue = constraintTypeSegment.selectedSegmentIndex == 0 // Length
        constraintTextField.isHidden = !needsValue
        
        if needsValue {
            constraintTextField.placeholder = "Length (cm)"
        }
    }
    
    @objc private func applyConstraint() {
        guard case .editingRoom(let room) = viewModel.currentMode,
              selectedEdgeIndex >= 0 else {
            cancelConstraint()
            return
        }
        
        // Apply constraint based on selected type
        switch constraintTypeSegment.selectedSegmentIndex {
        case 0: // Length
            guard let text = constraintTextField.text,
                  let length = Double(text) else {
                cancelConstraint()
                return
            }
            viewModel.setLengthConstraint(for: room, edgeIndex: selectedEdgeIndex, length: CGFloat(length))
            
        case 1: // Horizontal
            viewModel.setHorizontalConstraint(for: room, edgeIndex: selectedEdgeIndex)
            
        case 2: // Vertical
            viewModel.setVerticalConstraint(for: room, edgeIndex: selectedEdgeIndex)
            
        default:
            break
        }
        
        // Update solver info to show it was used
        updateSolverInfo()
        
        // Force canvas redraw
        canvasView.setNeedsDisplay()
        print("📱 Canvas redraw triggered after constraint")
        
        // Hide panel
        hideConstraintPanel()
        
        // Refresh display
        canvasView.setNeedsDisplay()
    }
    
    @objc private func cancelConstraint() {
        hideConstraintPanel()
    }
    
    private func hideConstraintPanel() {
        constraintTextField.resignFirstResponder()
        UIView.animate(withDuration: 0.3, animations: {
            self.constraintPanel.alpha = 0
        }) { _ in
            self.constraintPanel.isHidden = true
            self.selectedEdgeIndex = -1
            self.constraintTextField.text = ""
        }
    }
    
    private func updateSolverInfo() {
        let adapter = PlaneGCSAdapter()
        let info = adapter.getSolverInfo()
        let algorithms = adapter.availableAlgorithms().joined(separator: ", ")
        solverInfoLabel.text = "\(info)\nAlgorithms: \(algorithms)"
    }
    
    private func findEdgeAt(point: CGPoint, in room: CADRoom) -> Int? {
        let threshold: CGFloat = 20
        var closestEdge = -1
        var closestDistance = CGFloat.greatestFiniteMagnitude
        
        let corners = room.transformedCorners
        
        for i in 0..<corners.count {
            let j = (i + 1) % corners.count
            let p1 = corners[i]
            let p2 = corners[j]
            
            // Calculate distance from point to line segment
            let distance = distanceFromPoint(point, toLineSegment: (p1, p2))
            
            if distance < closestDistance && distance < threshold {
                closestDistance = distance
                closestEdge = i
            }
        }
        
        return closestEdge >= 0 ? closestEdge : nil
    }
    
    private func distanceFromPoint(_ point: CGPoint, toLineSegment segment: (CGPoint, CGPoint)) -> CGFloat {
        let (p1, p2) = segment
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        
        if dx == 0 && dy == 0 {
            return hypot(point.x - p1.x, point.y - p1.y)
        }
        
        let t = max(0, min(1, ((point.x - p1.x) * dx + (point.y - p1.y) * dy) / (dx * dx + dy * dy)))
        let projection = CGPoint(x: p1.x + t * dx, y: p1.y + t * dy)
        
        return hypot(point.x - projection.x, point.y - projection.y)
    }
}

// MARK: - UIGestureRecognizerDelegate
extension FloorPlanViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, 
                          shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow pan and pinch together
        if gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPinchGestureRecognizer {
            return true
        }
        if gestureRecognizer is UIPinchGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer {
            return true
        }
        // Allow pinch and rotation together for room transform
        if gestureRecognizer is UIPinchGestureRecognizer && otherGestureRecognizer is UIRotationGestureRecognizer {
            return viewModel.currentMode.isEditMode
        }
        if gestureRecognizer is UIRotationGestureRecognizer && otherGestureRecognizer is UIPinchGestureRecognizer {
            return viewModel.currentMode.isEditMode
        }
        return false
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Always allow taps to begin immediately
        if gestureRecognizer is UITapGestureRecognizer {
            return true
        }
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Always receive touches for taps
        return true
    }
}

// MARK: - CADCanvasDataSource
extension FloorPlanViewController: CADCanvasDataSource {
    func roomGeometry(for canvas: CADCanvasView) -> RoomGeometry {
        // Convert floor plan to old RoomGeometry format for compatibility
        let geometry = RoomGeometry()
        // This will be updated when we refactor CADCanvasView
        return geometry
    }
    
    func isGridEnabled(for canvas: CADCanvasView) -> Bool {
        return viewModel.isGridEnabled
    }
    
    func rooms(for canvas: CADCanvasView) -> [CADRoom] {
        return viewModel.currentRooms
    }
    
    func selectedRoom(for canvas: CADCanvasView) -> CADRoom? {
        return viewModel.selectedRoom
    }
    
    func drawingCorners(for canvas: CADCanvasView) -> [CGPoint] {
        return viewModel.drawingCorners
    }
    
    func draggedVertexIndex(for canvas: CADCanvasView) -> Int? {
        return isDraggingVertex ? draggedVertexIndex : nil
    }
}

// MARK: - CADCanvasDelegate
extension FloorPlanViewController: CADCanvasDelegate {
    func canvasDidUpdateTransform(_ canvas: CADCanvasView) {
        // Handle transform updates if needed
    }
    
    func canvas(_ canvas: CADCanvasView, didSelectCornerAt index: Int) {
        // Handle corner selection if needed
    }
}