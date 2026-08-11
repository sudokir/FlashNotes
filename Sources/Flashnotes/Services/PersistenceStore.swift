import Foundation
import SwiftData

enum PersistenceStore {
    static let directoryName = "Flashnotes"
    static let storeName = "Flashnotes.store"

    static func configuration(schema: Schema, inMemory: Bool) throws -> ModelConfiguration {
        if inMemory {
            return ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        }

        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeURL = try prepareStore(in: support)
        return ModelConfiguration("Flashnotes", schema: schema, url: storeURL)
    }

    @discardableResult
    static func prepareStore(in applicationSupportURL: URL, fileManager: FileManager = .default) throws -> URL {
        let directory = applicationSupportURL.appending(path: directoryName, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appending(path: storeName)
        let legacy = applicationSupportURL.appending(path: "default.store")

        if !fileManager.fileExists(atPath: destination.path), fileManager.fileExists(atPath: legacy.path) {
            try copyStoreFamily(from: legacy, to: destination, fileManager: fileManager)
        }
        try createCompatibilityBackupIfNeeded(of: destination, in: directory, fileManager: fileManager)
        return destination
    }

    private static func createCompatibilityBackupIfNeeded(of store: URL, in directory: URL, fileManager: FileManager) throws {
        guard fileManager.fileExists(atPath: store.path) else { return }
        let backupDirectory = directory.appending(path: "Backups/Before-Library-Features", directoryHint: .isDirectory)
        let backupStore = backupDirectory.appending(path: storeName)
        guard !fileManager.fileExists(atPath: backupStore.path) else { return }
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        try copyStoreFamily(from: store, to: backupStore, fileManager: fileManager)
    }

    private static func copyStoreFamily(from source: URL, to destination: URL, fileManager: FileManager) throws {
        for suffix in ["", "-wal", "-shm"] {
            let sourceFile = URL(fileURLWithPath: source.path + suffix)
            guard fileManager.fileExists(atPath: sourceFile.path) else { continue }
            let destinationFile = URL(fileURLWithPath: destination.path + suffix)
            try fileManager.copyItem(at: sourceFile, to: destinationFile)
        }
    }
}
