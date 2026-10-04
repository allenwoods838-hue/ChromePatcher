import Foundation

public struct ChromeBuildProfile: Codable, Equatable {
    public let minimumMacOS: String
    public let description: String?

    public init(minimumMacOS: String, description: String? = nil) {
        self.minimumMacOS = minimumMacOS
        self.description = description
    }
}

public struct ChromeBuildProfileFile: Codable, Equatable {
    public let profiles: [String: ChromeBuildProfile]

    public init(profiles: [String: ChromeBuildProfile]) {
        self.profiles = profiles
    }
}

public enum ChromeBuildProfileError: Error, LocalizedError {
    case unreadableFile(URL)
    case invalidFile(URL)
    case profileNotFound(String, URL)
    case invalidMinimumVersion(String, String)
    case invalidProfileName

    public var errorDescription: String? {
        switch self {
        case .unreadableFile(let url):
            return "Could not read Chrome build profiles at \(url.path)."
        case .invalidFile(let url):
            return "Chrome build profiles are invalid at \(url.path). Expected a JSON object with a \"profiles\" object."
        case .profileNotFound(let name, let url):
            return "Chrome build profile '\(name)' was not found in \(url.path)."
        case .invalidMinimumVersion(let name, let value):
            return "Chrome build profile '\(name)' has invalid minimum macOS version '\(value)'."
        case .invalidProfileName:
            return "Chrome build profile names must not be empty."
        }
    }
}

public struct ChromeBuildProfiles {
    public let fileURL: URL
    private let file: ChromeBuildProfileFile

    private init(fileURL: URL, file: ChromeBuildProfileFile) {
        self.fileURL = fileURL
        self.file = file
    }

    public static var defaultFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ChromePatcher/profiles.json")
    }

    public static func templateJSON(
        profileName: String = "my-chrome-build",
        minimumMacOS: String = "12.0",
        description: String? = "Example profile; verify this minimum for the exact build."
    ) -> String {
        let normalizedName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = normalizedName.isEmpty ? "my-chrome-build" : normalizedName
        let encodedFile = ChromeBuildProfileFile(profiles: [
            safeName: ChromeBuildProfile(
                minimumMacOS: minimumMacOS,
                description: description
            )
        ])

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try! encoder.encode(encodedFile)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    public static func writeTemplate(
        to fileURL: URL,
        profileName: String = "my-chrome-build",
        minimumMacOS: String = "12.0",
        description: String? = "Example profile; verify this minimum for the exact build."
    ) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let template = templateJSON(
            profileName: profileName,
            minimumMacOS: minimumMacOS,
            description: description
        )
        try template.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    public static func load(from fileURL: URL) throws -> ChromeBuildProfiles {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw ChromeBuildProfileError.unreadableFile(fileURL)
        }

        let file: ChromeBuildProfileFile
        do {
            file = try JSONDecoder().decode(ChromeBuildProfileFile.self, from: data)
        } catch {
            throw ChromeBuildProfileError.invalidFile(fileURL)
        }

        guard file.profiles.keys.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw ChromeBuildProfileError.invalidProfileName
        }
        for (name, profile) in file.profiles where MacOSVersion(profile.minimumMacOS) == nil {
            throw ChromeBuildProfileError.invalidMinimumVersion(name, profile.minimumMacOS)
        }

        return ChromeBuildProfiles(fileURL: fileURL, file: file)
    }

    public var names: [String] {
        file.profiles.keys.sorted()
    }

    public func minimumMacOSVersion(for name: String) throws -> MacOSVersion {
        guard let profile = file.profiles[name] else {
            throw ChromeBuildProfileError.profileNotFound(name, fileURL)
        }
        guard let minimumVersion = MacOSVersion(profile.minimumMacOS) else {
            throw ChromeBuildProfileError.invalidMinimumVersion(name, profile.minimumMacOS)
        }
        return minimumVersion
    }

    public func profile(named name: String) -> ChromeBuildProfile? {
        file.profiles[name]
    }
}
