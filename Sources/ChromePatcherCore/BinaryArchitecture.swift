import Darwin
import Foundation

public enum BinaryArchitecture: Hashable, CustomStringConvertible {
    case arm64
    case x86_64
    case other(Int32)

    public var description: String {
        switch self {
        case .arm64: "arm64"
        case .x86_64: "x86_64"
        case .other(let cpuType): "other(\(String(cpuType, radix: 16)))"
        }
    }

    public static var host: BinaryArchitecture? {
        var supportsARM64: Int32 = 0
        var valueSize = MemoryLayout<Int32>.size
        if sysctlbyname("hw.optional.arm64", &supportsARM64, &valueSize, nil, 0) == 0 {
            return supportsARM64 == 1 ? .arm64 : .x86_64
        }

        var systemInfo = utsname()
        guard uname(&systemInfo) == 0 else {
            return nil
        }

        let machineSize = MemoryLayout.size(ofValue: systemInfo.machine)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: machineSize) {
                String(cString: $0)
            }
        }

        return switch machine {
        case "arm64": .arm64
        case "x86_64": .x86_64
        default: nil
        }
    }

    fileprivate init(cpuType: Int32) {
        switch cpuType {
        case 0x0100000c: self = .arm64
        case 0x01000007: self = .x86_64
        default: self = .other(cpuType)
        }
    }
}

public enum MachOArchitectures {
    public enum ReadError: Swift.Error {
        case unreadable
        case invalid
    }

    public static func read(from url: URL) throws -> Set<BinaryArchitecture> {
        let file: FileHandle
        do {
            file = try FileHandle(forReadingFrom: url)
        } catch {
            throw ReadError.unreadable
        }
        defer { try? file.close() }

        let header = file.readData(ofLength: 8)
        guard header.count == 8 else {
            throw ReadError.invalid
        }

        let magic = uint32(in: header, at: 0, littleEndian: false)
        switch magic {
        case 0xfeedface, 0xfeedfacf:
            return [BinaryArchitecture(cpuType: Int32(bitPattern: uint32(in: header, at: 4, littleEndian: false)))]
        case 0xcefaedfe, 0xcffaedfe:
            return [BinaryArchitecture(cpuType: Int32(bitPattern: uint32(in: header, at: 4, littleEndian: true)))]
        case 0xcafebabe, 0xcafebabf:
            return try readFatArchitectures(from: file, header: header, littleEndian: false)
        case 0xbebafeca, 0xbfbafeca:
            return try readFatArchitectures(from: file, header: header, littleEndian: true)
        default:
            throw ReadError.invalid
        }
    }

    private static func readFatArchitectures(
        from file: FileHandle,
        header: Data,
        littleEndian: Bool
    ) throws -> Set<BinaryArchitecture> {
        let is64Bit = uint32(in: header, at: 0, littleEndian: false) == 0xcafebabf
            || uint32(in: header, at: 0, littleEndian: false) == 0xbfbafeca
        let count = Int(uint32(in: header, at: 4, littleEndian: littleEndian))
        let recordSize = is64Bit ? 32 : 20
        guard (1...128).contains(count) else {
            throw ReadError.invalid
        }

        let records = file.readData(ofLength: count * recordSize)
        guard records.count == count * recordSize else {
            throw ReadError.invalid
        }

        return Set((0..<count).map { index in
            let offset = index * recordSize
            return BinaryArchitecture(
                cpuType: Int32(bitPattern: uint32(in: records, at: offset, littleEndian: littleEndian))
            )
        })
    }

    private static func uint32(in data: Data, at offset: Int, littleEndian: Bool) -> UInt32 {
        let bytes = (0..<4).map { UInt32(data[offset + $0]) }
        if littleEndian {
            return bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24)
        }
        return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]
    }
}
