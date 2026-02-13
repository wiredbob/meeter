//
//  MeetingPrepApp.swift
//  MeetingPrep
//
//  Phase 1: UI Demo with Mocked Data
//

import SwiftUI
import SwiftData

@main
struct MeetingPrepApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Project.self, Document.self, Summary.self])
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Project") {
                    NotificationCenter.default.post(name: .createProject, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandMenu("Document") {
                Button("Import Document") {
                    NotificationCenter.default.post(name: .importDocument, object: nil)
                }
                .keyboardShortcut("i", modifiers: .command)

                Divider()

                Button("Delete Document") {
                    NotificationCenter.default.post(name: .deleteDocument, object: nil)
                }
                .keyboardShortcut(.delete, modifiers: [])
            }
        }
    }
}

extension Notification.Name {
    static let createProject = Notification.Name("createProject")
    static let importDocument = Notification.Name("importDocument")
    static let deleteDocument = Notification.Name("deleteDocument")
}
