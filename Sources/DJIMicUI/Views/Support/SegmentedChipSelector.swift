import SwiftUI

/// Compact segmented control with a sliding selection pill. Replaces native
/// segmented pickers so the controls match the panel's chip language and
/// animate their selection.
struct SegmentedChipSelector<Value: Hashable>: View {
    @Binding var selection: Value
    let values: [Value]
    var isEnabled = true
    var width: CGFloat = 210
    let label: (Value) -> String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionNamespace
    @State private var hoveredValue: Value?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(values, id: \.self) { value in
                segment(value)
            }
        }
        .padding(2)
        .frame(width: width, height: 24)
        .background(.secondary.opacity(0.10), in: Capsule())
        .overlay(Capsule().strokeBorder(.secondary.opacity(0.18), lineWidth: 1))
        .animation(
            reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.82),
            value: selection
        )
        .opacity(isEnabled ? 1 : 0.5)
        .disabled(!isEnabled)
    }

    private func segment(_ value: Value) -> some View {
        let isSelected = selection == value
        let isHovered = hoveredValue == value

        return Button {
            selection = value
        } label: {
            Text(label(value))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(isSelected || isHovered ? Color.primary : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(.secondary.opacity(0.22))
                            .matchedGeometryEffect(id: "selection", in: selectionNamespace)
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
        .accessibilityLabel(label(value))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
