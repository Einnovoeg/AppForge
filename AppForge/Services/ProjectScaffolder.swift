import Foundation

/// Errors surfaced while scaffolding a generated project on disk.
enum ProjectScaffolderError: LocalizedError {
    case unsupportedPlatform

    var errorDescription: String? {
        switch self {
        case .unsupportedPlatform:
            return "This MVP only scaffolds macOS SwiftUI apps right now."
        }
    }
}

/// Writes generated project files for either generic shells or built-in recipes like Sudoku.
struct ProjectScaffolder {
    private let fileManager = FileManager.default

    func createProject(
        from blueprint: AgentBlueprint,
        prompt: String,
        platform: AppPlatform,
        workspaceManager: WorkspaceManager
    ) throws -> GeneratedProject {
        guard platform == .macOS else {
            throw ProjectScaffolderError.unsupportedPlatform
        }

        try workspaceManager.bootstrapDirectories()

        let projectName = sanitizeProjectName(blueprint.appName)
        let projectRoot = workspaceManager.makeProjectRoot(for: projectName)
        try fileManager.createDirectory(at: projectRoot, withIntermediateDirectories: true, attributes: nil)

        let spec = GeneratedProjectSpec(
            name: projectName,
            platform: platform,
            bundleIdentifier: "com.appforge.generated.\(projectName.lowercased())",
            prompt: prompt,
            summary: blueprint.summary,
            features: blueprint.features,
            createdAt: .now,
            updatedAt: .now,
            refinementHistory: []
        )

        try writeProjectFiles(spec: spec, to: projectRoot)
        return GeneratedProject(rootURL: projectRoot, spec: spec)
    }

    func refineProject(
        _ project: GeneratedProject,
        with blueprint: AgentBlueprint,
        prompt: String
    ) throws -> GeneratedProject {
        var updatedSpec = project.spec
        updatedSpec.summary = blueprint.summary
        updatedSpec.features = blueprint.features
        updatedSpec.updatedAt = .now
        updatedSpec.refinementHistory.append(prompt)

        try writeProjectFiles(spec: updatedSpec, to: project.rootURL)
        return GeneratedProject(rootURL: project.rootURL, spec: updatedSpec)
    }

