# Build 4: File Parsing Foundation

**Goal**: Parse real files into structured text (no LLM yet, just extraction)

**Estimated Effort**: 2-3 days

---

## Overview

Replace mocked summaries with real file parsing. Users will see **raw extracted text** in the summary detail panel (fullSummary field) instead of fake summaries, validating that file parsing works before adding LLM complexity.

**Scope Clarification**:
- ✅ **Text formats**: .txt, .vtt, .srt, .json (transcripts)
- ✅ **PDF only** for presentations (using built-in PDFKit)
- ❌ **PPTX deferred** to Build 8 (requires ZIPFoundation + XML parsing)
- ❌ **Keynote deferred** to Build 8 (requires export bridge or complex parsing)
- ❌ **No processing delay** - removed to show instant parsing results

---

## Features to Implement

### 1. Tabbed Summary Detail View

#### Update SummaryDetailView.swift
**Location**: `MeetingPrep/MeetingPrep/ContentView.swift` (SummaryDetailView)

Add tabs to switch between formatted summary and raw text:

```swift
struct SummaryDetailView: View {
    let document: Document
    let summary: Summary

    @State private var showingExportMenu = false
    @State private var copiedSection: String?
    @State private var selectedTab: SummaryTab = .summary  // NEW

    enum SummaryTab: String, CaseIterable {
        case summary = "Summary"
        case raw = "Raw Text"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with tabs and export button
            HStack {
                Picker("View", selection: $selectedTab) {
                    ForEach(SummaryTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                Spacer()

                // Export menu (existing)
                Menu {
                    // ... existing export buttons
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Content based on selected tab
            Group {
                switch selectedTab {
                case .summary:
                    formattedSummaryView
                case .raw:
                    rawTextView
                }
            }
        }
        .overlay(alignment: .top) {
            // Toast notification (existing)
            if copiedSection != nil {
                Text("Copied!")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.green.opacity(0.9))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Formatted Summary View (existing)

    private var formattedSummaryView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Document name
                Text(document.fileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Headline
                Text(summary.headline)
                    .font(.title)
                    .fontWeight(.semibold)

                Divider()

                // Key Points (with copy button)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Key Points")
                            .font(.headline)

                        Spacer()

                        Button {
                            copySection(summary.keyPoints.map { "• \($0)" }.joined(separator: "\n"))
                        } label: {
                            Image(systemName: copiedSection == "keyPoints" ? "checkmark" : "doc.on.doc")
                                .foregroundStyle(copiedSection == "keyPoints" ? .green : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Copy key points")
                    }

                    ForEach(summary.keyPoints, id: \.self) { point in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundStyle(.secondary)
                            Text(point)
                                .font(.body)
                        }
                    }
                }

                Divider()

                // Action Items (if any)
                if !summary.actionItems.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Action Items")
                                .font(.headline)

                            Spacer()

                            Button {
                                let text = summary.actionItems.map { item in
                                    var line = "☐ \(item.description)"
                                    if let assignee = item.assignee {
                                        line += " — \(assignee)"
                                    }
                                    if let deadline = item.deadline {
                                        line += " (Due: \(deadline))"
                                    }
                                    return line
                                }.joined(separator: "\n")
                                copySection(text, key: "actionItems")
                            } label: {
                                Image(systemName: copiedSection == "actionItems" ? "checkmark" : "doc.on.doc")
                                    .foregroundStyle(copiedSection == "actionItems" ? .green : .secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Copy action items")
                        }

                        ForEach(summary.actionItems) { item in
                            ActionItemRow(item: item)
                        }
                    }

                    Divider()
                }

                // Participants (if any)
                if !summary.participants.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Participants")
                            .font(.headline)

                        FlowLayout(spacing: 8) {
                            ForEach(summary.participants, id: \.self) { participant in
                                Text(participant)
                                    .font(.callout)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.accentColor.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    Divider()
                }

                // Full Summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Summary")
                        .font(.headline)

                    Text(summary.fullSummary)
                        .font(.body)
                        .lineSpacing(4)
                        .textSelection(.enabled)  // Allow selection
                }

                // Metadata
                Divider()

                HStack {
                    Text("Generated:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(summary.generatedAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(summary.generatedAt, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Raw Text View (NEW)

    private var rawTextView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // File info header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(document.fileName)
                            .font(.title3)
                            .fontWeight(.semibold)

                        HStack(spacing: 12) {
                            Label(document.fileType.displayName, systemImage: document.fileType.iconName)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Label(document.fileSizeFormatted, systemImage: "doc")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Label("\(summary.fullSummary.count) chars", systemImage: "text.alignleft")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Copy raw text button
                    Button {
                        copyRawText()
                    } label: {
                        Label("Copy", systemImage: copiedSection == "raw" ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(copiedSection == "raw" ? .green : .secondary)
                    }
                    .buttonStyle(.borderless)
                }

                Divider()

                // Raw extracted text (monospaced for better readability)
                Text(summary.fullSummary)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
    }

    // MARK: - Helper Methods

    private func copySection(_ text: String, key: String = "keyPoints") {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        withAnimation {
            copiedSection = key
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                copiedSection = nil
            }
        }
    }

    private func copyRawText() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(summary.fullSummary, forType: .string)

        withAnimation {
            copiedSection = "raw"
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                copiedSection = nil
            }
        }
    }

    private func showCopiedToast() {
        withAnimation {
            copiedSection = "all"
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                copiedSection = nil
            }
        }
    }
}
```

