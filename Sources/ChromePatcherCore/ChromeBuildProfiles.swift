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

public struct ChromeBuildProfileSummary: Codable, Equatable {
    public let name: String
    public let minimumMacOS: String
    public let description: String?

    public init(name: String, profile: ChromeBuildProfile) {
        self.name = name
        self.minimumMacOS = profile.minimumMacOS
        self.description = profile.description
    }
}

public struct ChromeBuildProfileComparison: Codable, Equatable {
    public enum MinimumVersionRelation: String, Codable {
        case same
        case firstRequiresNewer
        case secondRequiresNewer
    }

    public let first: ChromeBuildProfileSummary
    public let second: ChromeBuildProfileSummary
    public let minimumVersionRelation: MinimumVersionRelation

    public init(first: ChromeBuildProfileSummary, second: ChromeBuildProfileSummary) throws {
        self.first = first
        self.second = second

        guard let firstMinimum = MacOSVersion(first.minimumMacOS) else {
            throw ChromeBuildProfileError.invalidMinimumVersion(first.name, first.minimumMacOS)
        }
        guard let secondMinimum = MacOSVersion(second.minimumMacOS) else {
            throw ChromeBuildProfileError.invalidMinimumVersion(second.name, second.minimumMacOS)
        }
        if firstMinimum == secondMinimum {
            minimumVersionRelation = .same
        } else if firstMinimum > secondMinimum {
            minimumVersionRelation = .firstRequiresNewer
        } else {
            minimumVersionRelation = .secondRequiresNewer
        }
    }
}

public enum ChromeBuildProfileError: Error, LocalizedError {
    case unreadableFile(URL)
    case invalidFile(URL)
    case profileNotFound(String, URL)
    case profileAlreadyExists(String, URL)
    case destinationAlreadyExists(URL)
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
        case .profileAlreadyExists(let name, let url):
            return "Chrome build profile '\(name)' already exists in \(url.path)."
        case .destinationAlreadyExists(let url):
            return "Cannot export profiles because the destination already exists at \(url.path)."
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
    ) throws -> String {
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
        let data = try encoder.encode(encodedFile)
        return String(decoding: data, as: UTF8.self)
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

        let template = try templateJSON(
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

    public func addProfile(named name: String, profile: ChromeBuildProfile) throws {
        try validate(name: name, profile: profile)
        guard file.profiles[name] == nil else {
            throw ChromeBuildProfileError.profileAlreadyExists(name, fileURL)
        }

        var updatedProfiles = file.profiles
        updatedProfiles[name] = profile
        try write(ChromeBuildProfileFile(profiles: updatedProfiles))
    }

    public func updateProfile(
        named name: String,
        minimumMacOS: String,
        description: String? = nil
    ) throws {
        guard let currentProfile = file.profiles[name] else {
            throw ChromeBuildProfileError.profileNotFound(name, fileURL)
        }

        let updatedProfile = ChromeBuildProfile(
            minimumMacOS: minimumMacOS,
            description: description ?? currentProfile.description
        )
        try validate(name: name, profile: updatedProfile)

        var updatedProfiles = file.profiles
        updatedProfiles[name] = updatedProfile
        try write(ChromeBuildProfileFile(profiles: updatedProfiles))
    }

    public func removeProfile(named name: String) throws {
        guard file.profiles[name] != nil else {
            throw ChromeBuildProfileError.profileNotFound(name, fileURL)
        }

        var updatedProfiles = file.profiles
        updatedProfiles.removeValue(forKey: name)
        try write(ChromeBuildProfileFile(profiles: updatedProfiles))
    }

    public func export(to destinationURL: URL, profileNames: [String]? = nil) throws {
        let directoryURL = destinationURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let exportFile = try selectedFile(named: profileNames)
        let data = try encodedFile(exportFile)
        let temporaryURL = directoryURL.appendingPathComponent(".\(UUID().uuidString).profiles")
        try data.write(to: temporaryURL, options: .atomic)
        do {
            try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                throw ChromeBuildProfileError.destinationAlreadyExists(destinationURL)
            }
            throw error
        }
    }

    public func importProfiles(from source: ChromeBuildProfiles, profileNames: [String]? = nil) throws {
        let sourceFile = try source.selectedFile(named: profileNames)
        for name in sourceFile.profiles.keys where file.profiles[name] != nil {
            throw ChromeBuildProfileError.profileAlreadyExists(name, fileURL)
        }

        var updatedProfiles = file.profiles
        updatedProfiles.merge(sourceFile.profiles) { _, incoming in incoming }
        try write(ChromeBuildProfileFile(profiles: updatedProfiles))
    }

    private func selectedFile(named profileNames: [String]?) throws -> ChromeBuildProfileFile {
        guard let profileNames else {
            return file
        }

        var selectedProfiles: [String: ChromeBuildProfile] = [:]
        for name in profileNames {
            guard let profile = file.profiles[name] else {
                throw ChromeBuildProfileError.profileNotFound(name, fileURL)
            }
            selectedProfiles[name] = profile
        }
        return ChromeBuildProfileFile(profiles: selectedProfiles)
    }

    private func validate(name: String, profile: ChromeBuildProfile) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              name == name.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw ChromeBuildProfileError.invalidProfileName
        }
        guard MacOSVersion(profile.minimumMacOS) != nil else {
            throw ChromeBuildProfileError.invalidMinimumVersion(name, profile.minimumMacOS)
        }
    }

    private func write(_ file: ChromeBuildProfileFile) throws {
        let data = try encodedFile(file)
        try data.write(to: fileURL, options: .atomic)
    }

    private func encodedFile(_ file: ChromeBuildProfileFile? = nil) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(file ?? self.file)
    }
}
