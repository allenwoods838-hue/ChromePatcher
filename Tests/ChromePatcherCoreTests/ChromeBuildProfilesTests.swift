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
        let json = try ChromeBuildProfiles.templateJSON(
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

    func testWritesTemplateFileToDisk() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }

        try ChromeBuildProfiles.writeTemplate(to: url, profileName: "chrome-126")
        let profiles = try ChromeBuildProfiles.load(from: url)

        XCTAssertEqual(profiles.names, ["chrome-126"])
        XCTAssertEqual(try profiles.minimumMacOSVersion(for: "chrome-126"), MacOSVersion(major: 12, minor: 0))
    }

    func testAddsUpdatesAndRemovesProfilesWithoutLosingOthers() throws {
        let url = try writeProfiles([
            "existing": ChromeBuildProfile(minimumMacOS: "11.0", description: "Keep me")
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        try ChromeBuildProfiles.load(from: url).addProfile(
            named: "new-build",
            profile: ChromeBuildProfile(minimumMacOS: "12.0", description: "New profile")
        )
        try ChromeBuildProfiles.load(from: url).updateProfile(
            named: "new-build",
            minimumMacOS: "13.0"
        )

        let afterUpdate = try ChromeBuildProfiles.load(from: url)
        XCTAssertEqual(afterUpdate.names, ["existing", "new-build"])
        XCTAssertEqual(afterUpdate.profile(named: "existing")?.description, "Keep me")
        XCTAssertEqual(afterUpdate.profile(named: "new-build")?.minimumMacOS, "13.0")
        XCTAssertEqual(afterUpdate.profile(named: "new-build")?.description, "New profile")

        try afterUpdate.removeProfile(named: "new-build")
        XCTAssertEqual(try ChromeBuildProfiles.load(from: url).names, ["existing"])
    }

    func testAddingExistingProfileFailsWithoutChangingFile() throws {
        let url = try writeProfiles([
            "existing": ChromeBuildProfile(minimumMacOS: "11.0")
        ])
        defer { try? FileManager.default.removeItem(at: url) }
        let originalData = try Data(contentsOf: url)

        XCTAssertThrowsError(
            try ChromeBuildProfiles.load(from: url).addProfile(
                named: "existing",
                profile: ChromeBuildProfile(minimumMacOS: "12.0")
            )
        )
        XCTAssertEqual(try Data(contentsOf: url), originalData)
    }

    func testProfileComparisonReportsWhichMinimumIsNewer() throws {
        let first = ChromeBuildProfileSummary(
            name: "older-build",
            profile: ChromeBuildProfile(minimumMacOS: "12.0", description: "Monterey")
        )
        let second = ChromeBuildProfileSummary(
            name: "newer-build",
            profile: ChromeBuildProfile(minimumMacOS: "13.0")
        )

        let comparison = try ChromeBuildProfileComparison(first: first, second: second)

        XCTAssertEqual(comparison.minimumVersionRelation, .secondRequiresNewer)
        XCTAssertEqual(comparison.first.description, "Monterey")
    }

    func testProfileComparisonTreatsEquivalentVersionFormatsAsSame() throws {
        let first = ChromeBuildProfileSummary(
            name: "build-one",
            profile: ChromeBuildProfile(minimumMacOS: "12.0")
        )
        let second = ChromeBuildProfileSummary(
            name: "build-two",
            profile: ChromeBuildProfile(minimumMacOS: "12.0.0")
        )

        XCTAssertEqual(
            try ChromeBuildProfileComparison(first: first, second: second).minimumVersionRelation,
            .same
        )
    }

    private func writeProfiles(_ profiles: [String: ChromeBuildProfile]) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let data = try JSONEncoder().encode(ChromeBuildProfileFile(profiles: profiles))
        try data.write(to: url)
        return url
    }
}