**Benefits**:
- ✅ **Summary tab**: Shows structured summary (headline, key points, participants, full summary)
- ✅ **Raw Text tab**: Shows unprocessed extracted text in monospaced font
- ✅ **Easy verification**: Switch between tabs to verify parsing worked correctly
- ✅ **Copy buttons**: Both tabs have copy functionality
- ✅ **Text selection**: Raw text is selectable for manual inspection

---

### 2. Core Parsing Infrastructure

#### TranscriptParser.swift
**Location**: `MeetingPrep/MeetingPrep/Services/Parsers/TranscriptParser.swift`

```swift
struct TranscriptParser {
    /// Parse plain text files (.txt)
    static func parsePlainText(from url: URL) throws -> ParsedDocument

    /// Parse VTT subtitle files (.vtt)
    static func parseVTT(from url: URL) throws -> ParsedDocument

    /// Parse SRT subtitle files (.srt)
    static func parseSRT(from url: URL) throws -> ParsedDocument

    /// Parse JSON transcripts (Zoom/Teams export)
    static func parseJSON(from url: URL) throws -> ParsedDocument
}
```

**Requirements**:
- Extract speaker names from VTT/SRT timestamps
- Parse JSON structure for Zoom/Teams format
- Handle malformed files gracefully
- Return uniform `ParsedDocument` structure

#### PresentationParser.swift
**Location**: `MeetingPrep/MeetingPrep/Services/Parsers/PresentationParser.swift`

```swift
struct PresentationParser {
    /// Extract text from PDF using PDFKit
    static func parsePDF(from url: URL) throws -> ParsedDocument
}
```

**Requirements**:
- Use `PDFKit` to extract text from each page
- Preserve page order
- Combine into single text document
- Handle encrypted/protected PDFs

#### ParsedDocument.swift
**Location**: `MeetingPrep/MeetingPrep/Models/ParsedDocument.swift`

```swift
struct ParsedDocument {
    let id: UUID
    let sourceFileName: String
    let documentType: DocumentType
    let fullText: String
    let segments: [TextSegment]
    let parsedAt: Date
}

struct TextSegment {
    let speaker: String?        // nil for presentations
    let content: String
    let timestamp: TimeInterval? // nil for presentations
    let pageNumber: Int?        // nil for transcripts
}
```

---

### 2. Integration with Existing Flow

#### Update MockSummarisationService.swift
**Location**: `MeetingPrep/MeetingPrep/Services/MockSummarisationService.swift`

Replace mocked summary generation with real file parsing:

```swift
@MainActor
class MockSummarisationService {
    // NO DELAY - instant parsing results

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

extension Array where Element: Hashable {
    func unique() -> [Element] {
        Array(Set(self))
    }
}
```

**Note**: The extension shows unique() helper for deduplicating speakers.
```

#### Update ProjectDetailView.swift
**Location**: `MeetingPrep/MeetingPrep/ContentView.swift` (ProjectDetailView)

Modify `handleImport` to pass file URL to summarization service:

```swift
private func handleImport(_ result: Result<[URL], Error>) async {
    guard case .success(let urls) = result else { return }

    for url in urls {
        // Start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to access file: \(url)")
            continue
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
        }

        // Generate summary with REAL FILE PARSING
        do {
            let summary = try await mockService.generateSummary(for: document, fileURL: url)
            summary.document = document
            document.summary = summary
            modelContext.insert(summary)
            try? modelContext.save()
        } catch {
            print("Failed to parse document: \(error)")
            // TODO: Show error to user in Build 8
        }

        // Remove from processing
        await MainActor.run {
            processingDocuments.remove(document.id)
        }
    }
}
```

---

## Unit Tests

### TranscriptParserTests.swift
**Location**: `MeetingPrepTests/Services/Parsers/TranscriptParserTests.swift`

```swift
import XCTest
@testable import MeetingPrep

final class TranscriptParserTests: XCTestCase {

    func testParsePlainText() throws {
        // Given: Sample .txt file
        let content = "This is a test transcript.\nWith multiple lines."
        let url = createTempFile(content: content, extension: "txt")

        // When: Parse
        let parsed = try TranscriptParser.parsePlainText(from: url)

        // Then: Verify structure
        XCTAssertEqual(parsed.fullText, content)
        XCTAssertEqual(parsed.documentType, .transcript)
    }

