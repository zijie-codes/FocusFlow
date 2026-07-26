import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct JSONBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data("{}".utf8)) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw BackupError.unreadableFile
        }
        data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct BackupEnvelope<Payload: Codable>: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let appVersion: String
    let payload: Payload
}

enum BackupError: LocalizedError {
    case unreadableFile
    case emptyBackup
    case unsupportedSchema(found: Int, supported: Int)
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            return "无法读取所选备份文件。"
        case .emptyBackup:
            return "备份文件不包含可导入的数据。"
        case let .unsupportedSchema(found, supported):
            return "备份版本 \(found) 暂不支持（当前支持至 \(supported)）。"
        case .invalidJSON:
            return "备份文件不是有效的 FocusFlow JSON。"
        }
    }
}

/// 将持久化层提供的 Codable 快照包装成带版本信息的 JSON FileDocument。
/// 具体 Core Data 对象应先映射为值类型 DTO，再交给该服务编码。
final class BackupService {
    static let currentSchemaVersion = 1

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func makeDocument<Payload: Codable>(from payload: Payload) throws -> JSONBackupDocument {
        let envelope = BackupEnvelope(
            schemaVersion: Self.currentSchemaVersion,
            exportedAt: Date(),
            appVersion: Self.appVersion,
            payload: payload
        )
        return JSONBackupDocument(data: try encoder.encode(envelope))
    }

    func exportData<Payload: Codable>(from payload: Payload) throws -> Data {
        try makeDocument(from: payload).data
    }

    func decode<Payload: Codable>(
        _ type: Payload.Type,
        from document: JSONBackupDocument
    ) throws -> Payload {
        try decode(type, from: document.data)
    }

    func decode<Payload: Codable>(_ type: Payload.Type, from data: Data) throws -> Payload {
        guard !data.isEmpty else { throw BackupError.emptyBackup }

        do {
            let envelope = try decoder.decode(BackupEnvelope<Payload>.self, from: data)
            guard envelope.schemaVersion <= Self.currentSchemaVersion else {
                throw BackupError.unsupportedSchema(
                    found: envelope.schemaVersion,
                    supported: Self.currentSchemaVersion
                )
            }
            return envelope.payload
        } catch let error as BackupError {
            throw error
        } catch {
            throw BackupError.invalidJSON
        }
    }

    func suggestedFilename(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "FocusFlow-备份-\(formatter.string(from: date))"
    }

    private static var appVersion: String {
        let shortVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String
        return shortVersion ?? "1.0"
    }
}
