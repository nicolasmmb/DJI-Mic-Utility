import SwiftUI

/// Liquid Glass helpers with a material fallback for older macOS versions.
/// The app still deploys to macOS 14, but on macOS 26+ every surface uses the
/// system glass material.
extension View {
    @ViewBuilder
    func glassPanel(
        cornerRadius: CGFloat = 24,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        self
            .background(.regularMaterial, in: shape)
            .background(.primary.opacity(0.06), in: shape)
            .overlay(shape.strokeBorder(.primary.opacity(0.10), lineWidth: 0.9))
            .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
    }

    @ViewBuilder
    func glassCircle(
        size: CGFloat,
        tint: Color? = nil,
        interactive: Bool = true
    ) -> some View {
        self
            .frame(width: size, height: size)
            .background {
                if #available(macOS 26.0, *) {
                    Circle()
                        .fill(.clear)
                        .glassEffect(
                            .regular.tint(tint).interactive(interactive),
                            in: .circle
                        )
                } else {
                    Circle().fill(.regularMaterial)
                }
            }
            .background(.primary.opacity(0.07), in: Circle())
            .overlay(Circle().strokeBorder(.primary.opacity(0.14), lineWidth: 0.9))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
    }

    @ViewBuilder
    func glassCapsule(tint: Color? = nil, interactive: Bool = true) -> some View {
        self
            .background {
                if #available(macOS 26.0, *) {
                    Capsule()
                        .fill(.clear)
                        .glassEffect(
                            .regular.tint(tint).interactive(interactive),
                            in: .capsule
                        )
                } else {
                    Capsule().fill(.regularMaterial)
                }
            }
            .background(.primary.opacity(0.07), in: Capsule())
            .overlay(Capsule().strokeBorder(.primary.opacity(0.14), lineWidth: 0.9))
            .shadow(color: .black.opacity(0.07), radius: 6, y: 3)
    }
}

/// Living backdrop so the glass has something to refract. Movement is disabled
/// with Reduce Motion.
struct PremiumBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    private var base: Color {
        colorScheme == .dark
            ? Color(red: 0.045, green: 0.055, blue: 0.075)
            : Color(red: 0.93, green: 0.945, blue: 0.965)
    }

    private var greenGlow: Color {
        colorScheme == .dark
            ? Color(red: 0.15, green: 0.85, blue: 0.55).opacity(0.08)
            : Color(red: 0.25, green: 0.78, blue: 0.50).opacity(0.05)
    }

    private var blueGlow: Color {
        colorScheme == .dark
            ? Color(red: 0.30, green: 0.55, blue: 1.00).opacity(0.06)
            : Color(red: 0.35, green: 0.55, blue: 0.95).opacity(0.04)
    }

    private var warmGlow: Color {
        colorScheme == .dark
            ? Color(red: 1.00, green: 0.55, blue: 0.25).opacity(0.04)
            : Color(red: 1.00, green: 0.62, blue: 0.35).opacity(0.03)
    }

    var body: some View {
        ZStack {
            base

            Circle()
                .fill(greenGlow)
                .frame(width: 230, height: 230)
                .blur(radius: 90)
                .offset(x: -120, y: -190)

            Circle()
                .fill(blueGlow)
                .frame(width: 270, height: 270)
                .blur(radius: 100)
                .offset(x: 140, y: 30)

            Circle()
                .fill(warmGlow)
                .frame(width: 200, height: 200)
                .blur(radius: 90)
                .offset(x: -40, y: 230)
        }
        .ignoresSafeArea()
    }
}
