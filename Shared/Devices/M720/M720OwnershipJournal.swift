import Foundation
import Darwin

/// Swift cannot import C's variadic `open(2)` safely, so bind its fixed
/// O_CREAT form. Passing a mode when O_CREAT is absent is permitted by POSIX.
@_silgen_name("open")
private func m720POSIXOpen(
    _ path: UnsafePointer<CChar>,
    _ flags: Int32,
    _ mode: mode_t
) -> Int32

struct M720DeviceKey: Codable, Equatable, Hashable {
    let vendorID: Int
    let productID: Int
    let transport: String
    let serialNumber: String
}

enum M720JournalPhase: String, Codable, Equatable {
    case prepared
    case applied
    case restoring
}

struct M720JournalCIDEntry: Codable, Equatable {
    let cid: UInt16
    let original: HIDPPReportingState
    let intended: HIDPPReportingState
    var phase: M720JournalPhase
}

struct M720JournalDevice: Codable, Equatable {
    let key: M720DeviceKey
    var controls: [M720JournalCIDEntry]
}

struct M720OwnershipJournal: Codable, Equatable {
    static let currentVersion = 1
    static let emptyV1 = M720OwnershipJournal(version: currentVersion, devices: [])

    let version: Int
    var devices: [M720JournalDevice]

    func validatedCanonicalized() throws -> M720OwnershipJournal {
        guard version == Self.currentVersion else {
            throw M720JournalValidationError.unsupportedVersion(version)
        }

        var seenDevices = Set<M720DeviceKey>()
        for device in devices {
            guard (0...Int(UInt16.max)).contains(device.key.vendorID) else {
                throw M720JournalValidationError.identifierOutOfRange
            }
            guard (0...Int(UInt16.max)).contains(device.key.productID) else {
                throw M720JournalValidationError.identifierOutOfRange
            }
            guard !device.key.transport.isEmpty else {
                throw M720JournalValidationError.emptyTransport
            }
            guard !device.key.serialNumber.isEmpty else {
                throw M720JournalValidationError.emptySerialNumber
            }
            guard seenDevices.insert(device.key).inserted else {
                throw M720JournalValidationError.duplicateDeviceKey
            }
            guard !device.controls.isEmpty else {
                throw M720JournalValidationError.emptyControls
            }

            var seenCIDs = Set<UInt16>()
            for entry in device.controls {
                guard seenCIDs.insert(entry.cid).inserted else {
                    throw M720JournalValidationError.duplicateCID(entry.cid)
                }
                guard M720Profile.cidToButton[entry.cid] != nil else {
                    throw M720JournalValidationError.unsupportedCID(entry.cid)
                }
                guard entry.original.cid == entry.cid, entry.intended.cid == entry.cid else {
                    throw M720JournalValidationError.mismatchedCID(entry.cid)
                }
                guard !entry.original.isDiverted else {
                    throw M720JournalValidationError.originalIsDiverted(entry.cid)
                }
                let exactIntended = entry.original.changingDivert(to: true)
                guard entry.intended != entry.original, entry.intended == exactIntended else {
                    throw M720JournalValidationError.invalidIntendedState(entry.cid)
                }
            }
        }

        var canonical = self
        canonical.devices.sort { lhs, rhs in
            lhs.key.isOrderedBefore(rhs.key)
        }
        for index in canonical.devices.indices {
            canonical.devices[index].controls.sort { $0.cid < $1.cid }
        }
        return canonical
    }
}

enum M720JournalValidationError: Error, Equatable {
    case unsupportedVersion(Int)
    case identifierOutOfRange
    case emptyTransport
    case emptySerialNumber
    case duplicateDeviceKey
    case emptyControls
    case duplicateCID(UInt16)
    case unsupportedCID(UInt16)
    case mismatchedCID(UInt16)
    case originalIsDiverted(UInt16)
    case invalidIntendedState(UInt16)
}

private extension M720DeviceKey {
    func isOrderedBefore(_ other: M720DeviceKey) -> Bool {
        if vendorID != other.vendorID { return vendorID < other.vendorID }
        if productID != other.productID { return productID < other.productID }
        if transport != other.transport { return transport < other.transport }
        return serialNumber < other.serialNumber
    }
}

final class M720JournalCommitPermission {
    private let lock = NSLock()
    private var isOpen = true

