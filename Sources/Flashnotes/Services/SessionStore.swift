import Foundation

@MainActor
@Observable
final class SessionStore {
    @ObservationIgnored private let defaults: UserDefaults
    struct Location: Codable, Equatable {
        let folderID: UUID?
        let itemID: UUID?
    }

    private enum Keys {
        static let folder = "selectedFolderID"
        static let tabs = "openTabIDs"
        static let tab = "selectedTabID"
        static let back = "navigationBackStack"
        static let forward = "navigationForwardStack"
        static let recentItems = "recentItemIDs"
    }

    var selectedFolderID: UUID? { didSet { save() } }
    var openTabIDs: [UUID] { didSet { save() } }
    var selectedTabID: UUID? { didSet { save() } }
    var recentItemIDs: [UUID] { didSet { save() } }
    private(set) var backStack: [Location]
    private(set) var forwardStack: [Location]
    let sessionQuote: SessionQuote
    let sessionGreeting: String

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        sessionQuote = SessionQuoteLibrary.random()
        sessionGreeting = SessionGreetingLibrary.random()
        selectedFolderID = defaults.string(forKey: Keys.folder).flatMap(UUID.init(uuidString:))
        selectedTabID = defaults.string(forKey: Keys.tab).flatMap(UUID.init(uuidString:))
        let strings = defaults.stringArray(forKey: Keys.tabs) ?? []
        openTabIDs = strings.compactMap(UUID.init(uuidString:))
        recentItemIDs = (defaults.stringArray(forKey: Keys.recentItems) ?? []).compactMap(UUID.init(uuidString:))
        backStack = Self.decodeLocations(defaults.data(forKey: Keys.back))
        forwardStack = Self.decodeLocations(defaults.data(forKey: Keys.forward))
    }

    func open(_ item: LibraryItem) {
        let destination = Location(folderID: item.folder?.id, itemID: item.id)
        if destination == currentLocation {
            item.lastOpenedAt = .now
            recordRecent(item.id)
            return
        }
        recordNavigation()
        if !openTabIDs.contains(item.id) { openTabIDs.append(item.id) }
        selectedTabID = item.id
        selectedFolderID = item.folder?.id
        item.lastOpenedAt = .now
        item.folder?.lastOpenedAt = .now
        recordRecent(item.id)
    }

    func navigate(to folder: LibraryFolder?, item: LibraryItem? = nil) {
        let destination = Location(folderID: folder?.id, itemID: item?.id)
        guard destination != currentLocation else { return }
        recordNavigation()
        selectedFolderID = destination.folderID
        selectedTabID = destination.itemID
        folder?.lastOpenedAt = .now
        item?.lastOpenedAt = .now
        if let item { recordRecent(item.id) }
        if let item, !openTabIDs.contains(item.id) { openTabIDs.append(item.id) }
    }

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    func goBack() {
        guard let destination = backStack.popLast() else { return }
        forwardStack.append(currentLocation)
        apply(destination)
    }

    func goForward() {
        guard let destination = forwardStack.popLast() else { return }
        backStack.append(currentLocation)
        apply(destination)
    }

    func close(_ id: UUID) {
        guard let index = openTabIDs.firstIndex(of: id) else { return }
        openTabIDs.remove(at: index)
        if selectedTabID == id {
            selectedTabID = openTabIDs.indices.contains(index) ? openTabIDs[index] : openTabIDs.last
        }
    }

    func removeReferences(to ids: Set<UUID>) {
        openTabIDs.removeAll { ids.contains($0) }
        if let selectedTabID, ids.contains(selectedTabID) { self.selectedTabID = openTabIDs.last }
        recentItemIDs.removeAll { ids.contains($0) }
    }

    private func save() {
        defaults.set(selectedFolderID?.uuidString, forKey: Keys.folder)
        defaults.set(selectedTabID?.uuidString, forKey: Keys.tab)
        defaults.set(openTabIDs.map(\.uuidString), forKey: Keys.tabs)
        defaults.set(recentItemIDs.map(\.uuidString), forKey: Keys.recentItems)
        defaults.set(try? JSONEncoder().encode(backStack), forKey: Keys.back)
        defaults.set(try? JSONEncoder().encode(forwardStack), forKey: Keys.forward)
    }

    private var currentLocation: Location { Location(folderID: selectedFolderID, itemID: selectedTabID) }

    private func recordNavigation() {
        if backStack.last != currentLocation { backStack.append(currentLocation) }
        if backStack.count > 80 { backStack.removeFirst(backStack.count - 80) }
        forwardStack.removeAll()
        save()
    }

    private func apply(_ location: Location) {
        selectedFolderID = location.folderID
        selectedTabID = location.itemID
        save()
    }

    private func recordRecent(_ id: UUID) {
        recentItemIDs.removeAll { $0 == id }
        recentItemIDs.insert(id, at: 0)
        if recentItemIDs.count > 12 { recentItemIDs.removeLast(recentItemIDs.count - 12) }
    }

    private static func decodeLocations(_ data: Data?) -> [Location] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([Location].self, from: data)) ?? []
    }
}
