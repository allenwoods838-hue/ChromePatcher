import Foundation
import XCTest
@testable import ChromePatcherCore

final class ChromeDetectorTests: XCTestCase {
    func testDetectsChromeUsingItsProductVersion() throws {
        let applications = try makeApplicationsDirectory(
            metadata: [
                "CFBundleIdentifier": "com.google.Chrome",
                "KSVersion": "126.0.6478.127",
                "CFBundleShortVersionString": "126.0",
                "CFBundleExecutable": "Google Chrome"
            ]
        )
        try writeExecutable(architecture: .x86_64, in: applications)
        defer { try? FileManager.default.removeItem(at: applications) }

        let installation = try XCTUnwrap(ChromeDetector.detect(in: [applications]))
        XCTAssertEqual(installation.version, "126.0.6478.127")
        XCTAssertEqual(installation.appURL.lastPathComponent, "Google Chrome.app")
        XCTAssertEqual(installation.architectures, [.x86_64])
    }

    func testFallsBackToShortVersionWhenProductVersionIsMissing() throws {
        let applications = try makeApplicationsDirectory(
            metadata: [
                "CFBundleIdentifier": "com.google.Chrome",
                "CFBundleShortVersionString": "126.0",
                "CFBundleExecutable": "Google Chrome"
            ]
        )
        try writeExecutable(architecture: .arm64, in: applications)
        defer { try? FileManager.default.removeItem(at: applications) }

        let installation = try XCTUnwrap(ChromeDetector.detect(in: [applications]))
        XCTAssertEqual(installation.version, "126.0")
        XCTAssertEqual(installation.architectures, [.arm64])
    }

    func testReturnsNilWhenChromeIsNotInstalled() throws {
        let applications = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: applications, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: applications) }

        XCTAssertNil(try ChromeDetector.detect(in: [applications]))
    }

    private func makeApplicationsDirectory(metadata: [String: Any]) throws -> URL {
        let applications = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let infoURL = applications
            .appendingPathComponent("Google Chrome.app/Contents/Info.plist")
        try FileManager.default.createDirectory(
            at: infoURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try PropertyListSerialization.data(
            fromPropertyList: metadata,
            format: .xml,
            options: 0
        )
        try data.write(to: infoURL)
        return applications
    }

    private func writeExecutable(architecture: BinaryArchitecture, in applications: URL) throws {
        let executableURL = applications
            .appendingPathComponent("Google Chrome.app/Contents/MacOS/Google Chrome")
        let cpuType: UInt32 = architecture == .arm64 ? 0x0100000c : 0x01000007
        var bytes: [UInt8] = [0xcf, 0xfa, 0xed, 0xfe]
        bytes += (0..<4).map { UInt8((cpuType >> ($0 * 8)) & 0xff) }
        try Data(bytes).write(to: executableURL)
    }
}