    func check() throws {
        lock.lock()
        defer { lock.unlock() }
        guard isOpen else {
            throw M720JournalRepositoryError.mutationFenced
        }
    }

    func performCommit<T>(_ commit: () throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        guard isOpen else {
            throw M720JournalRepositoryError.mutationFenced
        }
        return try commit()
    }

    func close() {
        lock.lock()
        isOpen = false
        lock.unlock()
    }
}

protocol M720JournalStoring: AnyObject {
    func load() throws -> M720OwnershipJournal
    func save(
        _ journal: M720OwnershipJournal,
        commitPermission: M720JournalCommitPermission
    ) throws
    @discardableResult
    func acknowledgeQuarantineWithFreshEmptyV1(
        commitPermission: M720JournalCommitPermission
    ) throws -> M720OwnershipJournal
}

extension M720JournalStoring {
    func save(_ journal: M720OwnershipJournal) throws {
        try save(journal, commitPermission: M720JournalCommitPermission())
    }

    @discardableResult
    func acknowledgeQuarantineWithFreshEmptyV1() throws -> M720OwnershipJournal {
        try acknowledgeQuarantineWithFreshEmptyV1(
            commitPermission: M720JournalCommitPermission()
        )
    }
}

enum M720JournalStoreError: Error, Equatable {
    case quarantined
    case corruptFileQuarantined
    case notQuarantined
    case uncertain
}

struct M720JournalStoreFaults {
    var renameError: POSIXErrorCode?
    var directorySyncError: POSIXErrorCode?

    init(
        renameError: POSIXErrorCode? = nil,
        directorySyncError: POSIXErrorCode? = nil
    ) {
        self.renameError = renameError
        self.directorySyncError = directorySyncError
    }
}

final class M720OwnershipJournalStore: M720JournalStoring {
    static let fileName = "M720HIDPPOwnership-v1.plist"
    static var productionURL: URL {
        Locator.mfApplicationSupportFolderURL().appendingPathComponent(fileName, isDirectory: false)
    }

    private let finalURL: URL
    private let faults: M720JournalStoreFaults
    private let lock = NSLock()

    convenience init() {
        self.init(url: Self.productionURL)
    }

    init(
        url: URL,
        faults: M720JournalStoreFaults = M720JournalStoreFaults()
    ) {
        precondition(url.isFileURL)
        finalURL = url
        self.faults = faults
    }

    func load() throws -> M720OwnershipJournal {
        try withLock {
            guard try nodeExists(at: finalURL) else {
                guard try matchingCorruptSiblings().isEmpty else {
                    throw M720JournalStoreError.quarantined
                }
                return .emptyV1
            }

            let data = try Data(contentsOf: finalURL)
            let decoded: M720OwnershipJournal
            do {
                decoded = try PropertyListDecoder().decode(M720OwnershipJournal.self, from: data)
            } catch {
                try quarantineCorruptFinalAndReport()
            }

            do {
                return try decoded.validatedCanonicalized()
            } catch is M720JournalValidationError {
                try quarantineCorruptFinalAndReport()
            }
        }
    }

    func save(
        _ journal: M720OwnershipJournal,
        commitPermission: M720JournalCommitPermission
    ) throws {
        try withLock {
            let canonical = try journal.validatedCanonicalized()
            if try !nodeExists(at: finalURL), try !matchingCorruptSiblings().isEmpty {
                throw M720JournalStoreError.quarantined
            }
            try atomicSave(canonical, commitPermission: commitPermission)
        }
    }

    @discardableResult
    func acknowledgeQuarantineWithFreshEmptyV1(
        commitPermission: M720JournalCommitPermission
    ) throws -> M720OwnershipJournal {
        try withLock {
            guard try !nodeExists(at: finalURL), try !matchingCorruptSiblings().isEmpty else {
                throw M720JournalStoreError.notQuarantined
            }
            try atomicSave(.emptyV1, commitPermission: commitPermission)
            return .emptyV1
        }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }

    private func matchingCorruptSiblings() throws -> [URL] {
        let parentURL = finalURL.deletingLastPathComponent()
        guard try nodeExists(at: parentURL) else { return [] }
        return try FileManager.default.contentsOfDirectory(
            at: parentURL,
            includingPropertiesForKeys: nil,
            options: []
        ).filter { url in
            url.lastPathComponent.hasPrefix(finalURL.lastPathComponent + ".") &&
                url.lastPathComponent.hasSuffix(".corrupt")
        }
    }

