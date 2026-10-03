import ChromePatcherCore
import Darwin
import Foundation

private let usage = """
Usage: ChromePatcher --minimum-macos VERSION

Detect Google Chrome and compare this Mac's macOS version with a Chrome build's minimum.
VERSION must be numeric, for example 12.0 or 10.15.7.
Chrome is searched for in /Applications and ~/Applications.
This checker is read-only; it does not modify macOS or Chrome.
"""

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments == ["--help"] || arguments == ["-h"] {
    print(usage)
    exit(0)
}

guard arguments.count == 2, arguments[0] == "--minimum-macos" else {
    fputs("\(usage)\n", stderr)
    exit(2)
}

guard let minimumVersion = MacOSVersion(arguments[1]) else {
    fputs("Invalid minimum macOS version: \(arguments[1])\n", stderr)
    fputs("\(usage)\n", stderr)
    exit(2)
}

#if os(macOS)
let systemVersion = ProcessInfo.processInfo.operatingSystemVersion
let installedVersion = MacOSVersion(
    major: systemVersion.majorVersion,
    minor: systemVersion.minorVersion,
    patch: systemVersion.patchVersion
)

let chromeInstallation: ChromeInstallation?
do {
    chromeInstallation = try ChromeDetector.detect(
        in: ChromeDetector.defaultApplicationDirectories
    )
} catch {
    fputs("Could not inspect Google Chrome: \(error.localizedDescription)\n", stderr)
    exit(2)
}

print("Detected: \(installedVersion.displayName)")
if let chromeInstallation {
    print("Google Chrome: version \(chromeInstallation.version)")
    print("Location: \(chromeInstallation.appURL.path)")
} else {
    print("Google Chrome: not found in /Applications or ~/Applications")
}
print("Chrome build minimum: macOS \(minimumVersion)")
print("Mode: read-only; no changes made.")

switch CompatibilityResult(installed: installedVersion, minimum: minimumVersion) {
case .atOrAboveMinimum:
    print("Result: This Mac meets the specified minimum.")
    exit(0)
case .belowMinimum:
    print("Result: This Mac is below the specified minimum.")
    exit(1)
}
#else
fputs("ChromePatcher's compatibility checker can only run on macOS.\n", stderr)
exit(2)
#endif
