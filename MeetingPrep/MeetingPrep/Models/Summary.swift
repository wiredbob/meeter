//
//  Summary.swift
//  MeetingPrep
//
//  SwiftData model for summaries
//

import Foundation
import SwiftData

@Model
final class Summary {
    @Attribute(.unique) var id: UUID
    var headline: String
    var keyPoints: [String]
    var actionItemsData: Data  // Encoded [ActionItem]
    var participants: [String]
    var fullSummary: String
    var generatedAt: Date

    var document: Document?

    init(headline: String, keyPoints: [String], actionItems: [ActionItem],
         participants: [String], fullSummary: String) {
        self.id = UUID()
        self.headline = headline
        self.keyPoints = keyPoints
        self.actionItemsData = (try? JSONEncoder().encode(actionItems)) ?? Data()
        self.participants = participants
        self.fullSummary = fullSummary
        self.generatedAt = Date()
    }

    /// Decoded action items
    var actionItems: [ActionItem] {
        get {
            (try? JSONDecoder().decode([ActionItem].self, from: actionItemsData)) ?? []
        }
        set {
            actionItemsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }
}

/// Action item extracted from a summary
struct ActionItem: Codable, Hashable, Identifiable {
    let id: UUID
    let description: String
    let assignee: String?
    let deadline: String?

    init(description: String, assignee: String? = nil, deadline: String? = nil) {
        self.id = UUID()
        self.description = description
        self.assignee = assignee
        self.deadline = deadline
    }
}
