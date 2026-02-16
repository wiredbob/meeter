# Build 8: PowerPoint & Production Polish

**Goal**: Complete PPTX parsing + production-ready error handling

**Estimated Effort**: 3-4 days

---

## Overview

Complete all file format support (PPTX) and add robust error handling, retry mechanisms, and user-friendly error messages. This makes the app production-ready.

---

## Features to Implement

### 1. PPTX Parsing

#### PresentationParser.swift (additions)
**Location**: `MeetingPrep/MeetingPrep/Services/Parsers/PresentationParser.swift`

```swift
import Foundation
import ZIPFoundation

extension PresentationParser {

    /// Parse PPTX file (ZIP containing XML)
    static func parsePPTX(from url: URL) throws -> ParsedDocument {
        // PPTX is a ZIP archive containing XML files
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw ParsingError.invalidFile
        }

        var slideTexts: [String] = []
        var slideNumber = 1

        // Extract text from each slide XML
        for entry in archive where entry.path.contains("ppt/slides/slide") && entry.path.hasSuffix(".xml") {
            var slideData = Data()
            _ = try archive.extract(entry) { data in
                slideData.append(data)
            }

            if let slideText = extractTextFromSlideXML(slideData) {
                slideTexts.append("Slide \(slideNumber):\n\(slideText)")
                slideNumber += 1
            }
        }

        let fullText = slideTexts.joined(separator: "\n\n")

        return ParsedDocument(
            id: UUID(),
            sourceFileName: url.lastPathComponent,
            documentType: .presentation,
            fullText: fullText,
            segments: slideTexts.enumerated().map { index, text in
                TextSegment(
                    speaker: nil,
                    content: text,
                    timestamp: nil,
                    pageNumber: index + 1
                )
            },
            parsedAt: Date()
        )
    }

    private static func extractTextFromSlideXML(_ data: Data) -> String? {
        // Parse XML and extract text from <a:t> tags
        guard let xml = try? XMLDocument(data: data, options: []) else {
            return nil
        }

        do {
            let textNodes = try xml.nodes(forXPath: "//a:t")
            let texts = textNodes.compactMap { $0.stringValue }
            return texts.joined(separator: " ")
        } catch {
            return nil
        }
    }
}

enum ParsingError: Error {
    case invalidFile
    case unsupportedFormat
    case fileNotReadable
    case corrupted
}
```

---

### 2. Error Handling Framework

#### ProcessingError.swift
**Location**: `MeetingPrep/MeetingPrep/Models/ProcessingError.swift`

```swift
import Foundation

enum ProcessingError: Error, LocalizedError {
    // File errors
    case fileNotFound(path: String)
    case fileNotReadable(path: String)
    case unsupportedFileType(extension: String)
    case fileCorrupted(fileName: String)

    // Model errors
    case modelNotLoaded
    case modelLoadFailed(reason: String)
    case insufficientMemory

    // Processing errors
    case parsingFailed(fileName: String, reason: String)
    case transcriptionFailed(reason: String)
    case summarizationFailed(reason: String)

    // Network errors (for model download)
    case networkUnavailable
    case downloadFailed(url: String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .fileNotReadable(let path):
            return "Cannot read file: \(path). Check permissions."
        case .unsupportedFileType(let ext):
            return "Unsupported file type: .\(ext)"
        case .fileCorrupted(let fileName):
            return "File appears to be corrupted: \(fileName)"

        case .modelNotLoaded:
            return "No AI model loaded. Please load a model in Settings."
        case .modelLoadFailed(let reason):
            return "Failed to load model: \(reason)"
        case .insufficientMemory:
            return "Insufficient memory to run AI model. Try closing other apps."

        case .parsingFailed(let fileName, let reason):
            return "Failed to parse \(fileName): \(reason)"
        case .transcriptionFailed(let reason):
            return "Audio transcription failed: \(reason)"
        case .summarizationFailed(let reason):
            return "Summarization failed: \(reason)"

        case .networkUnavailable:
            return "No internet connection available for model download."
        case .downloadFailed(let url):
            return "Failed to download from: \(url)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound, .fileNotReadable:
            return "Make sure the file exists and you have permission to read it."
        case .unsupportedFileType:
            return "Supported types: .txt, .vtt, .srt, .json, .pdf, .pptx, .m4a, .mp3, .wav"
        case .fileCorrupted:
            return "Try re-exporting or re-downloading the file."

        case .modelNotLoaded:
            return "Go to Settings (⌘,) and load an AI model."
        case .modelLoadFailed:
            return "Try downloading a different model or restarting the app."
        case .insufficientMemory:
            return "Close other apps and try again, or use a smaller model."

        case .parsingFailed:
            return "The file might be corrupted or in an unsupported format."
        case .transcriptionFailed:
            return "Try using a different audio file or check audio quality."
        case .summarizationFailed:
            return "Try processing a shorter document or restarting the app."

        case .networkUnavailable:
            return "Connect to the internet to download the model."
        case .downloadFailed:
            return "Check your internet connection and try again."
        }
    }
}
```

