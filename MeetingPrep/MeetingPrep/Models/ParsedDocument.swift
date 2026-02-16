//
//  ParsedDocument.swift
//  MeetingPrep
//
//  Build 4: Intermediate parsing result before LLM processing
//

import Foundation

/// Represents a parsed document with extracted text and metadata
struct ParsedDocument {
    let id: UUID
    let sourceFileName: String
    let documentType: DocumentType
    let fullText: String
    let segments: [TextSegment]
    let parsedAt: Date

    init(id: UUID = UUID(), sourceFileName: String, documentType: DocumentType,
         fullText: String, segments: [TextSegment], parsedAt: Date = Date()) {
        self.id = id
        self.sourceFileName = sourceFileName
        self.documentType = documentType
        self.fullText = fullText
        self.segments = segments
        self.parsedAt = parsedAt
    }
}

/// A segment of text with optional metadata (timestamp, speaker)
struct TextSegment {
    let text: String
    let startTime: TimeInterval?
    let endTime: TimeInterval?
    let speaker: String?

    init(text: String, startTime: TimeInterval? = nil, endTime: TimeInterval? = nil, speaker: String? = nil) {
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.speaker = speaker
    }
}
