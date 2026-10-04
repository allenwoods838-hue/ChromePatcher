import ChromePatcherCore
import Darwin
import Foundation

private let usage = """
Usage:
  ChromePatcher --minimum-macos VERSION [--json]
  ChromePatcher --profile NAME [--profiles-file PATH] [--json]
  ChromePatcher --list-profiles [--profiles-file PATH]
  ChromePatcher --profile-template [NAME]
  ChromePatcher --validate-profiles-file PATH
  ChromePatcher --init-profiles-file [PATH]

Detect Google Chrome and compare this Mac's macOS version with a Chrome build's minimum.
VERSION must be numeric, for example 12.0 or 10.15.7.
Use --profile NAME to check a named local build profile.
Use --list-profiles to list configured profile names.
Use --profile-template NAME to print a JSON template for a new profile.
Use --validate-profiles-file PATH to validate a profiles JSON file.
Use --init-profiles-file PATH to create a starter profiles file in the standard location.
Use --profiles-file PATH to select a profiles JSON file.
Add --json to emit a machine-readable JSON report.
Chrome is searched for in /Applications and ~/Applications.
The Chrome executable's CPU architectures are checked against this Mac.
Default profiles file: ~/Library/Application Support/ChromePatcher/profiles.json
This checker is read-only; it does not modify macOS or Chrome.
"""

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments == ["--help"] || arguments == ["-h"] {
    print(usage)
    exit(0)
}

let jsonArguments = arguments.filter { $0 == "--json" }
var commandArguments = arguments.filter { $0 != "--json" }
guard jsonArguments.count <= 1 else {
    fputs("\(usage)\n", stderr)
    exit(2)
}

var profilesFileURL: URL?
if let profilesFileIndex = commandArguments.firstIndex(of: "--profiles-file") {
    guard profilesFileIndex + 1 < commandArguments.count else {
        fputs("\(usage)\n", stderr)
        exit(2)
    }
    profilesFileURL = URL(fileURLWithPath: commandArguments[profilesFileIndex + 1])
    commandArguments.removeSubrange(profilesFileIndex...(profilesFileIndex + 1))
}

let minimumVersion: MacOSVersion
switch commandArguments.first {
case "--minimum-macos":
    guard commandArguments.count == 2, profilesFileURL == nil,
          let version = MacOSVersion(commandArguments[1]) else {
        fputs("Invalid minimum macOS version or command options.\n\(usage)\n", stderr)
        exit(2)
    }
    minimumVersion = version
case "--profile":
    guard commandArguments.count == 2 else {
        fputs("\(usage)\n", stderr)
        exit(2)
    }
    let profileURL = profilesFileURL ?? ChromeBuildProfiles.defaultFileURL
    do {
        minimumVersion = try ChromeBuildProfiles.load(from: profileURL)
            .minimumMacOSVersion(for: commandArguments[1])
    } catch {
        fputs("\(error.localizedDescription)\n", stderr)
        exit(2)
    }
case "--list-profiles":
    guard commandArguments.count == 1, jsonArguments.isEmpty else {
        fputs("\(usage)\n", stderr)
        exit(2)
    }
    let profileURL = profilesFileURL ?? ChromeBuildProfiles.defaultFileURL
    do {
        let profiles = try ChromeBuildProfiles.load(from: profileURL)
        for name in profiles.names {
            if let profile = profiles.profile(named: name) {
                let description = profile.description.map { " - \($0)" } ?? ""
                print("\(name): macOS \(profile.minimumMacOS)\(description)")
            }
        }
    } catch {
        fputs("\(error.localizedDescription)\n", stderr)
        exit(2)
    }
    exit(0)
case "--profile-template":
    guard commandArguments.count <= 2, jsonArguments.isEmpty else {
        fputs("\(usage)\n", stderr)
        exit(2)
    }
    let profileName = commandArguments.count == 2 ? commandArguments[1] : "my-chrome-build"
    guard !profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        fputs("Profile names must not be empty.\n\(usage)\n", stderr)
        exit(2)
    }
    print(ChromeBuildProfiles.templateJSON(profileName: profileName))
    exit(0)
case "--validate-profiles-file":
    guard commandArguments.count == 2, jsonArguments.isEmpty else {
        fputs("\(usage)\n", stderr)
        exit(2)
    }
    let profileURL = URL(fileURLWithPath: commandArguments[1])
    do {
        _ = try ChromeBuildProfiles.load(from: profileURL)
        print("Valid Chrome build profiles file: \(profileURL.path)")
    } catch {
        fputs("\(error.localizedDescription)\n", stderr)
        exit(2)
    }
    exit(0)