---

### 3. Retry Mechanism

#### RetryHelper.swift
**Location**: `MeetingPrep/MeetingPrep/Utilities/RetryHelper.swift`

```swift
import Foundation

struct RetryHelper {
    static func retry<T>(
        maxAttempts: Int = 3,
        delay: Duration = .seconds(1),
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                print("Attempt \(attempt) failed: \(error)")

                // Don't retry on certain errors
                if let processingError = error as? ProcessingError {
                    switch processingError {
                    case .fileNotFound, .unsupportedFileType, .fileCorrupted:
                        throw error  // Don't retry these
                    default:
                        break  // Retry other errors
                    }
                }

                if attempt < maxAttempts {
                    try await Task.sleep(for: delay)
                }
            }
        }

        throw lastError ?? ProcessingError.summarizationFailed(reason: "Max retries exceeded")
    }
}
```

---

### 4. Error UI

#### ErrorAlertView.swift
**Location**: `MeetingPrep/MeetingPrep/Views/ErrorAlertView.swift`

```swift
import SwiftUI

struct ErrorAlertView: View {
    let error: ProcessingError
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Processing Error")
                .font(.title2)
                .fontWeight(.semibold)

            Text(error.errorDescription ?? "An error occurred")
                .font(.body)
                .multilineTextAlignment(.center)

            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button("Dismiss") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)

                if let onRetry = onRetry {
                    Button("Retry") {
                        onRetry()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}
```

---

### 5. Update Processing Flow with Error Handling

#### ProjectDetailView (robust version)
**Location**: `MeetingPrep/MeetingPrep/ContentView.swift`

