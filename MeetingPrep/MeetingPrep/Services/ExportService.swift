//
//  ExportService.swift
//  MeetingPrep
//
//  Build 3: Export summaries to various formats
//

import Foundation
import AppKit
import UniformTypeIdentifiers

enum ExportFormat {
    case markdown
    case plainText
}

class ExportService {

    /// Export a summary to the specified format
    static func export(summary: Summary, document: Document, format: ExportFormat) -> String {
        switch format {
        case .markdown:
            return exportMarkdown(summary: summary, document: document)
        case .plainText:
            return exportPlainText(summary: summary, document: document)
        }
    }

    /// Save summary to file with NSSavePanel
    static func saveToFile(summary: Summary, document: Document, format: ExportFormat) {
        let content = export(summary: summary, document: document, format: format)
        let fileExtension = format == .markdown ? "md" : "txt"
        let defaultFileName = "\(document.fileName.replacingOccurrences(of: ".", with: "_"))_summary.\(fileExtension)"

        // Determine content type - use plain text for both since they're text files
        let contentType: UTType = .plainText

        // Ensure we're on the main thread
        DispatchQueue.main.async {
            let savePanel = NSSavePanel()
            savePanel.nameFieldStringValue = defaultFileName
            savePanel.allowedContentTypes = [contentType]
            savePanel.canCreateDirectories = true

            savePanel.begin { response in
                guard response == .OK, let url = savePanel.url else { return }

                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("Failed to save file: \(error)")
                }
            }
        }
    }

    /// Copy summary to clipboard
    static func copyToClipboard(summary: Summary, document: Document, format: ExportFormat) {
        let content = export(summary: summary, document: document, format: format)

        DispatchQueue.main.async {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(content, forType: .string)
        }
    }

    // MARK: - Format Implementations

    private static func exportMarkdown(summary: Summary, document: Document) -> String {
        var output = ""

        // Title
        output += "# \(summary.headline)\n\n"

        // Metadata
        output += "> **Document:** \(document.fileName)  \n"
        output += "> **Type:** \(document.fileType.displayName)  \n"
        output += "> **Generated:** \(formatDate(summary.generatedAt))  \n\n"

        output += "---\n\n"

        // Key Points
        output += "## Key Points\n\n"
        for point in summary.keyPoints {
            output += "- \(point)\n"
        }
        output += "\n"

        // Action Items
        if !summary.actionItems.isEmpty {
            output += "## Action Items\n\n"
            for item in summary.actionItems {
                output += "- [ ] \(item.description)"
                if let assignee = item.assignee {
                    output += " — **\(assignee)**"
                }
                if let deadline = item.deadline {
                    output += " (Due: \(deadline))"
                }
                output += "\n"
            }
            output += "\n"
        }

        // Participants
        if !summary.participants.isEmpty {
            output += "## Participants\n\n"
            output += summary.participants.joined(separator: " • ")
            output += "\n\n"
        }

        // Full Summary
        output += "## Summary\n\n"
        output += summary.fullSummary
        output += "\n"

        return output
    }

    private static func exportPlainText(summary: Summary, document: Document) -> String {
        var output = ""

        // Title
        output += summary.headline.uppercased()
        output += "\n"
        output += String(repeating: "=", count: summary.headline.count)
        output += "\n\n"

        // Metadata
        output += "Document: \(document.fileName)\n"
        output += "Type: \(document.fileType.displayName)\n"
        output += "Generated: \(formatDate(summary.generatedAt))\n\n"

        output += String(repeating: "-", count: 60)
        output += "\n\n"

        // Key Points
        output += "KEY POINTS\n\n"
        for (index, point) in summary.keyPoints.enumerated() {
            output += "\(index + 1). \(point)\n"
        }
        output += "\n"

        // Action Items
        if !summary.actionItems.isEmpty {
            output += "ACTION ITEMS\n\n"
            for item in summary.actionItems {
                output += "☐ \(item.description)"
                if let assignee = item.assignee {
                    output += " — \(assignee)"
                }
                if let deadline = item.deadline {
                    output += " (Due: \(deadline))"
                }
                output += "\n"
            }
            output += "\n"
        }

        // Participants
        if !summary.participants.isEmpty {
            output += "PARTICIPANTS\n\n"
            output += summary.participants.joined(separator: ", ")
            output += "\n\n"
        }

        // Full Summary
        output += "SUMMARY\n\n"
        output += summary.fullSummary
        output += "\n"

        return output
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
