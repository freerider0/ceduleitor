import SwiftUI

struct FloorPlanToolbar: View {
    @ObservedObject var viewModel: FloorPlanEditorViewModel
    let onAddCorner: () -> Void
    let onDeleteCorner: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onReset: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            // Edit Tools Group
            if viewModel.editMode == .edit {
                HStack(spacing: 12) {
                    // Add Corner
                    ToolbarButton(
                        icon: "plus.circle",
                        label: "Add",
                        action: onAddCorner
                    )
                    
                    // Delete Corner
                    ToolbarButton(
                        icon: "minus.circle",
                        label: "Delete",
                        action: onDeleteCorner
                    )
                    
                    Divider()
                        .frame(height: 30)
                    
                    // Undo
                    ToolbarButton(
                        icon: "arrow.uturn.backward",
                        label: "Undo",
                        action: onUndo
                    )
                    
                    // Redo
                    ToolbarButton(
                        icon: "arrow.uturn.forward",
                        label: "Redo",
                        action: onRedo
                    )
                }
            }
            
            Spacer()
            
            // View Controls
            HStack(spacing: 12) {
                // Snap to Grid Toggle
                Toggle(isOn: $viewModel.snapToGrid) {
                    Label("Snap", systemImage: "grid")
                        .labelStyle(IconOnlyLabelStyle())
                }
                .toggleStyle(ToolbarToggleStyle())
                
                Divider()
                    .frame(height: 30)
                
                // Reset View
                ToolbarButton(
                    icon: "arrow.up.left.and.arrow.down.right",
                    label: "Fit",
                    action: onReset
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        )
        .padding(.horizontal)
    }
}

// MARK: - Toolbar Button Component

struct ToolbarButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.caption2)
            }
            .frame(width: 50, height: 50)
            .foregroundColor(.blue)
        }
    }
}

// MARK: - Toolbar Toggle Style

struct ToolbarToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            VStack(spacing: 4) {
                configuration.label
                    .font(.system(size: 20))
                Text("Snap")
                    .font(.caption2)
            }
            .frame(width: 50, height: 50)
            .foregroundColor(configuration.isOn ? .blue : .gray)
        }
    }
}

// MARK: - Icon Only Label Style

struct IconOnlyLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.icon
    }
}