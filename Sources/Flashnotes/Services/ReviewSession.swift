import Foundation

enum ReviewOrder: String, CaseIterable, Identifiable {
    case ordered
    case random
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum ReviewFace: Equatable {
    case front
    case back
    case complete
}

struct ReviewSession: Equatable {
    private(set) var cardIDs: [UUID]
    private(set) var index = 0
    private(set) var face: ReviewFace = .front

    init(cardIDs: [UUID], order: ReviewOrder, shuffle: ([UUID]) -> [UUID] = { $0.shuffled() }) {
        self.cardIDs = order == .ordered ? cardIDs : shuffle(cardIDs)
        if cardIDs.isEmpty { face = .complete }
    }

    var currentCardID: UUID? {
        guard cardIDs.indices.contains(index), face != .complete else { return nil }
        return cardIDs[index]
    }

    var progressText: String {
        face == .complete ? "Complete" : "\(index + 1) of \(cardIDs.count)"
    }

    mutating func space() {
        switch face {
        case .front:
            face = .back
        case .back:
            if index == cardIDs.count - 1 {
                face = .complete
            } else {
                index += 1
                face = .front
            }
        case .complete:
            break
        }
    }

    mutating func previous() {
        if face == .complete, !cardIDs.isEmpty {
            index = cardIDs.count - 1
            face = .front
        } else if index > 0 {
            index -= 1
            face = .front
        } else {
            face = .front
        }
    }

    mutating func restart() {
        index = 0
        face = cardIDs.isEmpty ? .complete : .front
    }
}
