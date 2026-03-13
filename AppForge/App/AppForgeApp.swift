import SwiftUI

@main
/// App entry point for the native AppForge shell.
struct AppForgeApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            AppRootView(viewModel: viewModel)
                .frame(minWidth: 1420, minHeight: 900)
                .tint(viewModel.colorPalette.theme.accent)
                .environment(\.appTheme, viewModel.colorPalette.theme)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
