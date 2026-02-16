//
//  PresentationParser.swift
//  MeetingPrep
//
//  Build 4: Parse presentation files (PDF only - PPTX/Keynote deferred to Build 8)
//

import Foundation
import PDFKit

enum PresentationParserError: Error, LocalizedError {
    case unableToLoadPDF
    case noPDFContent
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .unableToLoadPDF:
            return "Unable to load PDF file"
        case .noPDFContent:
            return "PDF contains no extractable text"
        case .unsupportedFormat:
            return "File format not supported (PPTX/Keynote support coming in Build 8)"
        }
    }
}

struct PresentationParser {

    // MARK: - PDF Parsing

    /// Parse PDF files using PDFKit
    static func parsePDF(from url: URL) throws -> ParsedDocument {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw PresentationParserError.unableToLoadPDF
        }

        var fullTextParts: [String] = []
        var segments: [TextSegment] = []

        // Extract text from each page
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            guard let pageText = page.string else { continue }

            let trimmedText = pageText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedText.isEmpty {
                fullTextParts.append(trimmedText)
                segments.append(TextSegment(text: trimmedText))
            }
        }

        guard !fullTextParts.isEmpty else {
            throw PresentationParserError.noPDFContent
        }

        return ParsedDocument(
            sourceFileName: url.lastPathComponent,
            documentType: .presentation,
            fullText: fullTextParts.joined(separator: "\n\n---\n\n"),
            segments: segments
        )
    }

    // MARK: - PPTX Parsing (Placeholder for Build 8)

    /// PPTX parsing - deferred to Build 8
    static func parsePPTX(from url: URL) throws -> ParsedDocument {
        throw PresentationParserError.unsupportedFormat
    }

    // MARK: - Keynote Parsing (Placeholder for Build 8)

    /// Keynote parsing - deferred to Build 8
    static func parseKeynote(from url: URL) throws -> ParsedDocument {
        throw PresentationParserError.unsupportedFormat
    }
}