```swift
struct ProjectDetailView: View {
    // ... existing properties

    @State private var processingErrors: [UUID: ProcessingError] = [:]
    @State private var showingErrorFor: UUID?

    private func handleImport(_ result: Result<[URL], Error>) async {
        guard case .success(let urls) = result else { return }

        for url in urls {
            await processDocument(url: url)
        }
    }

    private func processDocument(url: URL) async {
        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to access security-scoped resource")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        // Create document
        let fileName = url.lastPathComponent
        let fileType = DocumentType.from(url: url)
        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0

        let document = Document(
            fileName: fileName,
            fileType: fileType,
            fileSize: Int64(fileSize)
        )
        document.project = project
        project.documents.append(document)
        modelContext.insert(document)
        try? modelContext.save()

        // Mark as processing
        await MainActor.run {
            processingDocuments.insert(document.id)
            processingProgress[document.id] = ProcessingState(
                phase: "Starting...",
                progress: 0.0
            )
        }

        // Process with retry
        do {
            try await RetryHelper.retry(maxAttempts: 3) {
                try await processDocumentInternal(document: document, url: url)
            }

            // Success - clear any previous errors
            await MainActor.run {
                processingErrors.removeValue(forKey: document.id)
            }

        } catch let error as ProcessingError {
            await MainActor.run {
                processingErrors[document.id] = error
                showingErrorFor = document.id
            }
        } catch {
            await MainActor.run {
                processingErrors[document.id] = .summarizationFailed(
                    reason: error.localizedDescription
                )
                showingErrorFor = document.id
            }
        }

        // Remove from processing
        await MainActor.run {
            processingDocuments.remove(document.id)
            processingProgress.removeValue(forKey: document.id)
        }
    }

    private func processDocumentInternal(document: Document, url: URL) async throws {
        // Parse file
        let parsed: ParsedDocument

        if document.fileType == .audio {
            // Audio transcription
            guard audioTranscriber.isModelLoaded else {
                throw ProcessingError.modelNotLoaded
            }

            parsed = try await transcribeAudio(url: url, fileName: document.fileName, documentId: document.id)

        } else {
            // Text/Presentation parsing
            parsed = try parseFile(url: url, type: document.fileType)
        }

        // Generate summary
        guard llmEngine.isLoaded else {
            throw ProcessingError.modelNotLoaded
        }

        let pipeline = SummarisationPipeline(llmEngine: llmEngine)
        let summary = try await pipeline.generateSummary(
            for: document,
            parsedContent: parsed
        ) { progress in
            Task { @MainActor in
                let adjustedProgress = document.fileType == .audio
                    ? 0.5 + (progress.percent * 0.5)
                    : progress.percent

                processingProgress[document.id] = ProcessingState(
                    phase: progress.phase.description,
                    progress: adjustedProgress
                )
            }
        }

        // Save
        await MainActor.run {
            summary.document = document
            document.summary = summary
            modelContext.insert(summary)
            try? modelContext.save()
        }
    }

    private func parseFile(url: URL, type: DocumentType) throws -> ParsedDocument {
        do {
            switch type {
            case .transcript:
                // Detect specific format
                let ext = url.pathExtension.lowercased()
                switch ext {
                case "txt":
                    return try TranscriptParser.parsePlainText(from: url)
                case "vtt":
                    return try TranscriptParser.parseVTT(from: url)
                case "srt":
                    return try TranscriptParser.parseSRT(from: url)
                case "json":
                    return try TranscriptParser.parseJSON(from: url)
                default:
                    return try TranscriptParser.parsePlainText(from: url)
                }

            case .presentation:
                let ext = url.pathExtension.lowercased()
                if ext == "pdf" {
                    return try PresentationParser.parsePDF(from: url)
                } else if ext == "pptx" {
                    return try PresentationParser.parsePPTX(from: url)
                } else {
                    throw ProcessingError.unsupportedFileType(extension: ext)
                }

            case .audio:
                throw ProcessingError.parsingFailed(
                    fileName: url.lastPathComponent,
                    reason: "Audio should be transcribed, not parsed"
                )
            }
        } catch let error as ParsingError {
            throw ProcessingError.parsingFailed(
                fileName: url.lastPathComponent,
                reason: error.localizedDescription
            )
        }
    }
}
```

#### Add Error Alert to View

```swift
var body: some View {
    VStack(spacing: 0) {
        // ... existing UI
    }
    .sheet(item: $showingErrorFor) { documentId in
        if let error = processingErrors[documentId],
           let document = project.documents.first(where: { $0.id == documentId }) {
            ErrorAlertView(
                error: error,
                onRetry: {
                    showingErrorFor = nil
                    Task {
                        await processDocument(url: /* saved URL */)
                    }
                },
                onDismiss: {
                    showingErrorFor = nil
                }
            )
        }
    }
}
```

---

## Unit Tests

### PPTXParsingTests.swift
**Location**: `MeetingPrepTests/Services/Parsers/PPTXParsingTests.swift`

```swift
import XCTest
@testable import MeetingPrep

final class PPTXParsingTests: XCTestCase {

    func testParsePPTX() throws {
        // Given: Sample PPTX file
        let pptxURL = createSamplePPTX()

        // When
        let parsed = try PresentationParser.parsePPTX(from: pptxURL)

        // Then
        XCTAssertFalse(parsed.fullText.isEmpty)
        XCTAssertGreaterThan(parsed.segments.count, 0)
        XCTAssertEqual(parsed.documentType, .presentation)
    }

    func testParseInvalidPPTX() {
        // Given: Invalid file
        let invalidURL = URL(fileURLWithPath: "/tmp/invalid.pptx")

        // When/Then
        XCTAssertThrowsError(try PresentationParser.parsePPTX(from: invalidURL))
    }

    private func createSamplePPTX() -> URL {
        // Create minimal PPTX for testing
        // ...
    }
}
```

### RetryHelperTests.swift
**Location**: `MeetingPrepTests/Utilities/RetryHelperTests.swift`