    private func quarantineCorruptFinalAndReport() throws -> Never {
        let parentURL = finalURL.deletingLastPathComponent()
        let corruptURL = try uniqueCorruptURL()
        try rename(from: finalURL, to: corruptURL, exclusive: true)
        do {
            try synchronizeDirectory(parentURL)
        } catch {
            throw M720JournalStoreError.uncertain
        }
        throw M720JournalStoreError.corruptFileQuarantined
    }

    private func uniqueCorruptURL() throws -> URL {
        let milliseconds = Int64(Date().timeIntervalSince1970 * 1_000)
        let parentURL = finalURL.deletingLastPathComponent()
        while true {
            let name = finalURL.lastPathComponent + ".\(milliseconds)-\(UUID().uuidString).corrupt"
            let candidate = parentURL.appendingPathComponent(name, isDirectory: false)
            if try !nodeExists(at: candidate) {
                return candidate
            }
        }
    }

    private func atomicSave(
        _ journal: M720OwnershipJournal,
        commitPermission: M720JournalCommitPermission
    ) throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let data = try encoder.encode(journal)
        let parentURL = finalURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: parentURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let tempURL = parentURL.appendingPathComponent(
            ".\(finalURL.lastPathComponent).tmp.\(UUID().uuidString)",
            isDirectory: false
        )
        var descriptor: Int32 = -1
        var renamed = false
        defer {
            if descriptor >= 0 {
                _ = Darwin.close(descriptor)
            }
            if !renamed {
                try? FileManager.default.removeItem(at: tempURL)
            }
        }

        descriptor = try openExclusiveTemp(at: tempURL)
        try writeAll(data, to: descriptor)
        try synchronizeFile(descriptor)
        try closeFile(&descriptor)
        try commitPermission.performCommit {
            try rename(from: tempURL, to: finalURL)
            renamed = true
        }
        do {
            try synchronizeDirectory(parentURL)
        } catch {
            throw M720JournalStoreError.uncertain
        }
    }

    private func nodeExists(at url: URL) throws -> Bool {
        var metadata = stat()
        let result = url.withUnsafeFileSystemRepresentation { path in
            lstat(path, &metadata)
        }
        if result == 0 { return true }
        let code = errno
        if code == ENOENT { return false }
        throw posixError(code)
    }

    private func openExclusiveTemp(at url: URL) throws -> Int32 {
        let descriptor = url.withUnsafeFileSystemRepresentation { path in
            m720POSIXOpen(path!, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, S_IRUSR | S_IWUSR)
        }
        guard descriptor >= 0 else { throw posixError(errno) }
        if fchmod(descriptor, S_IRUSR | S_IWUSR) != 0 {
            let code = errno
            _ = Darwin.close(descriptor)
            throw posixError(code)
        }
        return descriptor
    }

    private func writeAll(_ data: Data, to descriptor: Int32) throws {
        try data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            var offset = 0
            while offset < rawBuffer.count {
                let written = Darwin.write(
                    descriptor,
                    baseAddress.advanced(by: offset),
                    rawBuffer.count - offset
                )
                if written > 0 {
                    offset += written
                } else if written < 0, errno == EINTR {
                    continue
                } else {
                    throw posixError(written == 0 ? EIO : errno)
                }
            }
        }
    }

    private func synchronizeFile(_ descriptor: Int32) throws {
        while fsync(descriptor) != 0 {
            if errno == EINTR { continue }
            throw posixError(errno)
        }
    }

    private func closeFile(_ descriptor: inout Int32) throws {
        let closingDescriptor = descriptor
        descriptor = -1
        guard Darwin.close(closingDescriptor) == 0 else {
            throw posixError(errno)
        }
    }

    private func rename(
        from sourceURL: URL,
        to destinationURL: URL,
        exclusive: Bool = false
    ) throws {
        if let injectedError = faults.renameError {
            throw POSIXError(injectedError)
        }
        let result = sourceURL.withUnsafeFileSystemRepresentation { sourcePath in
            destinationURL.withUnsafeFileSystemRepresentation { destinationPath in
                if exclusive {
                    return renamex_np(sourcePath, destinationPath, UInt32(RENAME_EXCL))
                }
                return Darwin.rename(sourcePath, destinationPath)
            }
        }
        guard result == 0 else { throw posixError(errno) }
    }

    private func synchronizeDirectory(_ url: URL) throws {
        if let injectedError = faults.directorySyncError {
            throw POSIXError(injectedError)
        }
        let descriptor = url.withUnsafeFileSystemRepresentation { path in
            m720POSIXOpen(path!, O_RDONLY | O_CLOEXEC, 0)
        }
        guard descriptor >= 0 else { throw posixError(errno) }
        var descriptorToClose = descriptor
        defer {
            if descriptorToClose >= 0 {
                _ = Darwin.close(descriptorToClose)
            }
        }
        try synchronizeFile(descriptor)
        try closeFile(&descriptorToClose)
    }

    private func posixError(_ code: Int32) -> POSIXError {
        POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
    }
}

