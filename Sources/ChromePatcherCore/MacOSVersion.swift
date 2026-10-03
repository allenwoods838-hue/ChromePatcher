import Foundation

public struct MacOSVersion: Comparable, CustomStringConvertible, Equatable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init?(_ value: String) {
        let components = value.split(separator: ".", omittingEmptySubsequences: false)
        guard (2...3).contains(components.count),
              components.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0 >= "0" && $0 <= "9" } }),
              let major = Int(components[0]),
              let minor = Int(components[1]) else {
            return nil
        }

        let patch = components.count == 3 ? Int(components[2]) : 0
        guard let patch else {
            return nil
        }

        self.init(major: major, minor: minor, patch: patch)
    }

    public static func < (lhs: MacOSVersion, rhs: MacOSVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    public var description: String {
        patch == 0 ? "\(major).\(minor)" : "\(major).\(minor).\(patch)"
    }

    public var marketingName: String? {
        switch (major, minor) {
        case (10, 15): "Catalina"
        case (11, _): "Big Sur"
        case (12, _): "Monterey"
        default: nil
        }
    }

    public var displayName: String {
        if let marketingName {
            return "macOS \(description) (\(marketingName))"
        }
        return "macOS \(description)"
    }
}

public enum CompatibilityResult: Equatable {
    case atOrAboveMinimum
    case belowMinimum

    public init(installed: MacOSVersion, minimum: MacOSVersion) {
        self = installed >= minimum ? .atOrAboveMinimum : .belowMinimum
    }
}
