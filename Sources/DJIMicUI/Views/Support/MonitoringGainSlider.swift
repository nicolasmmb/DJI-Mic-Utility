import SwiftUI

/// Monitoring gain control: a custom center-anchored slider with a compact dB
/// readout. Dragging snaps to whole decibels and commits once on release, so
/// the receiver is not flooded with commands.
struct MonitoringGainSlider: View {
    let current: Int
    var isEnabled = true
    var commit: (Int) -> Void

    private let range = -12...12

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var value: Double
    @State private var isDragging = false
    @State private var isHovering = false

    init(current: Int, isEnabled: Bool = true, commit: @escaping (Int) -> Void) {
        self.current = current
        self.isEnabled = isEnabled
        self.commit = commit
        _value = State(initialValue: Double(current))
    }

    private var animation: Animation? {
        guard !reduceMotion, !isDragging else { return nil }
        return .spring(response: 0.28, dampingFraction: 0.8)
    }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            slider
                .frame(maxWidth: .infinity)

            ValueChip(value: formatted(Int(value.rounded())), systemImage: "headphones", animatesDigits: true)
                .fixedSize()
                .frame(width: 78, alignment: .trailing)
        }
        .frame(width: 210, height: 24)
        .opacity(isEnabled ? 1 : 0.5)
        .onAppear { value = Double(current) }
        .onChange(of: current) { _, newValue in
            guard !isDragging else { return }
            withAnimation(animation) { value = Double(newValue) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.s("rx.monitoringGain"))
        .accessibilityValue(formatted(Int(value.rounded())))
        .accessibilityAdjustableAction(adjust)
    }

    private var slider: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let clamped = min(max(value, Double(range.lowerBound)), Double(range.upperBound))
            let ratio = (clamped - Double(range.lowerBound)) / Double(range.upperBound - range.lowerBound)
            let x = max(6, min(width * ratio, width - 6))
            let center = width / 2

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.secondary.opacity(0.14))
                    .frame(height: 4)

                Capsule()
                    .fill(.primary.opacity(0.55))
                    .frame(width: abs(x - center), height: 4)
                    .offset(x: min(x, center))
                    .animation(animation, value: value)

                Circle()
                    .fill(.secondary.opacity(0.35))
                    .frame(width: 2, height: 2)
                    .offset(x: center - 1)

                Circle()
                    .fill(.background)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().strokeBorder(.secondary.opacity(0.35), lineWidth: 1))
                    .shadow(color: .black.opacity(0.16), radius: 1.5, y: 1)
                    .scaleEffect(isDragging ? 1.18 : (isHovering ? 1.1 : 1))
                    .offset(x: x - 6)
                    .animation(animation, value: value)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isHovering)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isDragging)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(dragGesture(width: width))
            .onHover { hovering in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
        }
        .frame(height: 24)
        .allowsHitTesting(isEnabled)
    }

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                guard isEnabled, width > 0 else { return }
                isDragging = true
                let ratio = min(max(gesture.location.x / width, 0), 1)
                let span = Double(range.upperBound - range.lowerBound)
                let raw = Double(range.lowerBound) + ratio * span
                value = raw.rounded()
            }
            .onEnded { _ in
                guard isEnabled else { return }
                isDragging = false
                commit(Int(value.rounded()))
            }
    }

    private func formatted(_ value: Int) -> String {
        switch value {
        case 0: "0 dB"
        case let positive where positive > 0: "+\(positive) dB"
        default: "\(value) dB"
        }
    }

    private func adjust(_ direction: AccessibilityAdjustmentDirection) {
        guard isEnabled else { return }

        let newValue: Int
        switch direction {
        case .increment:
            newValue = min(Int(value.rounded()) + 1, range.upperBound)
        case .decrement:
            newValue = max(Int(value.rounded()) - 1, range.lowerBound)
        @unknown default:
            return
        }

        withAnimation(animation) { value = Double(newValue) }
        commit(newValue)
    }
}
