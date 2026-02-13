//
//  TranscriptParserTests.swift
//  MeetingPrepTests
//
//  Build 4: Unit tests for TranscriptParser
//

import XCTest
@testable import MeetingPrep

final class TranscriptParserTests: XCTestCase {

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

    // MARK: - Plain Text Tests

    func testParsePlainText() throws {
        // Given
        let content = "This is a simple text file.\nIt has multiple lines.\nAnd should be parsed correctly."
        let fileURL = tempDirectory.appendingPathComponent("test.txt")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        // When
        let result = try TranscriptParser.parsePlainText(from: fileURL)

        // Then
        XCTAssertEqual(result.sourceFileName, "test.txt")
        XCTAssertEqual(result.documentType, .transcript)
        XCTAssertEqual(result.fullText, content)
        XCTAssertEqual(result.segments.count, 1)
        XCTAssertEqual(result.segments.first?.text, content)
        XCTAssertNil(result.segments.first?.speaker)
    }

    func testParsePlainTextEmpty() throws {
        // Given
        let content = ""
        let fileURL = tempDirectory.appendingPathComponent("empty.txt")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        // When
        let result = try TranscriptParser.parsePlainText(from: fileURL)

        // Then
        XCTAssertEqual(result.fullText, "")
        XCTAssertEqual(result.segments.count, 1)
    }

    // MARK: - VTT Tests

    func testParseVTTWithSpeakers() throws {
        // Given
        let vttContent = """
        WEBVTT

        00:00:00.000 --> 00:00:05.000
        <v Sarah Chen>Good morning everyone.

        00:00:05.000 --> 00:00:10.000
        <v Mike Rodriguez>Thanks for joining.
        """
        let fileURL = tempDirectory.appendingPathComponent("test.vtt")
        try vttContent.write(to: fileURL, atomically: true, encoding: .utf8)

        // When
        let result = try TranscriptParser.parseVTT(from: fileURL)

        // Then
        XCTAssertEqual(result.sourceFileName, "test.vtt")
        XCTAssertEqual(result.documentType, .transcript)
        XCTAssertEqual(result.segments.count, 2)

        // First segment
        XCTAssertEqual(result.segments[0].speaker, "Sarah Chen")
        XCTAssertEqual(result.segments[0].text, "Good morning everyone.")
        XCTAssertEqual(result.segments[0].startTime, 0.0)
        XCTAssertEqual(result.segments[0].endTime, 5.0)

        // Second segment
        XCTAssertEqual(result.segments[1].speaker, "Mike Rodriguez")
        XCTAssertEqual(result.segments[1].text, "Thanks for joining.")
        XCTAssertEqual(result.segments[1].startTime, 5.0)
        XCTAssertEqual(result.segments[1].endTime, 10.0)

        // Full text should include speakers
        XCTAssertTrue(result.fullText.contains("Sarah Chen: Good morning everyone."))
        XCTAssertTrue(result.fullText.contains("Mike Rodriguez: Thanks for joining."))
    }

    func testParseVTTWithoutSpeakers() throws {
        // Given
        let vttContent = """
        WEBVTT

        00:00:00.000 --> 00:00:03.000
        This is a subtitle without a speaker.

        00:00:03.000 --> 00:00:06.000
        Another subtitle line.
        """
        let fileURL = tempDirectory.appendingPathComponent("test.vtt")
        try vttContent.write(to: fileURL, atomically: true, encoding: .utf8)

        // When
        let result = try TranscriptParser.parseVTT(from: fileURL)

        // Then
        XCTAssertEqual(result.segments.count, 2)
        XCTAssertNil(result.segments[0].speaker)
        XCTAssertNil(result.segments[1].speaker)
        XCTAssertEqual(result.segments[0].text, "This is a subtitle without a speaker.")
    }

    func testParseVTTInvalidFormat() throws {
        // Given (missing WEBVTT header)
        let invalidContent = """
        00:00:00.000 --> 00:00:03.000
        This should fail.
        """
        let fileURL = tempDirectory.appendingPathComponent("invalid.vtt")
        try invalidContent.write(to: fileURL, atomically: true, encoding: .utf8)

        // Then
        XCTAssertThrowsError(try TranscriptParser.parseVTT(from: fileURL)) { error in
            XCTAssertTrue(error is TranscriptParserError)
        }
    }

    // MARK: - SRT Tests

