import SwiftUI

/// Compact animated switch that matches the panel's chip language: a capsule
/// track with a sliding thumb, hover feedback and a spring transition.
struct ChipSwitch: View {
    @Binding var isOn: Bool
    var isEnabled = true
    var label: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    private var trackFill: Color {
        if isOn {
            return .green.opacity(isHovering && isEnabled ? 1 : 0.9)
        }
        return .secondary.opacity(isHovering && isEnabled ? 0.28 : 0.20)
    }

    private var animation: Animation? {
        reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.78)
    }

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Capsule()
                .fill(trackFill)
                .frame(width: 44, height: 26)
                .overlay(alignment: .leading) {
                    Circle()
                        .fill(.white)
                        .frame(width: 20, height: 20)
                        .shadow(color: .black.opacity(0.22), radius: 1.5, y: 1)
                        .padding(3)
                        .offset(x: isOn ? 18 : 0)
                        .scaleEffect(isHovering && isEnabled ? 1.06 : 1)
                }
                .overlay(
                    Capsule()
                        .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                )
                .animation(animation, value: isOn)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isHovering)
                .contentShape(Capsule())
        }
        .buttonStyle(PressableChipButtonStyle(reduceMotion: reduceMotion))
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? L10n.s("common.on") : L10n.s("common.off"))
        .accessibilityAddTraits(.isButton)
    }
}
