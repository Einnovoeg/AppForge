import Foundation

/// Bundle-backed release metadata surfaced in the UI and release documentation.
struct AppReleaseInfo {
    let marketingVersion: String
    let buildNumber: String

    var displayVersion: String {
        "v\(marketingVersion)"
    }

    var displayVersionWithBuild: String {
        "\(displayVersion) (\(buildNumber))"
    }

    var releaseSummary: String {
        "Release \(displayVersionWithBuild)"
    }

    static let current: AppReleaseInfo = {
        let bundle = Bundle.main
        let marketingVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        let buildNumber = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return AppReleaseInfo(marketingVersion: marketingVersion, buildNumber: buildNumber)
    }()
}