    func testParseVTT() throws {
        // Given: Sample VTT with timestamps and speakers
        let vtt = """
        WEBVTT

        00:00:00.000 --> 00:00:05.000
        <v Speaker 1>Hello everyone

        00:00:05.000 --> 00:00:10.000
        <v Speaker 2>Thanks for joining
        """
        let url = createTempFile(content: vtt, extension: "vtt")

        // When: Parse
        let parsed = try TranscriptParser.parseVTT(from: url)

        // Then: Verify segments
        XCTAssertEqual(parsed.segments.count, 2)
        XCTAssertEqual(parsed.segments[0].speaker, "Speaker 1")
        XCTAssertEqual(parsed.segments[0].content, "Hello everyone")
        XCTAssertEqual(parsed.segments[0].timestamp, 0.0)
    }

    func testParseSRT() throws {
        // Given: Sample SRT file
        let srt = """
        1
        00:00:00,000 --> 00:00:05,000
        First subtitle

        2
        00:00:05,000 --> 00:00:10,000
        Second subtitle
        """
        let url = createTempFile(content: srt, extension: "srt")

        // When: Parse
        let parsed = try TranscriptParser.parseSRT(from: url)

        // Then: Verify
        XCTAssertEqual(parsed.segments.count, 2)
        XCTAssertEqual(parsed.segments[0].content, "First subtitle")
    }

    func testParseInvalidFile() {
        // Given: Non-existent file
        let url = URL(fileURLWithPath: "/tmp/nonexistent.txt")

        // When/Then: Should throw
        XCTAssertThrowsError(try TranscriptParser.parsePlainText(from: url))
    }

    // Helper
    private func createTempFile(content: String, extension ext: String) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        try! content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
```

### PresentationParserTests.swift
**Location**: `MeetingPrepTests/Services/Parsers/PresentationParserTests.swift`

```swift
import XCTest
@testable import MeetingPrep

final class PresentationParserTests: XCTestCase {

    func testParsePDF() throws {
        // Given: Sample PDF file (create using PDFKit)
        let pdfURL = createSamplePDF(withText: "Test PDF Content")

        // When: Parse
        let parsed = try PresentationParser.parsePDF(from: pdfURL)

        // Then: Verify
        XCTAssertTrue(parsed.fullText.contains("Test PDF Content"))
        XCTAssertEqual(parsed.documentType, .presentation)
    }

    func testParseEmptyPDF() throws {
        // Given: Empty PDF
        let pdfURL = createSamplePDF(withText: "")

        // When: Parse
        let parsed = try PresentationParser.parsePDF(from: pdfURL)

        // Then: Should not crash
        XCTAssertNotNil(parsed)
    }

