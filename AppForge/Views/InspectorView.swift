import SwiftUI

/// Right-column summary of the selected project and latest build/launch output.
struct InspectorView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        AppPanel(
            title: "Project Snapshot",
            subtitle: "Build status, selected project details, and the latest console output.",
            accessory: AnyView(revealButton)
        ) {
            VStack(alignment: .leading, spacing: 16) {
                if let project = viewModel.selectedProject {
                    HStack(spacing: 10) {
                        InfoPill(title: "Project", value: project.name, tint: theme.accent)
                        InfoPill(title: "Platform", value: project.platform.displayName, tint: theme.glow)
                        InfoPill(title: "Updated", value: project.updatedAt.formatted(date: .abbreviated, time: .shortened), tint: theme.accentSoft)
                    }

                    Text(project.summary)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    FlowLayout(items: project.features) { feature in
                        Text(feature)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(theme.accent.opacity(0.14), in: Capsule())
                    }
                } else {
                    ContentUnavailableView(
                        "No project selected",
                        systemImage: "shippingbox",
                        description: Text("Pick a generated app to inspect its summary and build output.")
                    )
                }

                CodeSurface {
                    ScrollView {
                        Text(viewModel.buildLog.isEmpty ? "No build output yet." : viewModel.buildLog)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(theme.consoleText)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxHeight: .infinity)
    }

    private var revealButton: some View {
        Group {
            if viewModel.selectedProject != nil {
                Button("Reveal in Finder") {
                    viewModel.revealSelectedProject()
                }
                .buttonStyle(AppActionButtonStyle(emphasized: false))
            }
        }
    }
}

/// Simple adaptive layout for rendering feature tags.
private struct FlowLayout<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let columns = [
                GridItem(.adaptive(minimum: 120), spacing: 10, alignment: .leading)
            ]

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(items, id: \.self) { item in
                    content(item)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