case "--init-profiles-file":
    guard commandArguments.count <= 2, jsonArguments.isEmpty else {
        fputs("\(usage)\n", stderr)
        exit(2)
    }
    let profileURL = commandArguments.count == 2 ? URL(fileURLWithPath: commandArguments[1]) : ChromeBuildProfiles.defaultFileURL
    if FileManager.default.fileExists(atPath: profileURL.path) {
        fputs("Profile file already exists at \(profileURL.path).\n", stderr)
        exit(2)
    }
    do {
        try ChromeBuildProfiles.writeTemplate(to: profileURL)
        print("Created profile file: \(profileURL.path)")
    } catch {
        fputs("\(error.localizedDescription)\n", stderr)
        exit(2)
    }
    exit(0)
default:
    fputs("\(usage)\n", stderr)
    exit(2)
}

let selectedProfileName = commandArguments.first == "--profile" ? commandArguments[1] : nil

#if os(macOS)
let systemVersion = ProcessInfo.processInfo.operatingSystemVersion
let installedVersion = MacOSVersion(
    major: systemVersion.majorVersion,
    minor: systemVersion.minorVersion,
    patch: systemVersion.patchVersion
)
let modelIdentifier: String
do {
    modelIdentifier = try MacHardware.modelIdentifier()
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(2)
}

let chromeInstallation: ChromeInstallation?
do {
    chromeInstallation = try ChromeDetector.detect(
        in: ChromeDetector.defaultApplicationDirectories
    )
} catch {
    fputs("Could not inspect Google Chrome: \(error.localizedDescription)\n", stderr)
    exit(2)
}

guard let hostArchitecture = BinaryArchitecture.host else {
    fputs("Could not determine this Mac's CPU architecture.\n", stderr)
    exit(2)
}

let report = CompatibilityReport(
    installedMacOS: installedVersion,
    minimumMacOS: minimumVersion,
    modelIdentifier: modelIdentifier,
    hostArchitecture: hostArchitecture,
    chromeInstallation: chromeInstallation,
    profileName: selectedProfileName
)
let readiness = CompatibilityReadiness(
    installedMacOS: installedVersion,
    minimumMacOS: minimumVersion,
    chromeArchitectures: chromeInstallation?.architectures,
    hostArchitecture: hostArchitecture
)

if !jsonArguments.isEmpty {
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var output = try encoder.encode(report)
        output.append(0x0a)
        FileHandle.standardOutput.write(output)
    } catch {
        fputs("Could not encode JSON report: \(error.localizedDescription)\n", stderr)
        exit(2)
    }
} else {
    print("Detected: \(installedVersion.displayName)")
    print("Mac model: \(modelIdentifier)")
    print("Mac architecture: \(hostArchitecture)")
    if let chromeInstallation {
        print("Google Chrome: version \(chromeInstallation.version)")
        print("Location: \(chromeInstallation.appURL.path)")
        print("Chrome architectures: \(chromeInstallation.architectures.map(\.description).sorted().joined(separator: ", "))")
        if chromeInstallation.architectures.contains(hostArchitecture) {
            print("Architecture result: native support is available.")
        } else {
            print("Architecture result: no native slice is available.")
            if hostArchitecture == .arm64, chromeInstallation.architectures.contains(.x86_64) {
                print("An x86_64 build may run through Rosetta if Rosetta is installed.")
            }
        }
    } else {
        print("Google Chrome: not found in /Applications or ~/Applications")
    }
    print("Chrome build minimum: macOS \(minimumVersion)")
    if let selectedProfileName {
        print("Chrome build profile: \(selectedProfileName)")
    }
    print("Mode: read-only; no changes made.")
    print("Overall result: \(readiness.summary)")
}

switch CompatibilityResult(installed: installedVersion, minimum: minimumVersion) {
case .atOrAboveMinimum:
    if jsonArguments.isEmpty {
        print("Result: This Mac's macOS version meets the specified minimum.")
    }
    exit(0)
case .belowMinimum:
    if jsonArguments.isEmpty {
        print("Result: This Mac's macOS version is below the specified minimum.")
    }
    exit(1)
}
#else
fputs("ChromePatcher's compatibility checker can only run on macOS.\n", stderr)
exit(2)
#endif