    // Helper to create test PDF
    private func createSamplePDF(withText text: String) -> URL {
        // Implementation using PDFKit to create test PDF
        // ...
    }
}
```

---

## Mock VTT Test Files

Create these test files for manual testing:

### 1. simple-meeting.vtt
```vtt
WEBVTT

00:00:00.000 --> 00:00:05.000
<v Sarah Chen>Good morning everyone. Let's start with the Q1 roadmap discussion.

00:00:05.000 --> 00:00:12.000
<v Mike Rodriguez>Thanks Sarah. I think we should prioritize Feature X for the March release.

00:00:12.000 --> 00:00:18.000
<v Alex Kim>Agreed. We'll need to hire two additional engineers to hit that deadline.

00:00:18.000 --> 00:00:25.000
<v Sarah Chen>Great point. Mike, can you draft the technical spec by Friday?

00:00:25.000 --> 00:00:30.000
<v Mike Rodriguez>Absolutely. I'll have it ready by end of week.
```

### 2. team-standup.vtt
```vtt
WEBVTT

00:00:00.000 --> 00:00:04.000
<v Jordan Taylor>Morning team. Quick standup. I'll go first.

00:00:04.000 --> 00:00:10.000
<v Jordan Taylor>Yesterday I finished the authentication module. Today I'm starting on the API integration.

00:00:10.000 --> 00:00:15.000
<v Pat Wilson>Nice work Jordan. I completed code review on three PRs yesterday.

00:00:15.000 --> 00:00:22.000
<v Pat Wilson>Today I'm focusing on the database migration. Should be done by EOD.

00:00:22.000 --> 00:00:28.000
<v Sam Lee>I'm blocked on the design assets. Can someone from design review the mockups?

00:00:28.000 --> 00:00:33.000
<v Jordan Taylor>I'll ping the design team after this call.

00:00:33.000 --> 00:00:37.000
<v Sam Lee>Thanks Jordan. That would be super helpful.
```

### 3. client-call.vtt
```vtt
WEBVTT

00:00:00.000 --> 00:00:06.000
<v Account Manager>Thank you for joining us today. We're excited to review Phase 1 results.

00:00:06.000 --> 00:00:12.000
<v Client Stakeholder>We're very pleased with the deliverables. Everything was on time and high quality.

00:00:12.000 --> 00:00:19.000
<v Project Lead>I'm glad to hear that. For Phase 2, we'd like to propose an expanded scope.

00:00:19.000 --> 00:00:25.000
<v Client Stakeholder>What are you thinking? We have budget for additional features.

00:00:25.000 --> 00:00:32.000
<v Project Lead>We recommend adding a mobile companion app. It would extend the platform to iOS and Android.

00:00:32.000 --> 00:00:38.000
<v Client Stakeholder>That sounds perfect. Send over an updated proposal and timeline.

00:00:38.000 --> 00:00:44.000
<v Account Manager>We'll have that to you by end of week. Let's schedule a follow-up for next Tuesday.
```

Save these to `test-files/` directory in your project for manual testing.

---

## Testing Strategy

### Manual Testing

1. **Plain Text (.txt)**:
   - Create `test.txt` with sample content
   - Import into app
   - **Verify**: Full text appears in "Summary" section (fullSummary field)
   - **Verify**: No processing delay (instant results)

2. **VTT Subtitle**:
   - Use `simple-meeting.vtt` from above
   - Import and verify speaker detection
   - **Verify**: Participants shows "Sarah Chen, Mike Rodriguez, Alex Kim"
   - **Verify**: Full VTT text appears in Summary section
   - **Verify**: Timestamps are preserved in segments

3. **VTT with Multiple Speakers**:
   - Use `team-standup.vtt`
   - **Verify**: All 3 speakers detected
   - **Verify**: Full transcript readable in Summary

4. **VTT Client Call**:
   - Use `client-call.vtt`
   - **Verify**: Professional dialogue parsed correctly
   - **Verify**: Speakers extracted

5. **PDF**:
   - Import simple text-based PDF
   - **Verify**: Text extraction works
   - Try multi-page PDF
   - **Verify**: All pages extracted in order

6. **Audio** (placeholder):
   - Import .m4a file
   - **Verify**: Placeholder message "[Audio transcription not yet implemented]" appears in Summary
   - **Verify**: No crash, graceful handling

7. **PPTX/Keynote** (should fail gracefully):
   - Import .pptx file
   - **Verify**: Either shows error OR treats as unsupported
   - Note: Full PPTX support in Build 8

### Integration Testing

Create `DocumentProcessingIntegrationTests.swift`:

```swift
func testEndToEndDocumentImport() async throws {
    // Given: Real transcript file
    let url = Bundle(for: Self.self).url(forResource: "sample", withExtension: "txt")!

    // When: Import through full pipeline
    let document = Document(fileName: "sample.txt", fileType: .transcript, fileSize: 1024)
    let summary = try await mockService.generateSummary(for: document, fileURL: url)

    // Then: Verify summary contains parsed content
    XCTAssertTrue(summary.fullSummary.count > 0)
    XCTAssertNotEqual(summary.headline, "") // Not using mocked data
}
```

---

## File Structure Changes

```
MeetingPrep/
├── MeetingPrep/
│   ├── Models/
│   │   └── ParsedDocument.swift          // NEW
│   └── Services/
│       ├── Parsers/                      // NEW FOLDER
│       │   ├── TranscriptParser.swift
│       │   └── PresentationParser.swift
│       └── MockSummarisationService.swift // MODIFIED
└── MeetingPrepTests/                     // NEW
    └── Services/
        └── Parsers/
            ├── TranscriptParserTests.swift
            └── PresentationParserTests.swift
```

---

## Acceptance Criteria

- ✅ `.txt` files are parsed and full text displayed in Summary section
- ✅ `.vtt` files extract speaker names and timestamps correctly
- ✅ `.srt` files are parsed correctly
- ✅ **PDF files** extract text from all pages (PPTX/Keynote deferred to Build 8)
- ✅ Audio files show placeholder message "[Audio transcription not yet implemented]"
- ✅ Invalid files show error (graceful failure)
- ✅ **No processing delay** - results appear instantly
- ✅ **Raw text visible** in fullSummary field in detail panel
- ✅ **Speakers extracted** and shown in Participants section (for VTT/SRT)
- ✅ Key points show file metadata (type, length, segment count)
- ✅ All parser unit tests pass
- ✅ Security-scoped file access works correctly

---

## Dependencies

- **PDFKit** (built-in macOS framework)
- **Foundation** (for file I/O and string parsing)

No new SPM packages required.

---

## Next Steps (Build 5)

After Build 4 is complete:
- LLM engine integration (MLX Swift)
- Real summarization for short documents
- Prompt template design