enum M720JournalRepositoryError: Error, Equatable {
    case notLoaded
    case mismatchedCID
    case mismatchedDevice
    case mutationFenced
}

final class M720OwnershipJournalRepository {
    typealias Completion = (Result<M720OwnershipJournal, Error>) -> Void

    private enum SnapshotState {
        case neverLoaded
        case loaded(M720OwnershipJournal)
        case needsReloadAfterUncertain
    }

    static let shared = M720OwnershipJournalRepository(store: M720OwnershipJournalStore())

    private let store: M720JournalStoring
    private let queue: DispatchQueue
    private var snapshotState: SnapshotState = .neverLoaded

    init(
        store: M720JournalStoring,
        queueLabel: String = "com.nuebling.mac-mouse-fix.m720-ownership-journal"
    ) {
        self.store = store
        queue = DispatchQueue(label: queueLabel, qos: .utility)
    }

    func reload(completion: @escaping Completion) {
        queue.async {
            let wasWaitingForUncertainReload: Bool
            if case .needsReloadAfterUncertain = self.snapshotState {
                wasWaitingForUncertainReload = true
            } else {
                wasWaitingForUncertainReload = false
            }
            do {
                let loaded = try self.store.load()
                self.snapshotState = .loaded(loaded)
                completion(.success(loaded))
            } catch {
                if wasWaitingForUncertainReload || self.isStorageUncertain(error) {
                    self.snapshotState = .needsReloadAfterUncertain
                } else {
                    self.snapshotState = .neverLoaded
                }
                completion(.failure(error))
            }
        }
    }

