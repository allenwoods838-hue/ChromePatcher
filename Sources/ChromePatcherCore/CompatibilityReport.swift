import Foundation

public struct CompatibilityReport: Codable, Equatable {
    public let schemaVersion: Int
    public let macOSVersion: String
    public let minimumMacOSVersion: String
    public let meetsMinimumMacOS: Bool
    public let macModelIdentifier: String
    public let macArchitecture: String
    public let chromeInstalled: Bool
    public let chromeVersion: String?
    public let chromePath: String?
    public let chromeArchitectures: [String]?
    public let nativeArchitectureAvailable: Bool?
    public let readiness: String
    public let readinessSummary: String
    public let readOnly: Bool

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case macOSVersion
        case minimumMacOSVersion
        case meetsMinimumMacOS
        case macModelIdentifier
        case macArchitecture
        case chromeInstalled
        case chromeVersion
        case chromePath
        case chromeArchitectures
        case nativeArchitectureAvailable
        case readiness
        case readinessSummary
        case readOnly
    }

    public init(
        installedMacOS: MacOSVersion,
        minimumMacOS: MacOSVersion,
        modelIdentifier: String,
        hostArchitecture: BinaryArchitecture,
        chromeInstallation: ChromeInstallation?
    ) {
        let readiness = CompatibilityReadiness(
            installedMacOS: installedMacOS,
            minimumMacOS: minimumMacOS,
            chromeArchitectures: chromeInstallation?.architectures,
            hostArchitecture: hostArchitecture
        )

        schemaVersion = 1
        macOSVersion = installedMacOS.description
        minimumMacOSVersion = minimumMacOS.description
        meetsMinimumMacOS = installedMacOS >= minimumMacOS
        macModelIdentifier = modelIdentifier
        macArchitecture = hostArchitecture.description
        chromeInstalled = chromeInstallation != nil
        chromeVersion = chromeInstallation?.version
        chromePath = chromeInstallation?.appURL.path
        chromeArchitectures = chromeInstallation?.architectures
            .map(\.description)
            .sorted()
        nativeArchitectureAvailable = chromeInstallation.map {
            $0.architectures.contains(hostArchitecture)
        }
        self.readiness = readiness.identifier
        readinessSummary = readiness.summary
        readOnly = true
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(macOSVersion, forKey: .macOSVersion)
        try container.encode(minimumMacOSVersion, forKey: .minimumMacOSVersion)
        try container.encode(meetsMinimumMacOS, forKey: .meetsMinimumMacOS)
        try container.encode(macModelIdentifier, forKey: .macModelIdentifier)
        try container.encode(macArchitecture, forKey: .macArchitecture)
        try container.encode(chromeInstalled, forKey: .chromeInstalled)
        try container.encode(chromeVersion, forKey: .chromeVersion)
        try container.encode(chromePath, forKey: .chromePath)
        try container.encode(chromeArchitectures, forKey: .chromeArchitectures)
        try container.encode(nativeArchitectureAvailable, forKey: .nativeArchitectureAvailable)
        try container.encode(readiness, forKey: .readiness)
        try container.encode(readinessSummary, forKey: .readinessSummary)
        try container.encode(readOnly, forKey: .readOnly)
    }
}

public enum CompatibilityReadiness: Equatable {
    case chromeNotInstalled
    case ready
    case macOSBelowMinimum
    case noNativeArchitecture
    case macOSBelowMinimumAndNoNativeArchitecture

    public init(
        installedMacOS: MacOSVersion,
        minimumMacOS: MacOSVersion,
        chromeArchitectures: Set<BinaryArchitecture>?,
        hostArchitecture: BinaryArchitecture?
    ) {
        guard let chromeArchitectures else {
            self = .chromeNotInstalled
            return
        }

        let macOSSupported = installedMacOS >= minimumMacOS
        let architectureSupported = hostArchitecture.map(chromeArchitectures.contains) ?? false

        switch (macOSSupported, architectureSupported) {
        case (true, true):
            self = .ready
        case (false, true):
            self = .macOSBelowMinimum
        case (true, false):
            self = .noNativeArchitecture
        case (false, false):
            self = .macOSBelowMinimumAndNoNativeArchitecture
        }
    }

    public var summary: String {
        switch self {
        case .chromeNotInstalled:
            "Cannot assess readiness because Google Chrome was not found."
        case .ready:
            "Ready: macOS meets the supplied minimum and Chrome has a native architecture slice."
        case .macOSBelowMinimum:
            "Not ready: macOS is below the supplied minimum."
        case .noNativeArchitecture:
            "Not ready natively: Chrome has no native architecture slice for this Mac."
        case .macOSBelowMinimumAndNoNativeArchitecture:
            "Not ready natively: macOS is below the supplied minimum and Chrome has no native architecture slice for this Mac."
        }
    }

    public var identifier: String {
        switch self {
        case .chromeNotInstalled: "chrome_not_installed"
        case .ready: "ready"
        case .macOSBelowMinimum: "macos_below_minimum"
        case .noNativeArchitecture: "no_native_architecture"
        case .macOSBelowMinimumAndNoNativeArchitecture: "macos_below_minimum_and_no_native_architecture"
        }
    }
}

public enum MacHardware {
    public enum IdentificationError: Error, LocalizedError {
        case unavailable

        public var errorDescription: String? {
            "Could not determine this Mac's model identifier."
        }
    }

    public static func modelIdentifier() throws -> String {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 1 else {
            throw IdentificationError.unavailable
        }

        var model = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &model, &size, nil, 0) == 0 else {
            throw IdentificationError.unavailable
        }

        let identifier = String(cString: model)
        guard !identifier.isEmpty else {
            throw IdentificationError.unavailable
        }
        return identifier
    }
}