    func testParseSRT() throws {
        // Given
        let srtContent = """
        1
        00:00:00,000 --> 00:00:05,000
        First subtitle line.

        2
        00:00:05,000 --> 00:00:10,000
        Second subtitle line.
        """
        let fileURL = tempDirectory.appendingPathComponent("test.srt")
        try srtContent.write(to: fileURL, atomically: true, encoding: .utf8)

        // When
        let result = try TranscriptParser.parseSRT(from: fileURL)

        // Then
        XCTAssertEqual(result.sourceFileName, "test.srt")
        XCTAssertEqual(result.documentType, .transcript)
        XCTAssertEqual(result.segments.count, 2)

        // First segment
        XCTAssertEqual(result.segments[0].text, "First subtitle line.")
        XCTAssertEqual(result.segments[0].startTime, 0.0)
        XCTAssertEqual(result.segments[0].endTime, 5.0)
        XCTAssertNil(result.segments[0].speaker)

        // Second segment
        XCTAssertEqual(result.segments[1].text, "Second subtitle line.")
        XCTAssertEqual(result.segments[1].startTime, 5.0)
        XCTAssertEqual(result.segments[1].endTime, 10.0)
    }

    func testParseSRTMultilineSubtitle() throws {
        // Given
        let srtContent = """
        1
        00:00:00,000 --> 00:00:05,000
        This is a subtitle
        that spans multiple lines.
        """
        let fileURL = tempDirectory.appendingPathComponent("test.srt")
        try srtContent.write(to: fileURL, atomically: true, encoding: .utf8)

        // When
        let result = try TranscriptParser.parseSRT(from: fileURL)

        // Then
        XCTAssertEqual(result.segments.count, 1)
        XCTAssertEqual(result.segments[0].text, "This is a subtitle that spans multiple lines.")
    }

    // MARK: - JSON Tests

    func testParseJSONWithFullText() throws {
        // Given
        let jsonContent = """
        {
            "text": "This is the full transcript text.",
            "segments": [
                {
                    "text": "First segment",
                    "start": 0.0,
                    "end": 5.0,
                    "speaker": "Alice"
                },
                {
                    "text": "Second segment",
                    "start": 5.0,
                    "end": 10.0,
                    "speaker": "Bob"
                }
            ]
        }
        """
        let fileURL = tempDirectory.appendingPathComponent("test.json")
        try jsonContent.write(to: fileURL, atomically: true, encoding: .utf8)

        // When
        let result = try TranscriptParser.parseJSON(from: fileURL)

        // Then
        XCTAssertEqual(result.sourceFileName, "test.json")
        XCTAssertEqual(result.documentType, .transcript)
        XCTAssertEqual(result.fullText, "This is the full transcript text.")
        XCTAssertEqual(result.segments.count, 2)
        XCTAssertEqual(result.segments[0].speaker, "Alice")
        XCTAssertEqual(result.segments[1].speaker, "Bob")
    }

    func testParseJSONTranscriptField() throws {
        // Given
        let jsonContent = """
        {
            "transcript": "Alternative JSON format with transcript field."
        }
        """
        let fileURL = tempDirectory.appendingPathComponent("test.json")
        try jsonContent.write(to: fileURL, atomically: true, encoding: .utf8)

        // When
        let result = try TranscriptParser.parseJSON(from: fileURL)

        // Then
        XCTAssertEqual(result.fullText, "Alternative JSON format with transcript field.")
        XCTAssertEqual(result.segments.count, 1)
    }

    func testParseJSONSegmentArray() throws {
        // Given
        let jsonContent = """
        [
            {
                "text": "Segment one",
                "start": 0.0,
                "end": 3.0
            },
            {
                "text": "Segment two",
                "start": 3.0,
                "end": 6.0
            }
        ]
        """
        let fileURL = tempDirectory.appendingPathComponent("test.json")
        try jsonContent.write(to: fileURL, atomically: true, encoding: .utf8)

        // When
        let result = try TranscriptParser.parseJSON(from: fileURL)

        // Then
        XCTAssertEqual(result.segments.count, 2)
        XCTAssertEqual(result.segments[0].text, "Segment one")
        XCTAssertEqual(result.segments[1].text, "Segment two")
        XCTAssertTrue(result.fullText.contains("Segment one"))
        XCTAssertTrue(result.fullText.contains("Segment two"))
    }

    func testParseJSONInvalidFormat() throws {
        // Given
        let jsonContent = """
        {
            "invalid": "no text or transcript field"
        }
        """
        let fileURL = tempDirectory.appendingPathComponent("invalid.json")
        try jsonContent.write(to: fileURL, atomically: true, encoding: .utf8)

        // Then
        XCTAssertThrowsError(try TranscriptParser.parseJSON(from: fileURL))
    }
}
