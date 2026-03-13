import Foundation

/// Built-in generators that can produce a real working app without calling an external model.
enum BuiltInRecipeKind {
    case sudoku

    static func detect(
        prompt: String,
        summary: String = "",
        features: [String] = [],
        name: String = ""
    ) -> BuiltInRecipeKind? {
        let combined = [prompt, summary, name, features.joined(separator: " ")]
            .joined(separator: " ")
            .lowercased()

        if combined.contains("sudoku") {
            return .sudoku
        }

        return nil
    }
}

/// Maps a recognized prompt to a first-party AppForge blueprint.
struct BuiltInRecipeService {
    func initialBlueprint(for prompt: String, platform: AppPlatform) -> AgentBlueprint? {
        guard platform == .macOS,
              let recipe = BuiltInRecipeKind.detect(prompt: prompt) else {
            return nil
        }

        return blueprint(for: recipe, appName: "Sudoku")
    }

    func refinementBlueprint(for prompt: String, project: GeneratedProject) -> AgentBlueprint? {
        guard project.platform == .macOS,
              let recipe = BuiltInRecipeKind.detect(
                prompt: prompt,
                summary: project.summary,
                features: project.features,
                name: "\(project.name) \(project.prompt)"
              ) else {
            return nil
        }

        return blueprint(for: recipe, appName: project.name)
    }

    private func blueprint(for recipe: BuiltInRecipeKind, appName: String) -> AgentBlueprint {
        switch recipe {
        case .sudoku:
            return AgentBlueprint(
                appName: appName,
                summary: "Playable Sudoku board with selectable puzzles, mistake highlighting, hints, restart controls, and a keypad-driven macOS interface.",
                features: [
                    "Playable 9x9 Sudoku board with clue locking",
                    "Hint, clear, restart, and next puzzle controls",
                    "Mistake highlighting and completion tracking",
                    "Multiple built-in puzzles with difficulty labels"
                ]
            )
        }
    }
}
