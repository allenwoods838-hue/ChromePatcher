import Foundation
import XCTest
@testable import ChromePatcherCore

final class BinaryArchitectureTests: XCTestCase {
    func testReadsThinArm64AndX86_64Executables() throws {
        XCTAssertEqual(try read(architecture: 0x0100000c), [.arm64])
        XCTAssertEqual(try read(architecture: 0x01000007), [.x86_64])
    }

    func testReadsUniversalExecutable() throws {
        var bytes: [UInt8] = [0xca, 0xfe, 0xba, 0xbe, 0, 0, 0, 2]
        bytes += bigEndian(0x01000007) + Array(repeating: 0, count: 16)
        bytes += bigEndian(0x0100000c) + Array(repeating: 0, count: 16)
        XCTAssertEqual(try read(bytes: bytes), [.arm64, .x86_64])
    }

    func testRejectsInvalidMachOHeader() throws {
        XCTAssertThrowsError(try read(bytes: [0, 1, 2, 3, 4, 5, 6, 7]))
        XCTAssertThrowsError(try read(bytes: [0xca, 0xfe, 0xba, 0xbe, 0, 0, 0, 2]))
    }

    private func read(architecture: UInt32) throws -> Set<BinaryArchitecture> {
        var bytes: [UInt8] = [0xcf, 0xfa, 0xed, 0xfe]
        bytes += (0..<4).map { UInt8((architecture >> ($0 * 8)) & 0xff) }
        return try read(bytes: bytes)
    }

    private func read(bytes: [UInt8]) throws -> Set<BinaryArchitecture> {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try Data(bytes).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        return try MachOArchitectures.read(from: url)
    }

    private func bigEndian(_ value: UInt32) -> [UInt8] {
        (0..<4).map { UInt8((value >> ((3 - $0) * 8)) & 0xff) }
    }
}
