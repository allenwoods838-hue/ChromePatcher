import Foundation

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
