import SwiftUI

/// Shared color tokens for the custom shell.
struct AppTheme {
    let accent: Color
    let accentSoft: Color
    let glow: Color
    let consoleBackground: Color
    let consoleText: Color
    let lightBackgroundStops: [Color]
    let darkBackgroundStops: [Color]
}

/// Curated palettes that can be switched at runtime from Settings.
enum AppColorPalette: String, CaseIterable, Identifiable, Codable {
    case harbor
    case ember
    case spruce
    case graphite

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .harbor:
            return "Harbor"
        case .ember:
            return "Ember"
        case .spruce:
            return "Spruce"
        case .graphite:
            return "Graphite"
        }
    }

    var theme: AppTheme {
        switch self {
        case .harbor:
            return AppTheme(
                accent: Color(red: 0.11, green: 0.46, blue: 0.54),
                accentSoft: Color(red: 0.68, green: 0.82, blue: 0.78),
                glow: Color(red: 0.88, green: 0.66, blue: 0.39),
                consoleBackground: Color(red: 0.09, green: 0.13, blue: 0.16),
                consoleText: Color(red: 0.90, green: 0.94, blue: 0.97),
                lightBackgroundStops: [
                    Color(red: 0.96, green: 0.97, blue: 0.99),
                    Color(red: 0.91, green: 0.94, blue: 0.97),
                    Color(red: 0.89, green: 0.93, blue: 0.95)
                ],
                darkBackgroundStops: [
                    Color(red: 0.06, green: 0.08, blue: 0.11),
                    Color(red: 0.08, green: 0.11, blue: 0.14),
                    Color(red: 0.10, green: 0.14, blue: 0.18)
                ]
            )
        case .ember:
            return AppTheme(
                accent: Color(red: 0.73, green: 0.33, blue: 0.27),
                accentSoft: Color(red: 0.94, green: 0.78, blue: 0.67),
                glow: Color(red: 0.84, green: 0.54, blue: 0.22),
                consoleBackground: Color(red: 0.14, green: 0.11, blue: 0.11),
                consoleText: Color(red: 0.96, green: 0.92, blue: 0.90),
                lightBackgroundStops: [
                    Color(red: 0.99, green: 0.96, blue: 0.95),
                    Color(red: 0.96, green: 0.90, blue: 0.87),
                    Color(red: 0.94, green: 0.88, blue: 0.84)
                ],
                darkBackgroundStops: [
                    Color(red: 0.13, green: 0.09, blue: 0.09),
                    Color(red: 0.17, green: 0.11, blue: 0.10),
                    Color(red: 0.21, green: 0.14, blue: 0.11)
                ]
            )
        case .spruce:
            return AppTheme(
                accent: Color(red: 0.22, green: 0.43, blue: 0.31),
                accentSoft: Color(red: 0.76, green: 0.85, blue: 0.70),
                glow: Color(red: 0.73, green: 0.64, blue: 0.39),
                consoleBackground: Color(red: 0.09, green: 0.12, blue: 0.10),
                consoleText: Color(red: 0.92, green: 0.95, blue: 0.91),
                lightBackgroundStops: [
                    Color(red: 0.96, green: 0.98, blue: 0.95),
                    Color(red: 0.91, green: 0.95, blue: 0.90),
                    Color(red: 0.89, green: 0.92, blue: 0.86)
                ],
                darkBackgroundStops: [
                    Color(red: 0.05, green: 0.08, blue: 0.06),
                    Color(red: 0.08, green: 0.11, blue: 0.08),
                    Color(red: 0.10, green: 0.14, blue: 0.10)
                ]
            )
        case .graphite:
            return AppTheme(
                accent: Color(red: 0.35, green: 0.42, blue: 0.59),
                accentSoft: Color(red: 0.72, green: 0.77, blue: 0.88),
                glow: Color(red: 0.57, green: 0.62, blue: 0.76),
                consoleBackground: Color(red: 0.09, green: 0.10, blue: 0.13),
                consoleText: Color(red: 0.90, green: 0.92, blue: 0.96),
                lightBackgroundStops: [
                    Color(red: 0.95, green: 0.96, blue: 0.98),
                    Color(red: 0.91, green: 0.92, blue: 0.96),
                    Color(red: 0.87, green: 0.89, blue: 0.94)
                ],
                darkBackgroundStops: [
                    Color(red: 0.06, green: 0.07, blue: 0.10),
                    Color(red: 0.08, green: 0.09, blue: 0.13),
                    Color(red: 0.11, green: 0.12, blue: 0.17)
                ]
            )
        }
    }
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppColorPalette.harbor.theme
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark ? theme.darkBackgroundStops : theme.lightBackgroundStops,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Large blurred shapes keep the shell from reading like a flat dashboard.
            Circle()
                .fill(theme.accentSoft.opacity(colorScheme == .dark ? 0.14 : 0.20))
                .frame(width: 340, height: 340)
                .blur(radius: 24)
                .offset(x: -360, y: -250)

            Circle()
                .fill(theme.glow.opacity(colorScheme == .dark ? 0.12 : 0.18))
                .frame(width: 300, height: 300)
                .blur(radius: 20)
                .offset(x: 420, y: -180)

            Circle()
                .fill(theme.accent.opacity(colorScheme == .dark ? 0.10 : 0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 26)
                .offset(x: 380, y: 260)
        }
        .ignoresSafeArea()
    }
}

/// Reusable frosted panel surface used for every major section of the shell.
struct AppPanel<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let subtitle: String?
    let accessory: AnyView?
    private let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        accessory: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)

                if let accessory {
                    accessory
                }
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(.ultraThinMaterial, in: shape)
        .overlay {
            shape
                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.52), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.08), radius: 24, x: 0, y: 14)
    }
}

/// Compact status chip used across the header, sidebar, and conversation views.
struct InfoPill: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appTheme) private var theme

    let title: String
    let value: String
    var tint: Color?

    var body: some View {
        let resolvedTint = tint ?? theme.accent

        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(resolvedTint.opacity(colorScheme == .dark ? 0.20 : 0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(resolvedTint.opacity(colorScheme == .dark ? 0.28 : 0.20), lineWidth: 1)
        }
    }
}

/// Shared button styling for the shell's primary and secondary actions.
struct AppActionButtonStyle: ButtonStyle {
    @Environment(\.appTheme) private var theme
    let emphasized: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(background(isPressed: configuration.isPressed), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(border(isPressed: configuration.isPressed), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }

    private func background(isPressed: Bool) -> some ShapeStyle {
        if emphasized {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        theme.accent.opacity(isPressed ? 0.85 : 1),
                        theme.glow.opacity(isPressed ? 0.78 : 0.92)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }

        return AnyShapeStyle(Color.white.opacity(isPressed ? 0.28 : 0.18))
    }

    private func border(isPressed: Bool) -> Color {
        emphasized
            ? Color.white.opacity(isPressed ? 0.18 : 0.26)
            : Color.white.opacity(isPressed ? 0.16 : 0.32)
    }
}

/// Monospaced, high-contrast surface for build logs and source previews.
struct CodeSurface<Content: View>: View {
    @Environment(\.appTheme) private var theme
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.consoleBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
    }
}
