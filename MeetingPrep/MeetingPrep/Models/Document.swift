//
//  Document.swift
//  MeetingPrep
//
//  SwiftData model for documents
//

import Foundation
import SwiftData
import UniformTypeIdentifiers

@Model
final class Document {
    @Attribute(.unique) var id: UUID
    var fileName: String
    var fileType: DocumentType
    var importedAt: Date
    var fileSize: Int64

    @Relationship(deleteRule: .cascade, inverse: \Summary.document)
    var summary: Summary?

    var project: Project?

    init(fileName: String, fileType: DocumentType, fileSize: Int64) {
        self.id = UUID()
        self.fileName = fileName
        self.fileType = fileType
        self.importedAt = Date()
        self.fileSize = fileSize
    }

    /// Human-readable file size
    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    /// Whether this document has been processed and has a summary
    var isProcessed: Bool {
        summary != nil
    }
}

enum DocumentType: String, Codable {
    case transcript     // .txt, .vtt, .srt, .json
    case audio          // .m4a, .mp3, .wav
    case presentation   // .pdf, .pptx, .key

    /// Detect document type from file URL
    static func from(url: URL) -> DocumentType {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "txt", "vtt", "srt", "json":
            return .transcript
        case "m4a", "mp3", "wav":
            return .audio
        case "pdf", "pptx", "key":
            return .presentation
        default:
            return .transcript  // Default fallback
        }
    }

    /// SF Symbol icon name for this document type
    var iconName: String {
        switch self {
        case .transcript:
            return "doc.text"
        case .audio:
            return "waveform"
        case .presentation:
            return "doc.richtext"
        }
    }

    /// Human-readable type name
    var displayName: String {
        switch self {
        case .transcript:
            return "Transcript"
        case .audio:
            return "Audio"
        case .presentation:
            return "Presentation"
        }
    }
}
