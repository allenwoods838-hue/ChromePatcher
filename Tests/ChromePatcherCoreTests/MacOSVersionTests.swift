import XCTest
@testable import ChromePatcherCore

final class MacOSVersionTests: XCTestCase {
    func testParsesTwoAndThreeComponentVersions() {
        XCTAssertEqual(MacOSVersion("12.0"), MacOSVersion(major: 12, minor: 0))
        XCTAssertEqual(MacOSVersion("10.15.7"), MacOSVersion(major: 10, minor: 15, patch: 7))
    }

    func testRejectsMalformedVersions() {
        for value in ["12", "v12.0", "12.-1", "12.0.0.1", "12..1", ""] {
            XCTAssertNil(MacOSVersion(value), "Expected \(value) to be rejected")
        }
    }

    func testComparesVersionsNumerically() {
        XCTAssertLessThan(MacOSVersion(major: 11, minor: 7, patch: 10), MacOSVersion(major: 12, minor: 0))
        XCTAssertGreaterThan(MacOSVersion(major: 12, minor: 0, patch: 1), MacOSVersion(major: 12, minor: 0))
    }

    func testClassifiesAgainstTheProvidedMinimum() {
        XCTAssertEqual(
            CompatibilityResult(installed: MacOSVersion(major: 11, minor: 7), minimum: MacOSVersion(major: 12, minor: 0)),
            .belowMinimum
        )
        XCTAssertEqual(
            CompatibilityResult(installed: MacOSVersion(major: 12, minor: 0), minimum: MacOSVersion(major: 12, minor: 0)),
            .atOrAboveMinimum
        )
    }

    func testNamesTargetMacOSReleases() {
        XCTAssertEqual(MacOSVersion(major: 10, minor: 15).displayName, "macOS 10.15 (Catalina)")
        XCTAssertEqual(MacOSVersion(major: 11, minor: 7).displayName, "macOS 11.7 (Big Sur)")
        XCTAssertEqual(MacOSVersion(major: 12, minor: 0).displayName, "macOS 12.0 (Monterey)")
    }
}
