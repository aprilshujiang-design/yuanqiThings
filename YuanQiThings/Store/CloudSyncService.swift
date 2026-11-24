import CloudKit
import Foundation

actor CloudSyncService {
    static let shared = CloudSyncService()

    private let container = CKContainer(identifier: "iCloud.com.april.smallwins")
    private let recordID = CKRecord.ID(recordName: "primary-energy-data")
    private let recordType = "EnergyBackup"

    enum SyncError: LocalizedError {
        case unavailable(CKAccountStatus)
        case invalidPayload

        var errorDescription: String? {
            switch self {
            case .unavailable(.noAccount):
                return String(localized: "设备尚未登录 iCloud")
            case .unavailable(.restricted):
                return String(localized: "iCloud 访问受到系统限制")
            case .unavailable:
                return String(localized: "iCloud 账户暂不可用")
            case .invalidPayload:
                return String(localized: "本地数据无法读取")
            }
        }
    }

    func accountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }

    func download() async throws -> Data? {
        let database = container.privateCloudDatabase
        do {
            let record = try await withRetry { try await database.record(for: recordID) }
            guard let asset = record["payload"] as? CKAsset,
                  let fileURL = asset.fileURL else { return nil }
            return try Data(contentsOf: fileURL)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    func mergeAndUpload(_ data: Data) async throws -> Data {
        let status = try await withRetry { try await self.accountStatus() }
        guard status == .available else { throw SyncError.unavailable(status) }
        guard let local = try? JSONDecoder().decode(PersistedEnergyData.self, from: data) else {
            throw SyncError.invalidPayload
        }

        let database = container.privateCloudDatabase
        var candidate = local

        for _ in 0..<3 {
            var record: CKRecord
            do {
                record = try await withRetry { try await database.record(for: self.recordID) }
                if let remoteData = try readPayload(from: record),
                   let remote = try? JSONDecoder().decode(PersistedEnergyData.self, from: remoteData) {
                    candidate = .merged(candidate, remote)
                }
            } catch let error as CKError where error.code == .unknownItem {
                record = CKRecord(recordType: recordType, recordID: recordID)
            }

            let candidateData = try JSONEncoder().encode(candidate)
            do {
                try await withRetry { try await self.save(candidateData, to: record, in: database) }
                return candidateData
            } catch let error as CKError where error.code == .serverRecordChanged {
                if let serverRecord = error.serverRecord,
                   let remoteData = try readPayload(from: serverRecord),
                   let remote = try? JSONDecoder().decode(PersistedEnergyData.self, from: remoteData) {
                    candidate = .merged(candidate, remote)
                    continue
                }
                throw error
            }
        }
        throw CKError(.serverRecordChanged)
    }

    private func readPayload(from record: CKRecord) throws -> Data? {
        guard let asset = record["payload"] as? CKAsset,
              let fileURL = asset.fileURL else { return nil }
        return try Data(contentsOf: fileURL)
    }

    private func save(_ data: Data, to record: CKRecord, in database: CKDatabase) async throws {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("yuanqi-cloud-\(UUID().uuidString).json")
        try data.write(to: temporaryURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        record["payload"] = CKAsset(fileURL: temporaryURL)
        _ = try await database.save(record)
    }

    private func withRetry<T>(_ operation: () async throws -> T) async throws -> T {
        var attempt = 0
        while true {
            do {
                return try await operation()
            } catch let error as CKError where error.isTransient && attempt < 2 {
                attempt += 1
                let suggestedDelay = error.userInfo[CKErrorRetryAfterKey] as? TimeInterval
                let delay = min(max(suggestedDelay ?? pow(2, Double(attempt)), 0.5), 12)
                try await Task.sleep(for: .seconds(delay))
            }
        }
    }
}

private extension CKError {
    var isTransient: Bool {
        switch code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited,
             .zoneBusy, .resultsTruncated:
            return true
        default:
            return false
        }
    }
}
