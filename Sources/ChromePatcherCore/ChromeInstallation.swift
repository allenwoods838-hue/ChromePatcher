import Foundation

public struct ChromeInstallation: Equatable {
    public let version: String
    public let appURL: URL

    public init(version: String, appURL: URL) {
        self.version = version
        self.appURL = appURL
    }
}

public enum ChromeDetectionError: Error, LocalizedError {
    case unreadableInfoPlist(URL)
    case invalidInfoPlist(URL)
    case missingVersion(URL)

    public var errorDescription: String? {
        switch self {
        case .unreadableInfoPlist(let url):
            return "Could not read Chrome app metadata at \(url.path)."
        case .invalidInfoPlist(let url):
            return "Chrome app metadata is invalid at \(url.path)."
        case .missingVersion(let url):
            return "Chrome app metadata does not contain a version at \(url.path)."
        }
    }
}

public enum ChromeDetector {
    private static let bundleIdentifier = "com.google.Chrome"
    private static let appName = "Google Chrome.app"

    public static func detect(in applicationDirectories: [URL]) throws -> ChromeInstallation? {
        for directory in applicationDirectories {
            let appURL = directory.appendingPathComponent(appName, isDirectory: true)
            let infoURL = appURL.appendingPathComponent("Contents/Info.plist")
            guard FileManager.default.fileExists(atPath: infoURL.path) else {
                continue
            }

            let data: Data
            do {
                data = try Data(contentsOf: infoURL)
            } catch {
                throw ChromeDetectionError.unreadableInfoPlist(infoURL)
            }

            let propertyList: Any
            do {
                propertyList = try PropertyListSerialization.propertyList(
                    from: data,
                    options: [],
                    format: nil
                )
            } catch {
                throw ChromeDetectionError.invalidInfoPlist(infoURL)
            }

            guard let metadata = propertyList as? [String: Any],
                  metadata["CFBundleIdentifier"] as? String == bundleIdentifier else {
                continue
            }

            guard let version = (metadata["KSVersion"] as? String)
                ?? (metadata["CFBundleShortVersionString"] as? String)
                ?? (metadata["CFBundleVersion"] as? String),
                  !version.isEmpty else {
                throw ChromeDetectionError.missingVersion(infoURL)
            }

            return ChromeInstallation(version: version, appURL: appURL)
        }

        return nil
    }

    public static var defaultApplicationDirectories: [URL] {
        var directories = [URL(fileURLWithPath: "/Applications", isDirectory: true)]
        if let userApplications = FileManager.default.urls(
            for: .applicationDirectory,
            in: .userDomainMask
        ).first {
            directories.append(userApplications)
        }
        return directories
    }
}
