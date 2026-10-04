import Foundation
import XCTest
@testable import ChromePatcherCore

final class CompatibilityReportTests: XCTestCase {
    func testJSONReportIncludesStableMachineReadableFields() throws {
        let chrome = ChromeInstallation(
            version: "126.0.6478.127",
            appURL: URL(fileURLWithPath: "/Applications/Google Chrome.app"),
            architectures: [.arm64, .x86_64]
        )
        let report = CompatibilityReport(
            installedMacOS: MacOSVersion(major: 12, minor: 0, patch: 1),
            minimumMacOS: MacOSVersion(major: 12, minor: 0),
            modelIdentifier: "Mac14,7",
            hostArchitecture: .arm64,
            chromeInstallation: chrome
        )

        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(CompatibilityReport.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.macOSVersion, "12.0.1")
        XCTAssertEqual(decoded.minimumMacOSVersion, "12.0")
        XCTAssertTrue(decoded.meetsMinimumMacOS)
        XCTAssertEqual(decoded.macModelIdentifier, "Mac14,7")
        XCTAssertEqual(decoded.macArchitecture, "arm64")
        XCTAssertTrue(decoded.chromeInstalled)
        XCTAssertEqual(decoded.chromeVersion, "126.0.6478.127")
        XCTAssertEqual(decoded.chromePath, "/Applications/Google Chrome.app")
        XCTAssertEqual(decoded.chromeArchitectures, ["arm64", "x86_64"])
        XCTAssertEqual(decoded.nativeArchitectureAvailable, true)
        XCTAssertEqual(decoded.readiness, "ready")
        XCTAssertTrue(decoded.readOnly)
    }

    func testJSONReportRepresentsMissingChromeWithNullDetails() throws {
        let report = CompatibilityReport(
            installedMacOS: MacOSVersion(major: 11, minor: 7),
            minimumMacOS: MacOSVersion(major: 12, minor: 0),
            modelIdentifier: "MacBookAir7,2",
            hostArchitecture: .x86_64,
            chromeInstallation: nil
        )

        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(CompatibilityReport.self, from: data)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertFalse(decoded.chromeInstalled)
        XCTAssertNil(decoded.chromeVersion)
        XCTAssertNil(decoded.chromePath)
        XCTAssertNil(decoded.chromeArchitectures)
        XCTAssertNil(decoded.nativeArchitectureAvailable)
        XCTAssertEqual(decoded.readiness, "chrome_not_installed")
        XCTAssertFalse(decoded.meetsMinimumMacOS)
        XCTAssertTrue(object["chromeVersion"] is NSNull)
        XCTAssertTrue(object["chromeArchitectures"] is NSNull)
        XCTAssertTrue(object["nativeArchitectureAvailable"] is NSNull)
    }
}
