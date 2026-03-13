import SwiftUI

/// Left column showing capability context, project history, files, and support actions.
struct SidebarView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.openURL) private var openURL
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AppPanel(
                    title: "Studio",
                    subtitle: "Provider, target, and machine capability at a glance.",
                    accessory: AnyView(
                        Button("Configure") {
                            viewModel.isShowingSettings = true
                        }
                        .buttonStyle(AppActionButtonStyle(emphasized: false))
                    )
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            InfoPill(title: "Capability", value: viewModel.capability.badge, tint: theme.accent)
                            InfoPill(title: "Target", value: viewModel.selectedPlatform.displayName, tint: theme.glow)
                        }

                        HStack(spacing: 10) {
                            InfoPill(title: "Provider", value: viewModel.aiProviderStatus.providerLabel, tint: theme.accentSoft)
                            InfoPill(title: "Network", value: viewModel.aiProviderStatus.networkLabel, tint: theme.accent)
                        }

                        Text(viewModel.aiProviderStatus.detail)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)

                        Picker("Platform", selection: $viewModel.selectedPlatform) {
                            ForEach(AppPlatform.allCases) { platform in
                                Text(platform.displayName).tag(platform)
                            }
                        }
                        .pickerStyle(.menu)

                        Text(viewModel.xcodeCodingStatusSummary)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                AppPanel(title: "Projects", subtitle: projectsSubtitle) {
                    if viewModel.projects.isEmpty {
                        emptyProjectsState
                    } else {
                        VStack(spacing: 10) {
                            ForEach(viewModel.projects) { project in
                                ProjectTile(
                                    project: project,
                                    isSelected: viewModel.selectedProject?.id == project.id,
                                    onSelect: {
                                        viewModel.load(project: project)
                                    }
                                )
                            }
                        }
                    }
                }

                AppPanel(title: "Workspace Files", subtitle: filesSubtitle) {
                    if viewModel.selectedProject == nil {
                        ContentUnavailableView(
                            "No files loaded",
                            systemImage: "folder.badge.questionmark",
                            description: Text("Select a generated project to inspect its source tree.")
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(viewModel.fileTree) { node in
                                FileTreeRow(
                                    node: node,
                                    selectedFileURL: viewModel.selectedFileURL,
                                    depth: 0,
                                    onSelect: { url in
                                        viewModel.selectFile(url)
                                    }
                                )
                            }
                        }
                    }
                }

                AppPanel(title: "Support", subtitle: "Privacy, workspace ownership, and project support.") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Generated apps live in ~/AppForge, API keys stay in the macOS Keychain, and no third-party source code is vendored into this repository.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            Button("Reveal Workspace") {
                                viewModel.revealWorkspace()
                            }
                            .buttonStyle(AppActionButtonStyle(emphasized: false))

                            Button("Buy Me a Coffee") {
                                guard let url = URL(string: "https://buymeacoffee.com/einnovoeg") else { return }
                                openURL(url)
                            }
                            .buttonStyle(AppActionButtonStyle(emphasized: true))
                        }
                    }
                }
            }
            .padding(.bottom, 4)
        }
        .scrollIndicators(.hidden)
    }

    private var projectsSubtitle: String {
        viewModel.projects.isEmpty
            ? "Generated apps will appear in your portable AppForge workspace."
            : "Recent generated apps stored in ~/AppForge/Projects."
    }

    private var filesSubtitle: String {
        guard let selectedProject = viewModel.selectedProject else {
            return "Select a project to browse its contents."
        }

        return selectedProject.rootURL.lastPathComponent
    }

    private var emptyProjectsState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("No generated projects yet", systemImage: "tray")
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            Text("Start a new session, describe the app you want, and AppForge will create a portable project workspace here.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct ProjectTile: View {
    @Environment(\.appTheme) private var theme
    let project: GeneratedProject
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(project.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(project.updatedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                    Text(project.summary)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                HStack(spacing: 8) {
                    InfoPill(title: "Platform", value: project.platform.displayName, tint: theme.accent)
                    InfoPill(title: "Features", value: "\(project.features.count)", tint: theme.glow)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isSelected ? 1.4 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var background: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [theme.accent.opacity(0.24), theme.glow.opacity(0.16)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        return AnyShapeStyle(Color.white.opacity(0.10))
    }

    private var borderColor: Color {
        isSelected ? theme.accent.opacity(0.55) : Color.white.opacity(0.18)
    }
}

private struct FileTreeRow: View {
    @Environment(\.appTheme) private var theme
    let node: FileTreeNode
    let selectedFileURL: URL?
    let depth: Int
    let onSelect: (URL) -> Void

    var body: some View {
        if node.isDirectory {
            DisclosureGroup {
                if let children = node.children {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(children) { child in
                            FileTreeRow(
                                node: child,
                                selectedFileURL: selectedFileURL,
                                depth: depth + 1,
                                onSelect: onSelect
                            )
                        }
                    }
                    .padding(.top, 6)
                }
            } label: {
                Label(node.name, systemImage: "folder")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .padding(.leading, CGFloat(depth) * 12)
        } else {
            Button {
                onSelect(node.url)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: selectedFileURL == node.url ? "doc.fill" : "doc.text")
                        .foregroundStyle(selectedFileURL == node.url ? theme.glow : .secondary)

                    Text(node.name)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(rowBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.leading, CGFloat(depth) * 12)
        }
    }

    private var rowBackground: some ShapeStyle {
        selectedFileURL == node.url
            ? AnyShapeStyle(theme.accent.opacity(0.18))
            : AnyShapeStyle(Color.white.opacity(0.06))
    }
}
