import SwiftUI

/// Center column for prompts, transcript, and build-phase feedback.
struct ConversationView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        AppPanel(
            title: viewModel.composerModeTitle,
            subtitle: viewModel.composerModeSummary,
            accessory: AnyView(statusBadgeRow)
        ) {
            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    InfoPill(title: "Phase", value: viewModel.buildPhase.label, tint: phaseTint)
                    InfoPill(title: "Routing", value: viewModel.aiRoutingStatus.modeLabel, tint: theme.accent)
                    InfoPill(title: "Models", value: viewModel.aiRoutingStatus.modelLabel, tint: theme.glow)
                    InfoPill(title: "Target", value: viewModel.selectedPlatform.displayName, tint: theme.glow)
                }

                if !viewModel.aiRoutingStatus.providerStatuses.isEmpty {
                    providerBadgeRow
                }

                transcript
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                composer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxHeight: .infinity)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }
                }
                .padding(18)
            }
            .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                guard let lastMessage = viewModel.messages.last else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.composeText)
                    .scrollContentBackground(.hidden)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .frame(minHeight: 120, maxHeight: 140)
                    .padding(12)
                    .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.20), lineWidth: 1)
                    }
                    .help("Describe the app you want to build or the refinement you want applied to the selected project.")
                    .disabled(viewModel.isBusy)

                if viewModel.composeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Describe the app you want to build or the next refinement you need.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 24)
                        .allowsHitTesting(false)
                }
            }

            HStack(alignment: .center, spacing: 12) {
                Text(viewModel.scaffoldModeSummary)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer()

                if viewModel.isBusy {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    Task {
                        await viewModel.sendCurrentPrompt()
                    }
                } label: {
                    Label("Send Prompt", systemImage: "arrow.up.circle.fill")
                }
                .help("Send the current prompt to AppForge for planning or refinement.")
                .buttonStyle(AppActionButtonStyle(emphasized: true))
                .keyboardShortcut(.return)
                .disabled(viewModel.composeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isBusy)
            }
        }
    }

    private var providerBadgeRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.aiRoutingStatus.providerStatuses, id: \.badge) { status in
                    Text(status.badge)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background((status.isReady ? theme.accent : .red).opacity(0.14), in: Capsule())
                }
            }
        }
    }

    private var statusBadgeRow: some View {
        HStack(spacing: 10) {
            if viewModel.isBusy {
                ProgressView()
                    .controlSize(.small)
            }

            Text(viewModel.aiRoutingStatus.networkLabel)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(theme.accent.opacity(0.14), in: Capsule())
        }
    }

    private var phaseTint: Color {
        viewModel.buildPhase == .failed ? .red : theme.accent
    }
}

/// Individual chat bubble inside the transcript stream.
private struct MessageBubbleView: View {
    @Environment(\.appTheme) private var theme
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top) {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                Text(message.text)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .frame(maxWidth: 620, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            }

            if message.role != .user {
                Spacer(minLength: 60)
            }
        }
    }

    private var title: String {
        switch message.role {
        case .assistant:
            return "AppForge"
        case .user:
            return "You"
        case .system:
            return "System"
        }
    }

    private var background: some ShapeStyle {
        switch message.role {
        case .assistant:
            return AnyShapeStyle(Color.white.opacity(0.14))
        case .user:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [theme.accent.opacity(0.22), theme.glow.opacity(0.16)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .system:
            return AnyShapeStyle(Color.gray.opacity(0.18))
        }
    }
}
