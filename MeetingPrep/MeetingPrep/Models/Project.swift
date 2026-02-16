//
//  Project.swift
//  MeetingPrep
//
//  SwiftData model for projects
//

import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var notes: String

    @Relationship(deleteRule: .cascade, inverse: \Document.project)
    var documents: [Document]

    init(title: String, notes: String = "") {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.notes = notes
        self.documents = []
    }

    /// Update the modification timestamp
    func touch() {
        self.updatedAt = Date()
    }
}
