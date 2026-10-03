import ChromePatcherCore
import Darwin
import Foundation

private let usage = """
Usage: ChromePatcher --minimum-macos VERSION

Compare this Mac's macOS version with the minimum required by a Chrome build.
VERSION must be numeric, for example 12.0 or 10.15.7.
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

print("Detected: \(installedVersion.displayName)")
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