    private func writeProjectFiles(spec: GeneratedProjectSpec, to rootURL: URL) throws {
        let sourceDirectory = rootURL
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent(spec.name, isDirectory: true)

        try fileManager.createDirectory(at: sourceDirectory, withIntermediateDirectories: true, attributes: nil)

        let recipe = BuiltInRecipeKind.detect(
            prompt: spec.prompt,
            summary: spec.summary,
            features: spec.features,
            name: spec.name
        )

        try write(
            templateNamed: "project.yml.template",
            to: rootURL.appendingPathComponent("project.yml"),
            replacements: [
                "{{PRODUCT_NAME}}": spec.name,
                "{{BUNDLE_IDENTIFIER}}": spec.bundleIdentifier
            ]
        )

        try write(
            templateNamed: "App.swift.template",
            to: sourceDirectory.appendingPathComponent("\(spec.name)App.swift"),
            replacements: [
                "{{PRODUCT_NAME}}": spec.name
            ]
        )

        switch recipe {
        case .sudoku:
            // Built-in recipes can replace the generic shell with a functional starter app.
            try sudokuContentViewSource(productName: spec.name)
                .write(to: sourceDirectory.appendingPathComponent("ContentView.swift"), atomically: true, encoding: .utf8)
            try sudokuGameSource()
                .write(to: sourceDirectory.appendingPathComponent("SudokuGame.swift"), atomically: true, encoding: .utf8)
        case nil:
            let sudokuGameURL = sourceDirectory.appendingPathComponent("SudokuGame.swift")
            if fileManager.fileExists(atPath: sudokuGameURL.path) {
                try fileManager.removeItem(at: sudokuGameURL)
            }

            try write(
                templateNamed: "ContentView.swift.template",
                to: sourceDirectory.appendingPathComponent("ContentView.swift"),
                replacements: [
                    "{{PRODUCT_NAME}}": spec.name,
                    "{{SUMMARY}}": swiftStringLiteral(spec.summary),
                    "{{PROMPT}}": swiftStringLiteral(spec.prompt),
                    "{{FEATURES_ARRAY}}": swiftArrayLiteral(spec.features),
                    "{{UPDATED_AT}}": swiftStringLiteral(Self.displayDateFormatter.string(from: spec.updatedAt))
                ]
            )
        }

        try write(
            templateNamed: "README.md.template",
            to: rootURL.appendingPathComponent("README.md"),
            replacements: [
                "{{PRODUCT_NAME}}": spec.name,
                "{{SUMMARY}}": spec.summary,
                "{{FEATURE_LIST}}": markdownFeatureList(spec.features)
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let specData = try encoder.encode(spec)
        try specData.write(to: rootURL.appendingPathComponent("AppForgeSpec.json"), options: .atomic)
    }

    private func write(templateNamed name: String, to destination: URL, replacements: [String: String]) throws {
        var content = try loadTemplate(named: name)
        for (key, value) in replacements {
            content = content.replacingOccurrences(of: key, with: value)
        }
        try content.write(to: destination, atomically: true, encoding: .utf8)
    }

    private func loadTemplate(named name: String) throws -> String {
        let bundledTemplateURL = Bundle.main.resourceURL?
            .appendingPathComponent("Templates", isDirectory: true)
            .appendingPathComponent("macOSSwiftUI", isDirectory: true)
            .appendingPathComponent(name)

        if let bundledTemplateURL, fileManager.fileExists(atPath: bundledTemplateURL.path) {
            return try String(contentsOf: bundledTemplateURL, encoding: .utf8)
        }

        return try fallbackTemplate(named: name)
    }

    private func fallbackTemplate(named name: String) throws -> String {
        switch name {
        case "project.yml.template":
            return """
            name: {{PRODUCT_NAME}}

            options:
              minimumXcodeGenVersion: 2.38.0
              createIntermediateGroups: true

            settings:
              base:
                PRODUCT_BUNDLE_IDENTIFIER: {{BUNDLE_IDENTIFIER}}
                PRODUCT_NAME: {{PRODUCT_NAME}}
                SWIFT_VERSION: 6.0
                MACOSX_DEPLOYMENT_TARGET: 15.0
                GENERATE_INFOPLIST_FILE: YES
                INFOPLIST_KEY_CFBundleDisplayName: {{PRODUCT_NAME}}
                INFOPLIST_KEY_LSApplicationCategoryType: public.app-category.developer-tools

            targets:
              {{PRODUCT_NAME}}:
                type: application
                platform: macOS
                deploymentTarget: 15.0
                sources:
                  - path: Sources
            """
        case "App.swift.template":
            return """
            // Generated by AppForge as the app entry point for this project.
            import SwiftUI

            @main
            struct {{PRODUCT_NAME}}App: App {
                var body: some Scene {
                    WindowGroup {
                        ContentView()
                    }
                }
            }
            """
        case "ContentView.swift.template":
            return """
            // Generated by AppForge as a scaffold-first placeholder view.
            import SwiftUI

            struct ContentView: View {
                private let features = [
            {{FEATURES_ARRAY}}
                ]

                var body: some View {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("{{PRODUCT_NAME}}")
                            .font(.system(size: 30, weight: .bold, design: .rounded))

                        Text("{{SUMMARY}}")
                            .font(.title3)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("What this build includes")
                                .font(.headline)

                            ForEach(features, id: \\.self) { feature in
                                Label(feature, systemImage: "checkmark.circle.fill")
                            }
                        }

                        Text("Source prompt")
                            .font(.headline)
                            .padding(.top, 8)

                        Text("{{PROMPT}}")
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("Updated {{UPDATED_AT}}")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(28)
                    .frame(minWidth: 720, minHeight: 480)
                }
            }
            """
        case "README.md.template":
            return """
            # {{PRODUCT_NAME}}

            {{SUMMARY}}

            ## Features

            {{FEATURE_LIST}}
            """
        default:
            throw CocoaError(.fileNoSuchFile)
        }
    }

    private func sanitizeProjectName(_ value: String) -> String {
        let filtered = value.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()

        guard !filtered.isEmpty else {
            return "GeneratedApp"
        }

        if let first = filtered.first, first.isNumber {
            return "App\(filtered)"
        }

        return filtered
    }

    private func markdownFeatureList(_ features: [String]) -> String {
        features.map { "- \($0)" }.joined(separator: "\n")
    }

    private func swiftStringLiteral(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private func swiftArrayLiteral(_ values: [String]) -> String {
        values.map { value in
            let escaped = swiftStringLiteral(value)
            return "            \"\(escaped)\""
        }.joined(separator: ",\n")
    }

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private func sudokuContentViewSource(productName: String) -> String {
        """
        // Generated by AppForge's built-in Sudoku recipe.
        import SwiftUI

        struct ContentView: View {
            @StateObject private var game = SudokuGame()

            var body: some View {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    HStack(alignment: .top, spacing: 24) {
                        SudokuBoardView(game: game)

                        VStack(alignment: .leading, spacing: 18) {
                            statsPanel
                            controlsPanel
                            helpPanel
                        }
                        .frame(width: 280)
                    }

                    if game.isSolved {
                        Label("Puzzle solved. Pick another one or restart to play again.", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                            .padding(.top, 4)
                    }
                }
                .padding(28)
                .frame(minWidth: 980, minHeight: 680)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.96, green: 0.95, blue: 0.90),
                            Color(red: 0.90, green: 0.93, blue: 0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }

            private var header: some View {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(productName)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))

                    Text("Playable Sudoku with locked clues, hints, and multiple built-in puzzles.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            private var statsPanel: some View {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Puzzle")
                        .font(.headline)

                    StatRow(label: "Difficulty", value: game.currentPuzzle.title)
                    StatRow(label: "Filled", value: "\\(game.filledCellCount)/81")
                    StatRow(label: "Mistakes", value: game.mistakeLabel)
                    StatRow(label: "Selection", value: game.selectionLabel)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }

            private var controlsPanel: some View {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Controls")
                        .font(.headline)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(1...9, id: \\.self) { number in
                            Button {
                                game.setValue(number)
                            } label: {
                                Text("\\(number)")
                                    .font(.title3.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(game.selectedCell == nil || game.selectedCellIsLocked)
                        }
                    }

                    HStack(spacing: 10) {
                        Button("Clear") {
                            game.clearSelectedCell()
                        }
                        .buttonStyle(.bordered)
                        .disabled(game.selectedCell == nil || game.selectedCellIsLocked)

                        Button("Hint") {
                            game.applyHint()
                        }
                        .buttonStyle(.bordered)
                        .disabled(game.selectedCell == nil || game.selectedCellIsLocked)
                    }

                    HStack(spacing: 10) {
                        Button("Restart") {
                            game.restartPuzzle()
                        }
                        .buttonStyle(.bordered)

                        Button("Next Puzzle") {
                            game.nextPuzzle()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }

            private var helpPanel: some View {
                VStack(alignment: .leading, spacing: 10) {
                    Text("How to play")
                        .font(.headline)

                    Text("Select any empty cell, then use the keypad to place a number. Locked clues are bold. Incorrect entries are highlighted in red until you clear them or use a hint.")
                        .foregroundStyle(.secondary)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }

        private struct SudokuBoardView: View {
            @ObservedObject var game: SudokuGame

            var body: some View {
                VStack(spacing: 8) {
                    ForEach(0..<3, id: \\.self) { boxRow in
                        HStack(spacing: 8) {
                            ForEach(0..<3, id: \\.self) { boxColumn in
                                VStack(spacing: 2) {
                                    ForEach(0..<3, id: \\.self) { rowOffset in
                                        HStack(spacing: 2) {
                                            ForEach(0..<3, id: \\.self) { columnOffset in
                                                let row = boxRow * 3 + rowOffset
                                                let column = boxColumn * 3 + columnOffset
                                                SudokuCellButton(game: game, row: row, column: column)
                                            }
                                        }
                                    }
                                }
                                .padding(6)
                                .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                        }
                    }
                }
                .padding(14)
                .background(Color.black.opacity(0.10), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
        }

        private struct SudokuCellButton: View {
            @ObservedObject var game: SudokuGame
            let row: Int
            let column: Int

            var body: some View {
                Button {
                    game.select(row: row, column: column)
                } label: {
                    Text(value.map(String.init) ?? "")
                        .font(.system(size: 22, weight: isLocked ? .bold : .semibold, design: .rounded))
                        .foregroundStyle(foregroundColor)
                        .frame(width: 50, height: 50)
                        .background(background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            private var cell: SudokuGame.Cell {
                SudokuGame.Cell(row: row, column: column)
            }

            private var value: Int? {
                game.displayValue(row: row, column: column)
            }

            private var isLocked: Bool {
                game.isLocked(row: row, column: column)
            }

            private var foregroundColor: Color {
                if game.isMistake(cell) {
                    return Color.red
                }

                return isLocked ? Color.primary : Color(red: 0.12, green: 0.36, blue: 0.62)
            }

            private var background: some ShapeStyle {
                if game.isSelected(cell) {
                    return AnyShapeStyle(Color(red: 0.74, green: 0.85, blue: 0.97))
                }

                if game.isMistake(cell) {
                    return AnyShapeStyle(Color.red.opacity(0.18))
                }

                if game.isHighlighted(cell) {
                    return AnyShapeStyle(Color(red: 0.93, green: 0.96, blue: 0.99))
                }

                return AnyShapeStyle(Color.white.opacity(0.86))
            }
        }

        private struct StatRow: View {
            let label: String
            let value: String

            var body: some View {
                HStack {
                    Text(label)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(value)
                        .fontWeight(.semibold)
                }
            }
        }
        """
    }

    private func sudokuGameSource() -> String {
        """
        // Generated by AppForge's built-in Sudoku recipe.
        import Foundation
        import SwiftUI

        final class SudokuGame: ObservableObject {
            struct Cell: Hashable {
                let row: Int
                let column: Int
            }

            struct Puzzle {
                let title: String
                let givens: [[Int]]
                let solution: [[Int]]
            }

            @Published private(set) var puzzleIndex = 0
            @Published private(set) var entries = Array(repeating: Array(repeating: 0, count: 9), count: 9)
            @Published private(set) var selectedCell: Cell?
            @Published private(set) var mistakes: Set<Cell> = []
            @Published private(set) var isSolved = false

            // Read through a computed property to keep Swift 6 happy with static storage access.
            var puzzles: [Puzzle] {
                Self.library
            }

            init() {
                loadPuzzle(index: 0)
            }

            var currentPuzzle: Puzzle {
                puzzles[puzzleIndex]
            }

            var filledCellCount: Int {
                (0..<9).reduce(0) { total, row in
                    total + (0..<9).filter { column in
                        displayValue(row: row, column: column) != nil
                    }.count
                }
            }

            var mistakeLabel: String {
                mistakes.isEmpty ? "None" : "\\(mistakes.count)"
            }

            var selectionLabel: String {
                guard let selectedCell else {
                    return "None"
                }

                return "R\\(selectedCell.row + 1) C\\(selectedCell.column + 1)"
            }

            var selectedCellIsLocked: Bool {
                guard let selectedCell else {
                    return true
                }

                return isLocked(row: selectedCell.row, column: selectedCell.column)
            }

            func displayValue(row: Int, column: Int) -> Int? {
                let given = currentPuzzle.givens[row][column]
                let value = given == 0 ? entries[row][column] : given
                return value == 0 ? nil : value
            }

            func isLocked(row: Int, column: Int) -> Bool {
                currentPuzzle.givens[row][column] != 0
            }

            func select(row: Int, column: Int) {
                selectedCell = Cell(row: row, column: column)
            }

            func isSelected(_ cell: Cell) -> Bool {
                selectedCell == cell
            }

            func isMistake(_ cell: Cell) -> Bool {
                mistakes.contains(cell)
            }

            func isHighlighted(_ cell: Cell) -> Bool {
                guard let selectedCell else {
                    return false
                }

                if selectedCell == cell {
                    return true
                }

                return selectedCell.row == cell.row
                    || selectedCell.column == cell.column
                    || (selectedCell.row / 3 == cell.row / 3 && selectedCell.column / 3 == cell.column / 3)
            }

            func setValue(_ number: Int) {
                guard let selectedCell, !isLocked(row: selectedCell.row, column: selectedCell.column) else {
                    return
                }

                entries[selectedCell.row][selectedCell.column] = number
                refreshState(for: selectedCell)
            }

            func clearSelectedCell() {
                guard let selectedCell, !isLocked(row: selectedCell.row, column: selectedCell.column) else {
                    return
                }

                entries[selectedCell.row][selectedCell.column] = 0
                mistakes.remove(selectedCell)
                isSolved = false
            }

            func applyHint() {
                guard let selectedCell, !isLocked(row: selectedCell.row, column: selectedCell.column) else {
                    return
                }

                entries[selectedCell.row][selectedCell.column] = currentPuzzle.solution[selectedCell.row][selectedCell.column]
                mistakes.remove(selectedCell)
                evaluateBoard()
            }

            func restartPuzzle() {
                entries = Array(repeating: Array(repeating: 0, count: 9), count: 9)
                mistakes.removeAll()
                isSolved = false
                selectedCell = nil
            }

            func nextPuzzle() {
                loadPuzzle(index: (puzzleIndex + 1) % puzzles.count)
            }

            private func loadPuzzle(index: Int) {
                puzzleIndex = index
                restartPuzzle()
            }

            private func refreshState(for cell: Cell) {
                let expected = currentPuzzle.solution[cell.row][cell.column]
                let actual = entries[cell.row][cell.column]

                if actual == 0 {
                    mistakes.remove(cell)
                } else if actual == expected {
                    mistakes.remove(cell)
                } else {
                    mistakes.insert(cell)
                }

                evaluateBoard()
            }

            private func evaluateBoard() {
                // A puzzle is solved only when every rendered value matches the known solution.
                for row in 0..<9 {
                    for column in 0..<9 {
                        guard displayValue(row: row, column: column) == currentPuzzle.solution[row][column] else {
                            isSolved = false
                            return
                        }
                    }
                }

                mistakes.removeAll()
                isSolved = true
            }

            private static let library: [Puzzle] = [
                Puzzle(
                    title: "Easy",
                    givens: [
                        [5, 3, 0, 0, 7, 0, 0, 0, 0],
                        [6, 0, 0, 1, 9, 5, 0, 0, 0],
                        [0, 9, 8, 0, 0, 0, 0, 6, 0],
                        [8, 0, 0, 0, 6, 0, 0, 0, 3],
                        [4, 0, 0, 8, 0, 3, 0, 0, 1],
                        [7, 0, 0, 0, 2, 0, 0, 0, 6],
                        [0, 6, 0, 0, 0, 0, 2, 8, 0],
                        [0, 0, 0, 4, 1, 9, 0, 0, 5],
                        [0, 0, 0, 0, 8, 0, 0, 7, 9]
                    ],
                    solution: SudokuGame.solution
                ),
                Puzzle(
                    title: "Medium",
                    givens: [
                        [0, 0, 4, 6, 0, 0, 9, 0, 0],
                        [6, 0, 0, 0, 9, 5, 0, 4, 0],
                        [0, 9, 0, 3, 0, 2, 0, 0, 7],
                        [8, 0, 9, 0, 0, 1, 0, 2, 0],
                        [0, 2, 0, 8, 0, 3, 0, 9, 0],
                        [0, 1, 0, 9, 0, 0, 8, 0, 6],
                        [9, 0, 0, 5, 0, 7, 0, 8, 0],
                        [0, 8, 0, 4, 1, 0, 0, 0, 5],
                        [0, 0, 5, 0, 0, 6, 1, 0, 0]
                    ],
                    solution: SudokuGame.solution
                ),
                Puzzle(
                    title: "Hard",
                    givens: [
                        [0, 0, 0, 6, 0, 0, 0, 1, 0],
                        [0, 7, 0, 0, 0, 5, 0, 0, 8],
                        [1, 0, 0, 0, 4, 0, 0, 0, 0],
                        [0, 0, 9, 0, 0, 0, 4, 0, 0],
                        [0, 2, 0, 0, 0, 0, 0, 9, 0],
                        [0, 0, 3, 0, 0, 0, 8, 0, 0],
                        [0, 0, 0, 0, 3, 0, 0, 0, 4],
                        [2, 0, 0, 4, 0, 0, 0, 3, 0],
                        [0, 4, 0, 0, 0, 6, 0, 0, 0]
                    ],
                    solution: SudokuGame.solution
                )
            ]

            private static let solution: [[Int]] = [
                [5, 3, 4, 6, 7, 8, 9, 1, 2],
                [6, 7, 2, 1, 9, 5, 3, 4, 8],
                [1, 9, 8, 3, 4, 2, 5, 6, 7],
                [8, 5, 9, 7, 6, 1, 4, 2, 3],
                [4, 2, 6, 8, 5, 3, 7, 9, 1],
                [7, 1, 3, 9, 2, 4, 8, 5, 6],
                [9, 6, 1, 5, 3, 7, 2, 8, 4],
                [2, 8, 7, 4, 1, 9, 6, 3, 5],
                [3, 4, 5, 2, 8, 6, 1, 7, 9]
            ]
        }
        """
    }
}