    func snapshot(completion: @escaping Completion) {
        queue.async {
            do {
                completion(.success(try self.snapshotLoadingAfterUncertainIfNeeded()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func mutateCID(
        for key: M720DeviceKey,
        cid: UInt16,
        mutation: @escaping (M720JournalCIDEntry?) throws -> M720JournalCIDEntry?,
        completion: @escaping Completion
    ) {
        mutateCID(
            for: key,
            cid: cid,
            mutation: mutation,
            commitPermission: M720JournalCommitPermission(),
            completion: completion
        )
    }

    func mutateCID(
        for key: M720DeviceKey,
        cid: UInt16,
        mutation: @escaping (M720JournalCIDEntry?) throws -> M720JournalCIDEntry?,
        commitPermission: M720JournalCommitPermission,
        completion: @escaping Completion
    ) {
        queue.async {
            do {
                try commitPermission.check()
                var candidate = try self.snapshotLoadingAfterUncertainIfNeeded()
                let deviceIndex = candidate.devices.firstIndex { $0.key == key }
                let controlIndex = deviceIndex.flatMap { index in
                    candidate.devices[index].controls.firstIndex { $0.cid == cid }
                }
                let existing = deviceIndex.flatMap { deviceIndex in
                    controlIndex.map { candidate.devices[deviceIndex].controls[$0] }
                }
                let updated = try mutation(existing)
                try commitPermission.check()

                if let updated {
                    guard updated.cid == cid else {
                        throw M720JournalRepositoryError.mismatchedCID
                    }
                    if let deviceIndex {
                        if let controlIndex {
                            candidate.devices[deviceIndex].controls[controlIndex] = updated
                        } else {
                            candidate.devices[deviceIndex].controls.append(updated)
                        }
                    } else {
                        candidate.devices.append(M720JournalDevice(key: key, controls: [updated]))
                    }
                } else if let deviceIndex, let controlIndex {
                    candidate.devices[deviceIndex].controls.remove(at: controlIndex)
                    if candidate.devices[deviceIndex].controls.isEmpty {
                        candidate.devices.remove(at: deviceIndex)
                    }
                }

                let canonical = try candidate.validatedCanonicalized()
                try self.store.save(canonical, commitPermission: commitPermission)
                self.snapshotState = .loaded(canonical)
                completion(.success(canonical))
            } catch {
                self.invalidateSnapshotIfStorageIsUncertain(error)
                completion(.failure(error))
            }
        }
    }

    func acknowledgeQuarantineWithFreshEmptyV1(completion: @escaping Completion) {
        acknowledgeQuarantineWithFreshEmptyV1(
            commitPermission: M720JournalCommitPermission(),
            completion: completion
        )
    }

    func acknowledgeQuarantineWithFreshEmptyV1(
        commitPermission: M720JournalCommitPermission,
        completion: @escaping Completion
    ) {
        queue.async {
            do {
                try commitPermission.check()
                let acknowledged = try self.store.acknowledgeQuarantineWithFreshEmptyV1(
                    commitPermission: commitPermission
                )
                self.snapshotState = .loaded(acknowledged)
                completion(.success(acknowledged))
            } catch {
                self.invalidateSnapshotIfStorageIsUncertain(error)
                completion(.failure(error))
            }
        }
    }

    func removeDevice(
        for key: M720DeviceKey,
        expected: M720JournalDevice?,
        completion: @escaping Completion
    ) {
        removeDevice(
            for: key,
            expected: expected,
            commitPermission: M720JournalCommitPermission(),
            completion: completion
        )
    }

    func removeDevice(
        for key: M720DeviceKey,
        expected: M720JournalDevice?,
        commitPermission: M720JournalCommitPermission,
        completion: @escaping Completion
    ) {
        queue.async {
            do {
                try commitPermission.check()
                var candidate = try self.snapshotLoadingAfterUncertainIfNeeded()
                let deviceIndex = candidate.devices.firstIndex { $0.key == key }
                let existing = deviceIndex.map { candidate.devices[$0] }
                guard existing == expected else {
                    throw M720JournalRepositoryError.mismatchedDevice
                }
                if let deviceIndex {
                    candidate.devices.remove(at: deviceIndex)
                }
                let canonical = try candidate.validatedCanonicalized()
                try self.store.save(canonical, commitPermission: commitPermission)
                self.snapshotState = .loaded(canonical)
                completion(.success(canonical))
            } catch {
                self.invalidateSnapshotIfStorageIsUncertain(error)
                completion(.failure(error))
            }
        }
    }

    private func snapshotLoadingAfterUncertainIfNeeded() throws -> M720OwnershipJournal {
        switch snapshotState {
        case .neverLoaded:
            throw M720JournalRepositoryError.notLoaded
        case let .loaded(snapshot):
            return snapshot
        case .needsReloadAfterUncertain:
            do {
                let loaded = try store.load()
                snapshotState = .loaded(loaded)
                return loaded
            } catch {
                snapshotState = .needsReloadAfterUncertain
                throw error
            }
        }
    }

    private func invalidateSnapshotIfStorageIsUncertain(_ error: Error) {
        if isStorageUncertain(error) {
            snapshotState = .needsReloadAfterUncertain
        }
    }

    private func isStorageUncertain(_ error: Error) -> Bool {
        error as? M720JournalStoreError == .uncertain
    }
}

enum M720RecoveryDecision: Equatable {
    case clearThenReconcile
    case setAppliedThenKeep
    case setAppliedThenRestore
    case keepApplied
    case restore
    case conflict
}

enum M720OwnershipRecovery {
    static func decide(
        entry: M720JournalCIDEntry,
        current: HIDPPReportingState,
        policyRequiresCapture: Bool
    ) -> M720RecoveryDecision {
        if current == entry.original {
            return .clearThenReconcile
        }
        guard current == entry.intended else {
            return .conflict
        }

        switch entry.phase {
        case .prepared:
            return policyRequiresCapture ? .setAppliedThenKeep : .setAppliedThenRestore
        case .applied:
            return policyRequiresCapture ? .keepApplied : .restore
        case .restoring:
            return policyRequiresCapture ? .setAppliedThenKeep : .restore
        }
    }
}