```swift
import XCTest
@testable import MeetingPrep

final class RetryHelperTests: XCTestCase {

    func testSuccessfulOperation() async throws {
        // Given
        var callCount = 0

        // When
        let result = try await RetryHelper.retry {
            callCount += 1
            return "success"
        }

        // Then
        XCTAssertEqual(result, "success")
        XCTAssertEqual(callCount, 1)
    }

    func testRetryOnFailure() async throws {
        // Given
        var callCount = 0

        // When
        let result = try await RetryHelper.retry(maxAttempts: 3) {
            callCount += 1
            if callCount < 3 {
                throw ProcessingError.summarizationFailed(reason: "Temporary failure")
            }
            return "success"
        }

        // Then
        XCTAssertEqual(result, "success")
        XCTAssertEqual(callCount, 3)
    }

    func testNoRetryOnPermanentFailure() async {
        // Given
        var callCount = 0

        // When/Then
        await XCTAssertThrowsErrorAsync {
            _ = try await RetryHelper.retry(maxAttempts: 3) {
                callCount += 1
                throw ProcessingError.fileNotFound(path: "/test")
            }
        }

        XCTAssertEqual(callCount, 1)  // Should not retry
    }
}
```

---

## Testing Strategy

### Manual Testing

1. **PPTX Parsing**:
   - Import simple PPTX (3 slides)
   - Verify all slide text extracted
   - Import complex PPTX (images, charts)
   - Verify text extraction works

2. **Error Scenarios**:
   - Import corrupted file → see error alert
   - Import without model → see "model not loaded" error
   - Click Retry → re-attempts processing

3. **Stress Testing**:
   - Import very large PPTX (100+ slides)
   - Import 10 documents simultaneously
   - Import while low on memory

4. **Edge Cases**:
   - Empty PPTX
   - PPTX with only images (no text)
   - Password-protected PPTX (should error gracefully)

---

## Dependencies

Add to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.18.0"),
    .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.9.0"),
    .package(url: "https://github.com/weichsel/ZIPFoundation", from: "0.9.0"),  // NEW
]
```

---

## File Structure Changes

```
MeetingPrep/
├── MeetingPrep/
│   ├── Models/
│   │   └── ProcessingError.swift        // NEW
│   ├── Utilities/
│   │   └── RetryHelper.swift            // NEW
│   └── Views/
│       └── ErrorAlertView.swift         // NEW
└── MeetingPrepTests/
    ├── Services/
    │   └── Parsers/
    │       └── PPTXParsingTests.swift
    └── Utilities/
        └── RetryHelperTests.swift
```

---

## Acceptance Criteria

- ✅ PPTX files are parsed correctly
- ✅ All file types now supported (.txt, .vtt, .srt, .json, .pdf, .pptx, .m4a, .mp3, .wav)
- ✅ Errors show user-friendly messages
- ✅ Retry mechanism works for transient failures
- ✅ Permanent errors don't retry
- ✅ Error alerts include recovery suggestions
- ✅ All unit tests pass
- ✅ Stress tests succeed
- ✅ App handles edge cases gracefully

---

## Production Readiness Checklist

- ✅ All file formats supported
- ✅ Error handling comprehensive
- ✅ User-friendly error messages
- ✅ Retry logic for transient failures
- ✅ Progress indicators for all operations
- ✅ Memory management (no leaks)
- ✅ Performance acceptable (long docs process in reasonable time)
- ✅ Settings UI complete
- ✅ Keyboard shortcuts work
- ✅ Unit test coverage >80%

---

## Known Limitations

- No speaker diarization (WhisperKit limitation)
- English-only transcription
- No PDF OCR (text-based PDFs only)
- No Keynote parsing (would require export-to-PDF bridge)
- Simple chunking strategy (could use semantic chunking)

---

## Future Enhancements (Post-Phase 2)

- Keynote file support
- Speaker diarization (via external service)
- Multi-language support
- OCR for scanned PDFs
- Real-time recording
- Calendar integration
- Tags and search
- Export templates
- Custom prompts

---

## Phase 2 Complete! 🎉

All Phase 2 builds implemented:
- ✅ **Build 4**: File parsing
- ✅ **Build 5**: LLM engine
- ✅ **Build 6**: Chunking & map-reduce
- ✅ **Build 7**: Audio transcription
- ✅ **Build 8**: PPTX & polish

**Total Time**: ~14-19 days

App is now production-ready for local AI-powered meeting summarization!
