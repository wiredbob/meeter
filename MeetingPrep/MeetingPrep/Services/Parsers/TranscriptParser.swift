//
//  TranscriptParser.swift
//  MeetingPrep
//
//  Build 4: Parse transcript files (.txt, .vtt, .srt, .json)
//

import Foundation

enum TranscriptParserError: Error, LocalizedError {
    case invalidFileFormat
    case unableToReadFile
    case unsupportedEncoding

    var errorDescription: String? {
        switch self {
        case .invalidFileFormat:
            return "Invalid file format"
        case .unableToReadFile:
            return "Unable to read file"
        case .unsupportedEncoding:
            return "File encoding not supported"
        }
    }
}

struct TranscriptParser {

    // MARK: - Plain Text Parsing

    /// Parse plain text files (.txt)
    static func parsePlainText(from url: URL) throws -> ParsedDocument {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            throw TranscriptParserError.unableToReadFile
        }

        return ParsedDocument(
            sourceFileName: url.lastPathComponent,
            documentType: .transcript,
            fullText: content,
            segments: [TextSegment(text: content)]
        )
    }

    // MARK: - VTT Parsing

    /// Parse WebVTT subtitle files (.vtt)
    static func parseVTT(from url: URL) throws -> ParsedDocument {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            throw TranscriptParserError.unableToReadFile
        }

        // Verify VTT header
        guard content.hasPrefix("WEBVTT") else {
            throw TranscriptParserError.invalidFileFormat
        }

        var segments: [TextSegment] = []
        var fullTextParts: [String] = []

        // Split into cue blocks (separated by blank lines)
        let lines = content.components(separatedBy: .newlines)
        var i = 0

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

            // Look for timestamp line (contains -->)
            if line.contains("-->") {
                let timeParts = line.components(separatedBy: "-->").map { $0.trimmingCharacters(in: .whitespaces) }
                let startTime = parseVTTTimestamp(timeParts[0])
                let endTime = timeParts.count > 1 ? parseVTTTimestamp(timeParts[1]) : nil

                // Next line(s) contain the text (possibly with speaker annotation)
                i += 1
                var cueText = ""
                var speaker: String? = nil

                while i < lines.count {
                    let textLine = lines[i]
                    if textLine.trimmingCharacters(in: .whitespaces).isEmpty {
                        break
                    }

                    // Extract speaker from <v Speaker Name>text format
                    if let speakerMatch = extractVTTSpeaker(from: textLine) {
                        speaker = speakerMatch.speaker
                        cueText += speakerMatch.text
                    } else {
                        cueText += textLine
                    }

                    i += 1
                }

                let cleanText = cueText.trimmingCharacters(in: .whitespaces)
                if !cleanText.isEmpty {
                    segments.append(TextSegment(
                        text: cleanText,
                        startTime: startTime,
                        endTime: endTime,
                        speaker: speaker
                    ))

                    // Build full text with speaker prefix if available
                    if let speaker = speaker {
                        fullTextParts.append("\(speaker): \(cleanText)")
                    } else {
                        fullTextParts.append(cleanText)
                    }
                }
            }

            i += 1
        }

        return ParsedDocument(
            sourceFileName: url.lastPathComponent,
            documentType: .transcript,
            fullText: fullTextParts.joined(separator: "\n\n"),
            segments: segments
        )
    }

    /// Extract speaker name from VTT voice tag: <v Speaker Name>text
    private static func extractVTTSpeaker(from line: String) -> (speaker: String, text: String)? {
        let pattern = #"<v\s+([^>]+)>(.+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        let speakerRange = Range(match.range(at: 1), in: line)
        let textRange = Range(match.range(at: 2), in: line)

        guard let speakerRange = speakerRange, let textRange = textRange else {
            return nil
        }

        let speaker = String(line[speakerRange]).trimmingCharacters(in: .whitespaces)
        let text = String(line[textRange]).trimmingCharacters(in: .whitespaces)

        return (speaker: speaker, text: text)
    }

    /// Parse VTT timestamp (HH:MM:SS.mmm or MM:SS.mmm)
    private static func parseVTTTimestamp(_ timestamp: String) -> TimeInterval? {
        let parts = timestamp.components(separatedBy: ":")
        guard parts.count >= 2 else { return nil }

        var hours: Double = 0
        var minutes: Double = 0
        var seconds: Double = 0

        if parts.count == 3 {
            // HH:MM:SS.mmm
            hours = Double(parts[0]) ?? 0
            minutes = Double(parts[1]) ?? 0
            seconds = Double(parts[2].replacingOccurrences(of: ",", with: ".")) ?? 0
        } else if parts.count == 2 {
            // MM:SS.mmm
            minutes = Double(parts[0]) ?? 0
            seconds = Double(parts[1].replacingOccurrences(of: ",", with: ".")) ?? 0
        }

        return hours * 3600 + minutes * 60 + seconds
    }

    // MARK: - SRT Parsing

    /// Parse SRT subtitle files (.srt)
    static func parseSRT(from url: URL) throws -> ParsedDocument {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            throw TranscriptParserError.unableToReadFile
        }

        var segments: [TextSegment] = []
        var fullTextParts: [String] = []

        // Split into subtitle blocks (separated by blank lines)
        let blocks = content.components(separatedBy: "\n\n")

        for block in blocks {
            let lines = block.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            guard lines.count >= 3 else { continue }

            // Line 0: sequence number
            // Line 1: timestamp
            // Line 2+: text

            let timestampLine = lines[1]
            if timestampLine.contains("-->") {
                let timeParts = timestampLine.components(separatedBy: "-->")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                let startTime = parseSRTTimestamp(timeParts[0])
                let endTime = timeParts.count > 1 ? parseSRTTimestamp(timeParts[1]) : nil

                let text = lines[2...].joined(separator: " ")

                segments.append(TextSegment(
                    text: text,
                    startTime: startTime,
                    endTime: endTime,
                    speaker: nil
                ))

                fullTextParts.append(text)
            }
        }

        return ParsedDocument(
            sourceFileName: url.lastPathComponent,
            documentType: .transcript,
            fullText: fullTextParts.joined(separator: "\n\n"),
            segments: segments
        )
    }

    /// Parse SRT timestamp (HH:MM:SS,mmm)
    private static func parseSRTTimestamp(_ timestamp: String) -> TimeInterval? {
        // Format: HH:MM:SS,mmm
        let cleaned = timestamp.replacingOccurrences(of: ",", with: ".")
        let parts = cleaned.components(separatedBy: ":")
        guard parts.count == 3 else { return nil }

        let hours = Double(parts[0]) ?? 0
        let minutes = Double(parts[1]) ?? 0
        let seconds = Double(parts[2]) ?? 0

        return hours * 3600 + minutes * 60 + seconds
    }

    // MARK: - JSON Parsing

    /// Parse JSON transcript files (common format from transcription services)
    static func parseJSON(from url: URL) throws -> ParsedDocument {
        guard let data = try? Data(contentsOf: url) else {
            throw TranscriptParserError.unableToReadFile
        }

        // Try to decode as generic transcript JSON
        // Common formats:
        // 1. { "text": "...", "segments": [...] }
        // 2. { "transcript": "..." }
        // 3. Array of segments

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Format 1 or 2
            if let fullText = json["text"] as? String ?? json["transcript"] as? String {
                var segments: [TextSegment] = []

                // Try to extract segments if available
                if let segmentsArray = json["segments"] as? [[String: Any]] {
                    for segmentData in segmentsArray {
                        let text = segmentData["text"] as? String ?? ""
                        let startTime = segmentData["start"] as? TimeInterval
                        let endTime = segmentData["end"] as? TimeInterval
                        let speaker = segmentData["speaker"] as? String

                        segments.append(TextSegment(
                            text: text,
                            startTime: startTime,
                            endTime: endTime,
                            speaker: speaker
                        ))
                    }
                }

                // If no segments, create one from full text
                if segments.isEmpty {
                    segments.append(TextSegment(text: fullText))
                }

                return ParsedDocument(
                    sourceFileName: url.lastPathComponent,
                    documentType: .transcript,
                    fullText: fullText,
                    segments: segments
                )
            }
        } else if let segmentsArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            // Format 3: array of segments
            var segments: [TextSegment] = []
            var fullTextParts: [String] = []

            for segmentData in segmentsArray {
                let text = segmentData["text"] as? String ?? ""
                let startTime = segmentData["start"] as? TimeInterval
                let endTime = segmentData["end"] as? TimeInterval
                let speaker = segmentData["speaker"] as? String

                segments.append(TextSegment(
                    text: text,
                    startTime: startTime,
                    endTime: endTime,
                    speaker: speaker
                ))

                fullTextParts.append(text)
            }

            return ParsedDocument(
                sourceFileName: url.lastPathComponent,
                documentType: .transcript,
                fullText: fullTextParts.joined(separator: "\n\n"),
                segments: segments
            )
        }

        throw TranscriptParserError.invalidFileFormat
    }
}
