import SwiftUI

/// Compact segmented control with a sliding selection pill. Replaces the
/// native segmented picker so the control matches the panel's chip language
/// and animates its selection.
struct GainSelector: View {
    @Binding var selection: Int
    var isEnabled = true

    private let values = [-12, -6, 0, 6, 12]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionNamespace
    @State private var hoveredValue: Int?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(values, id: \.self) { value in
                segment(value)
            }
        }
        .padding(2)
        .frame(width: 210, height: 24)
        .background(.secondary.opacity(0.10), in: Capsule())
        .overlay(Capsule().strokeBorder(.secondary.opacity(0.18), lineWidth: 1))
        .animation(
            reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.82),
            value: selection
        )
        .opacity(isEnabled ? 1 : 0.5)
        .disabled(!isEnabled)
    }

    private func segment(_ value: Int) -> some View {
        let isSelected = selection == value
        let isHovered = hoveredValue == value

        return Button {
            selection = value
        } label: {
            Text(label(for: value))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(isSelected || isHovered ? Color.primary : Color.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(.secondary.opacity(0.22))
                            .matchedGeometryEffect(id: "gainSelection", in: selectionNamespace)
                    } else if isHovered && isEnabled {
                        Capsule()
                            .fill(.secondary.opacity(0.08))
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(PressableChipButtonStyle(reduceMotion: reduceMotion))
        .onHover { hovering in
            if hovering {
                hoveredValue = value
            } else if hoveredValue == value {
                hoveredValue = nil
            }
        }
        .accessibilityLabel(label(for: value))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func label(for value: Int) -> String {
        switch value {
        case 0: "0"
        case let positive where positive > 0: "+\(positive)"
        default: "\(value)"
        }
    }
}
