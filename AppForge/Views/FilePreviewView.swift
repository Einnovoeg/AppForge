import SwiftUI

/// Source preview pane for the currently selected generated file.
struct FilePreviewView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        AppPanel(title: "Source Preview", subtitle: fileSubtitle) {
            if viewModel.selectedFileContents.isEmpty {
                ContentUnavailableView(
                    "Select a file",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Source files, project manifests, and generated specs appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                CodeSurface {
                    ScrollView([.vertical, .horizontal]) {
                        Text(viewModel.selectedFileContents)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundStyle(theme.consoleText)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var fileSubtitle: String {
        if let selectedFileURL = viewModel.selectedFileURL,
           let selectedProject = viewModel.selectedProject {
            let projectRootPath = selectedProject.rootURL.path(percentEncoded: false) + "/"
            return selectedFileURL.path(percentEncoded: false)
                .replacingOccurrences(of: projectRootPath, with: "")
        }

        return "Browse the generated project and inspect the current source."
    }
}
