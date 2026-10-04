import Foundation
import XCTest
@testable import ChromePatcherCore

final class ChromeBuildProfilesTests: XCTestCase {
    func testLoadsNamedProfilesAndSortsNames() throws {
        let url = try writeProfiles([
            "chrome-beta": ChromeBuildProfile(minimumMacOS: "12.0", description: "Beta"),
            "chrome-stable": ChromeBuildProfile(minimumMacOS: "10.15.7")
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        let profiles = try ChromeBuildProfiles.load(from: url)
        XCTAssertEqual(profiles.names, ["chrome-beta", "chrome-stable"])
        XCTAssertEqual(
            try profiles.minimumMacOSVersion(for: "chrome-stable"),
            MacOSVersion(major: 10, minor: 15, patch: 7)
        )
        XCTAssertEqual(profiles.profile(named: "chrome-beta")?.description, "Beta")
    }

    func testRejectsProfilesWithInvalidMinimumVersion() throws {
        let url = try writeProfiles([
            "invalid": ChromeBuildProfile(minimumMacOS: "twelve")
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try ChromeBuildProfiles.load(from: url))
    }

    func testRejectsMalformedProfilesFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try Data("{invalid".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try ChromeBuildProfiles.load(from: url))
    }

    func testReportsUnknownProfileName() throws {
        let url = try writeProfiles([
            "chrome-beta": ChromeBuildProfile(minimumMacOS: "12.0")
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try ChromeBuildProfiles.load(from: url).minimumMacOSVersion(for: "missing"))
    }

    func testGeneratesProfileTemplateJSON() throws {
        let json = ChromeBuildProfiles.templateJSON(
            profileName: "chrome-126",
            minimumMacOS: "10.15.7",
            description: "Example profile"
        )

        guard let data = json.data(using: .utf8) else {
            XCTFail("Template JSON should be UTF-8 encoded")
            return
        }

        let decoded = try JSONDecoder().decode(ChromeBuildProfileFile.self, from: data)
        XCTAssertEqual(decoded.profiles["chrome-126"]?.minimumMacOS, "10.15.7")
        XCTAssertEqual(decoded.profiles["chrome-126"]?.description, "Example profile")
    }

    private func writeProfiles(_ profiles: [String: ChromeBuildProfile]) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let data = try JSONEncoder().encode(ChromeBuildProfileFile(profiles: profiles))
        try data.write(to: url)
        return url
    }
}
