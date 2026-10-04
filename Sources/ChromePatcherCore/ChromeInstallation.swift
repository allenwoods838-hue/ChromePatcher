import Foundation

public struct ChromeInstallation: Equatable {
    public let version: String
    public let appURL: URL
    public let architectures: Set<BinaryArchitecture>

    public init(version: String, appURL: URL, architectures: Set<BinaryArchitecture>) {
        self.version = version
        self.appURL = appURL
        self.architectures = architectures
    }
}

public enum ChromeDetectionError: Error, LocalizedError {
    case unreadableInfoPlist(URL)
    case invalidInfoPlist(URL)
    case missingVersion(URL)
    case missingExecutable(URL)
    case unreadableExecutable(URL)
    case invalidExecutable(URL)

    public var errorDescription: String? {
        switch self {
        case .unreadableInfoPlist(let url):
            return "Could not read Chrome app metadata at \(url.path)."
        case .invalidInfoPlist(let url):
            return "Chrome app metadata is invalid at \(url.path)."
        case .missingVersion(let url):
            return "Chrome app metadata does not contain a version at \(url.path)."
        case .missingExecutable(let url):
            return "Chrome app metadata does not name an executable at \(url.path)."
        case .unreadableExecutable(let url):
            return "Could not read the Chrome executable at \(url.path)."
        case .invalidExecutable(let url):
            return "Chrome's executable has an invalid or unsupported Mach-O header at \(url.path)."
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

            guard let executableName = metadata["CFBundleExecutable"] as? String,
                  !executableName.isEmpty,
                  !executableName.contains("/") else {
                throw ChromeDetectionError.missingExecutable(infoURL)
            }

            let executableURL = appURL
                .appendingPathComponent("Contents/MacOS", isDirectory: true)
                .appendingPathComponent(executableName, isDirectory: false)
            let architectures: Set<BinaryArchitecture>
            do {
                architectures = try MachOArchitectures.read(from: executableURL)
            } catch let error as MachOArchitectures.ReadError {
                switch error {
                case .unreadable:
                    throw ChromeDetectionError.unreadableExecutable(executableURL)
                case .invalid:
                    throw ChromeDetectionError.invalidExecutable(executableURL)
                }
            }

            return ChromeInstallation(
                version: version,
                appURL: appURL,
                architectures: architectures
            )
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
