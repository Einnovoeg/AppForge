import SwiftUI

/// Top-level shell that arranges the three main workspace columns and shared modals.
struct AppRootView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 20) {
                header

                HStack(alignment: .top, spacing: 20) {
                    SidebarView(viewModel: viewModel)
                        .frame(minWidth: 320, idealWidth: 320, maxWidth: 320, maxHeight: .infinity)

                    ConversationView(viewModel: viewModel)
                        .frame(minWidth: 540, maxWidth: .infinity, maxHeight: .infinity)

                    VStack(spacing: 20) {
                        InspectorView(viewModel: viewModel)
                            .frame(height: 340)

                        FilePreviewView(viewModel: viewModel)
                            .frame(maxHeight: .infinity)
                    }
                    .frame(minWidth: 430, idealWidth: 430, maxWidth: 430, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(24)
        }
        .task {
            await viewModel.bootstrapIfNeeded()
        }
        .sheet(isPresented: $viewModel.isShowingSettings) {
            SettingsView(viewModel: viewModel)
                .frame(width: 680, height: 560)
        }
        .alert("AppForge", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    viewModel.errorMessage = nil
                }
            }
        )
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 20) {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [theme.accent, theme.glow],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .frame(width: 58, height: 58)
                    .overlay {
                        Image(systemName: "hammer.circle.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white.opacity(0.92))
                    }

                VStack(alignment: .leading, spacing: 5) {
                    Text("AppForge")
                        .font(.system(size: 30, weight: .bold, design: .rounded))

                    Text("Portable Apple-platform app builder with pluggable AI backends")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text(AppReleaseInfo.current.releaseSummary)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 20)

            HStack(spacing: 10) {
                InfoPill(title: "Capability", value: viewModel.capability.badge, tint: theme.accent)
                    .frame(width: 132)
                InfoPill(title: "Provider", value: viewModel.aiProviderStatus.providerLabel, tint: theme.glow)
                    .frame(width: 132)
                InfoPill(title: "Build", value: viewModel.buildPhase.label, tint: theme.accentSoft)
                    .frame(width: 150)
                InfoPill(title: "Project", value: viewModel.selectedProjectName, tint: theme.accent)
                    .frame(width: 190)
            }

            HStack(spacing: 10) {
                Button("New Session") {
                    viewModel.createNewProjectSession()
                }
                .buttonStyle(AppActionButtonStyle(emphasized: false))

                Button("Build") {
                    Task {
                        await viewModel.rebuildSelectedProject()
                    }
                }
                .buttonStyle(AppActionButtonStyle(emphasized: false))
                .disabled(viewModel.selectedProject == nil || viewModel.isBusy)

                Button("Launch") {
                    Task {
                        await viewModel.launchSelectedProject()
                    }
                }
                .buttonStyle(AppActionButtonStyle(emphasized: true))
                .disabled(viewModel.selectedProject == nil || viewModel.isBusy)

                Button("Settings") {
                    viewModel.isShowingSettings = true
                }
                .buttonStyle(AppActionButtonStyle(emphasized: false))
            }
        }
    }
}
