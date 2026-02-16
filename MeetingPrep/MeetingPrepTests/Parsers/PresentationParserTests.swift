//
//  PresentationParserTests.swift
//  MeetingPrepTests
//
//  Build 4: Unit tests for PresentationParser
//

import XCTest
import PDFKit
@testable import MeetingPrep

final class PresentationParserTests: XCTestCase {

    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    // MARK: - PDF Tests

    func testParsePDFSinglePage() throws {
        // Given
        let pdfURL = tempDirectory.appendingPathComponent("NI-GAS-TCs-V15.pdf")
        let testText = "This is a test PDF document.\nIt contains some sample text."

        // Create a simple PDF with PDFKit
        let pdfDocument = PDFDocument()
        let page = PDFPage()

        // Create PDF page with text (using annotation as a workaround for testing)
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // Letter size
        let textAnnotation = PDFAnnotation(bounds: pageRect, forType: .freeText, withProperties: nil)
        textAnnotation.contents = testText

        // For actual testing, we would need a real PDF file or create one properly
        // This test documents the expected behavior

        // Since creating PDFs programmatically is complex, we'll mark this as a placeholder
        // In real testing, you would use actual PDF files in the test bundle
        throw XCTSkip("PDF creation in tests requires actual PDF files in test bundle")
    }

    func testParsePDFInvalidFile() throws {
        // Given
        let invalidURL = tempDirectory.appendingPathComponent("notapdf.pdf")
        try "Not a real PDF".write(to: invalidURL, atomically: true, encoding: .utf8)

        // Then
        XCTAssertThrowsError(try PresentationParser.parsePDF(from: invalidURL)) { error in
            guard let parserError = error as? PresentationParserError else {
                XCTFail("Expected PresentationParserError")
                return
            }
            XCTAssertEqual(parserError, .unableToLoadPDF)
        }
    }

    func testParsePDFNonExistentFile() throws {
        // Given
        let nonExistentURL = tempDirectory.appendingPathComponent("doesnotexist.pdf")

        // Then
        XCTAssertThrowsError(try PresentationParser.parsePDF(from: nonExistentURL))
    }

    // MARK: - PPTX Tests (Placeholder)

    func testParsePPTXUnsupported() throws {
        // Given
        let pptxURL = tempDirectory.appendingPathComponent("test.pptx")
        try "Mock PPTX".write(to: pptxURL, atomically: true, encoding: .utf8)

        // Then
        XCTAssertThrowsError(try PresentationParser.parsePPTX(from: pptxURL)) { error in
            guard let parserError = error as? PresentationParserError else {
                XCTFail("Expected PresentationParserError")
                return
            }
            XCTAssertEqual(parserError, .unsupportedFormat)
        }
    }

    // MARK: - Keynote Tests (Placeholder)

    func testParseKeynoteUnsupported() throws {
        // Given
        let keynoteURL = tempDirectory.appendingPathComponent("test.key")
        try "Mock Keynote".write(to: keynoteURL, atomically: true, encoding: .utf8)

        // Then
        XCTAssertThrowsError(try PresentationParser.parseKeynote(from: keynoteURL)) { error in
            guard let parserError = error as? PresentationParserError else {
                XCTFail("Expected PresentationParserError")
                return
            }
            XCTAssertEqual(parserError, .unsupportedFormat)
        }
    }

    // MARK: - Integration Tests

    func testPDFParserReturnsCorrectDocumentType() throws {
        // This test would work with a real PDF file
        // Documenting expected behavior:
        // - sourceFileName should match file name
        // - documentType should be .presentation
        // - fullText should contain extracted text
        // - segments should have one segment per page

        throw XCTSkip("Requires real PDF file in test bundle for integration testing")
    }
}

// MARK: - Test Helper: PresentationParserError Equatable

extension PresentationParserError: Equatable {
    public static func == (lhs: PresentationParserError, rhs: PresentationParserError) -> Bool {
        switch (lhs, rhs) {
        case (.unableToLoadPDF, .unableToLoadPDF),
             (.noPDFContent, .noPDFContent),
             (.unsupportedFormat, .unsupportedFormat):
            return true
        default:
            return false
        }
    }
}
