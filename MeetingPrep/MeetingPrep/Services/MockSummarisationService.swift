//
//  MockSummarisationService.swift
//  MeetingPrep
//
//  Build 4: Real file parsing (no LLM yet)
//

import Foundation

/// Parses files and returns raw extracted text (no LLM processing yet)
@MainActor
class MockSummarisationService {

    // NO DELAY - instant parsing results

    /// Generate a summary by parsing the file (no LLM yet - shows raw text)
    func generateSummary(for document: Document, fileURL: URL) async throws -> Summary {
        // Parse file into structured text
        let parsed = try parseFile(url: fileURL, type: document.fileType)

        // Extract unique speakers (for VTT/SRT files)
        let speakers = Array(Set(parsed.segments.compactMap { $0.speaker }))

        // Return summary with RAW EXTRACTED TEXT
        return Summary(
            headline: "Extracted from: \(document.fileName)",
            keyPoints: [
                "File type: \(document.fileType.displayName)",
                "Content length: \(parsed.fullText.count) characters",
                "Segments: \(parsed.segments.count)",
                speakers.isEmpty ? "No speakers detected" : "Speakers: \(speakers.joined(separator: ", "))"
            ],
            actionItems: [],
            participants: speakers,
            fullSummary: parsed.fullText  // RAW TEXT SHOWN HERE
        )
    }

    private func parseFile(url: URL, type: DocumentType) throws -> ParsedDocument {
        switch type {
        case .transcript:
            // Determine specific format based on extension
            let ext = url.pathExtension.lowercased()
            switch ext {
            case "vtt":
                return try TranscriptParser.parseVTT(from: url)
            case "srt":
                return try TranscriptParser.parseSRT(from: url)
            case "json":
                return try TranscriptParser.parseJSON(from: url)
            default:  // .txt and others
                return try TranscriptParser.parsePlainText(from: url)
            }

        case .presentation:
            let ext = url.pathExtension.lowercased()
            if ext == "pdf" {
                return try PresentationParser.parsePDF(from: url)
            } else {
                // PPTX/Keynote not yet supported - placeholder
                return ParsedDocument(
                    id: UUID(),
                    sourceFileName: url.lastPathComponent,
                    documentType: .presentation,
                    fullText: "[\(ext.uppercased()) parsing will be implemented in Build 8]",
                    segments: [],
                    parsedAt: Date()
                )
            }

        case .audio:
            // Audio transcription in Build 7
            return ParsedDocument(
                id: UUID(),
                sourceFileName: url.lastPathComponent,
                documentType: .audio,
                fullText: "[Audio transcription not yet implemented - Build 7]",
                segments: [],
                parsedAt: Date()
            )
        }
    }
}
