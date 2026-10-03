import Foundation
import XCTest
@testable import ChromePatcherCore

final class ChromeDetectorTests: XCTestCase {
    func testDetectsChromeUsingItsProductVersion() throws {
        let applications = try makeApplicationsDirectory(
            metadata: [
                "CFBundleIdentifier": "com.google.Chrome",
                "KSVersion": "126.0.6478.127",
                "CFBundleShortVersionString": "126.0"
            ]
        )
        defer { try? FileManager.default.removeItem(at: applications) }

        let installation = try XCTUnwrap(ChromeDetector.detect(in: [applications]))
        XCTAssertEqual(installation.version, "126.0.6478.127")
        XCTAssertEqual(installation.appURL.lastPathComponent, "Google Chrome.app")
    }

    func testFallsBackToShortVersionWhenProductVersionIsMissing() throws {
        let applications = try makeApplicationsDirectory(
            metadata: [
                "CFBundleIdentifier": "com.google.Chrome",
                "CFBundleShortVersionString": "126.0"
            ]
        )
        defer { try? FileManager.default.removeItem(at: applications) }

        let installation = try XCTUnwrap(ChromeDetector.detect(in: [applications]))
        XCTAssertEqual(installation.version, "126.0")
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
}
