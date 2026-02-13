# Build 6: Document Chunking & Map-Reduce

**Goal**: Handle long documents with chunked summarization

**Estimated Effort**: 3-4 days

---

## Overview

Enable processing of long documents (1+ hour meetings) by splitting into chunks, summarizing each chunk, then combining into final summary. Add progress tracking so users can see processing status.

---

## Features to Implement

### 1. Document Chunker

#### DocumentChunker.swift
**Location**: `MeetingPrep/MeetingPrep/Services/LLM/DocumentChunker.swift`

```swift
import Foundation

struct DocumentChunk {
    let id: UUID
    let index: Int
    let content: String
    let estimatedTokens: Int
    let metadata: ChunkMetadata
}

struct ChunkMetadata {
    let startLine: Int?
    let endLine: Int?
    let speakers: [String]
}

class DocumentChunker {
    private let maxTokensPerChunk: Int
    private let overlapTokens: Int  // Overlap between chunks for context

    init(maxTokensPerChunk: Int = 3500, overlapTokens: Int = 200) {
        self.maxTokensPerChunk = maxTokensPerChunk
        self.overlapTokens = overlapTokens
    }

    /// Split document into chunks
    func chunk(_ document: ParsedDocument) -> [DocumentChunk] {
        let fullText = document.fullText
        let estimatedTotalTokens = LLMEngine.estimateTokenCount(fullText)

        // If document fits in single chunk, return as-is
        if estimatedTotalTokens <= maxTokensPerChunk {
            return [createSingleChunk(from: document)]
        }

        // Split by paragraphs/segments first
        let segments = splitIntoSegments(fullText)

        var chunks: [DocumentChunk] = []
        var currentChunk: [String] = []
        var currentTokenCount = 0
        var chunkIndex = 0

        for segment in segments {
            let segmentTokens = LLMEngine.estimateTokenCount(segment)

            // If adding this segment exceeds limit, finalize current chunk
            if currentTokenCount + segmentTokens > maxTokensPerChunk && !currentChunk.isEmpty {
                chunks.append(createChunk(
                    from: currentChunk,
                    index: chunkIndex,
                    speakers: extractSpeakers(from: currentChunk)
                ))
                chunkIndex += 1

                // Add overlap from previous chunk
                currentChunk = [currentChunk.suffix(2).joined(separator: "\n")]
                currentTokenCount = LLMEngine.estimateTokenCount(currentChunk[0])
            }

            currentChunk.append(segment)
            currentTokenCount += segmentTokens
        }

        // Add final chunk
        if !currentChunk.isEmpty {
            chunks.append(createChunk(
                from: currentChunk,
                index: chunkIndex,
                speakers: extractSpeakers(from: currentChunk)
            ))
        }

        return chunks
    }

    private func splitIntoSegments(_ text: String) -> [String] {
        // Split by double newlines (paragraphs) or speaker changes
        return text.components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func createSingleChunk(from document: ParsedDocument) -> DocumentChunk {
        DocumentChunk(
            id: UUID(),
            index: 0,
            content: document.fullText,
            estimatedTokens: LLMEngine.estimateTokenCount(document.fullText),
            metadata: ChunkMetadata(
                startLine: nil,
                endLine: nil,
                speakers: document.segments.compactMap { $0.speaker }.uniqued()
            )
        )
    }

    private func createChunk(from lines: [String], index: Int, speakers: [String]) -> DocumentChunk {
        let content = lines.joined(separator: "\n")
        return DocumentChunk(
            id: UUID(),
            index: index,
            content: content,
            estimatedTokens: LLMEngine.estimateTokenCount(content),
            metadata: ChunkMetadata(
                startLine: nil,
                endLine: nil,
                speakers: speakers
            )
        )
    }

    private func extractSpeakers(from lines: [String]) -> [String] {
        // Simple speaker detection (format: "Speaker Name: text")
        let speakerPattern = /^([A-Z][a-z]+(?: [A-Z][a-z]+)*): /
        var speakers: [String] = []

        for line in lines {
            if let match = line.firstMatch(of: speakerPattern) {
                speakers.append(String(match.1))
            }
        }

        return speakers.uniqued()
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
```

---

### 2. Summarisation Pipeline (Map-Reduce)

#### SummarisationPipeline.swift
**Location**: `MeetingPrep/MeetingPrep/Services/LLM/SummarisationPipeline.swift`

```swift
import Foundation

@MainActor
class SummarisationPipeline {
    private let llmEngine: LLMEngine
    private let chunker: DocumentChunker

    init(llmEngine: LLMEngine, chunker: DocumentChunker = DocumentChunker()) {
        self.llmEngine = llmEngine
        self.chunker = chunker
    }

    /// Generate summary with progress tracking
    func generateSummary(
        for document: Document,
        parsedContent: ParsedDocument,
        onProgress: @escaping (Progress) -> Void
    ) async throws -> Summary {
        // Chunk document
        let chunks = chunker.chunk(parsedContent)
        onProgress(Progress(phase: .chunking, currentChunk: 0, totalChunks: chunks.count, percent: 0))

        // MAP: Summarize each chunk
        var chunkSummaries: [String] = []

        for (index, chunk) in chunks.enumerated() {
            onProgress(Progress(
                phase: .summarizingChunks,
                currentChunk: index + 1,
                totalChunks: chunks.count,
                percent: Double(index) / Double(chunks.count)
            ))

            let chunkSummary = try await summarizeChunk(chunk)
            chunkSummaries.append(chunkSummary)
        }

        // REDUCE: Combine chunk summaries into final summary
        onProgress(Progress(phase: .combiningResults, currentChunk: chunks.count, totalChunks: chunks.count, percent: 0.9))

        let finalSummary = try await combineChunkSummaries(chunkSummaries, documentType: document.fileType)

        onProgress(Progress(phase: .complete, currentChunk: chunks.count, totalChunks: chunks.count, percent: 1.0))

        return finalSummary
    }

    private func summarizeChunk(_ chunk: DocumentChunk) async throws -> String {
        let prompt = PromptTemplates.chunkSummarizationPrompt(
            content: chunk.content,
            chunkIndex: chunk.index
        )

        return try await llmEngine.generate(
            prompt: prompt,
            maxTokens: 512,
            temperature: 0.3
        )
    }

    private func combineChunkSummaries(
        _ summaries: [String],
        documentType: DocumentType
    ) async throws -> Summary {
        let combinedText = summaries.enumerated()
            .map { "Section \($0.offset + 1):\n\($0.element)" }
            .joined(separator: "\n\n")

        let finalPrompt = PromptTemplates.finalSummarizationPrompt(
            chunkSummaries: combinedText,
            documentType: documentType
        )

        let response = try await llmEngine.generate(
            prompt: finalPrompt,
            maxTokens: 1024,
            temperature: 0.3
        )

        return try parseSummaryJSON(response)
    }

    private func parseSummaryJSON(_ jsonString: String) throws -> Summary {
        // Extract JSON from response (LLM might add extra text)
        let jsonStart = jsonString.firstIndex(of: "{") ?? jsonString.startIndex
        let jsonEnd = jsonString.lastIndex(of: "}") ?? jsonString.endIndex
        let jsonSubstring = jsonString[jsonStart...jsonEnd]

        let data = Data(jsonSubstring.utf8)
        let decoder = JSONDecoder()
        let summaryData = try decoder.decode(SummaryData.self, from: data)

        return Summary(
            headline: summaryData.headline,
            keyPoints: summaryData.keyPoints,
            actionItems: summaryData.actionItems,
            participants: summaryData.participants,
            fullSummary: summaryData.fullSummary
        )
    }
}

struct Progress {
    enum Phase {
        case chunking
        case summarizingChunks
        case combiningResults
        case complete
    }

    let phase: Phase
    let currentChunk: Int
    let totalChunks: Int
    let percent: Double
}

private struct SummaryData: Codable {
    let headline: String
    let keyPoints: [String]
    let actionItems: [ActionItem]
    let participants: [String]
    let fullSummary: String
}
```

---

### 3. Update Prompt Templates

#### PromptTemplates.swift (additions)
**Location**: `MeetingPrep/MeetingPrep/Services/LLM/PromptTemplates.swift`

Add chunk-specific prompts:

```swift
extension PromptTemplates {

    /// Prompt for summarizing a single chunk
    static func chunkSummarizationPrompt(content: String, chunkIndex: Int) -> String {
        return """
        You are summarizing part \(chunkIndex + 1) of a longer meeting transcript.

        Provide a brief summary of the key points discussed in this section. \
        Focus on:
        - Main topics discussed
        - Important decisions or conclusions
        - Any action items mentioned
        - Speakers involved

        Respond with 2-3 concise paragraphs.

        ---
        \(content)
        ---
        """
    }

    /// Prompt for combining chunk summaries
    static func finalSummarizationPrompt(chunkSummaries: String, documentType: DocumentType) -> String {
        return """
        \(systemPrompt)

        You have already summarized individual sections of a meeting. Now combine these \
        section summaries into a final, cohesive summary.

        Section summaries:
        ---
        \(chunkSummaries)
        ---

        Create a final summary that:
        - Synthesizes all sections into a coherent narrative
        - Extracts all key points across all sections
        - Consolidates all action items
        - Lists all participants mentioned
        - Provides a complete headline

        Respond ONLY with valid JSON matching the schema.
        """
    }
}
```

---

### 4. Progress UI

#### Update ProjectDetailView
**Location**: `MeetingPrep/MeetingPrep/ContentView.swift`

```swift
struct ProjectDetailView: View {
    // ... existing properties

    @State private var processingProgress: [UUID: ProcessingState] = [:]

    private func handleImport(_ result: Result<[URL], Error>) async {
        guard case .success(let urls) = result else { return }

        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
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

            // Generate summary with progress
            do {
                let parsed = try parseFile(url: url, type: fileType)

                if llmEngine.isLoaded {
                    let pipeline = SummarisationPipeline(llmEngine: llmEngine)
                    let summary = try await pipeline.generateSummary(
                        for: document,
                        parsedContent: parsed
                    ) { progress in
                        Task { @MainActor in
                            processingProgress[document.id] = ProcessingState(
                                phase: progress.phase.description,
                                progress: progress.percent
                            )
                        }
                    }

                    summary.document = document
                    document.summary = summary
                    modelContext.insert(summary)
                } else {
                    // Fallback to mock
                    let summary = try await mockService.generateSummary(for: document, fileURL: url)
                    summary.document = document
                    document.summary = summary
                    modelContext.insert(summary)
                }

                try? modelContext.save()
            } catch {
                print("Failed to process document: \(error)")
            }

            // Remove from processing
            await MainActor.run {
                processingDocuments.remove(document.id)
                processingProgress.removeValue(forKey: document.id)
            }
        }
    }
}

struct ProcessingState {
    let phase: String
    let progress: Double
}

extension Progress.Phase {
    var description: String {
        switch self {
        case .chunking: return "Preparing..."
        case .summarizingChunks: return "Summarizing..."
        case .combiningResults: return "Finalizing..."
        case .complete: return "Complete"
        }
    }
}
```

#### Update DocumentRow to show progress

```swift
struct DocumentRow: View {
    let document: Document
    let isProcessing: Bool
    let progress: ProcessingState?  // NEW

    var body: some View {
        HStack(spacing: 12) {
            // ... existing icon

            VStack(alignment: .leading, spacing: 4) {
                Text(document.fileName)
                    .font(.body)
                    .lineLimit(1)

                if isProcessing, let progress = progress {
                    HStack(spacing: 8) {
                        Text(progress.phase)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if progress.progress > 0 {
                            Text("\(Int(progress.progress * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    // ... existing metadata
                }
            }

            Spacer()

            // Processing indicator with progress
            if isProcessing {
                if let progress = progress, progress.progress > 0 {
                    ProgressView(value: progress.progress)
                        .frame(width: 40)
                } else {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 20, height: 20)
                }
            } else if document.isProcessed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            }
        }
        .padding(.vertical, 4)
    }
}
```

---

## Unit Tests

### DocumentChunkerTests.swift
**Location**: `MeetingPrepTests/Services/LLM/DocumentChunkerTests.swift`

```swift
import XCTest
@testable import MeetingPrep

final class DocumentChunkerTests: XCTestCase {

    func testSingleChunkDocument() {
        // Given: Small document
        let doc = createParsedDocument(wordCount: 500)
        let chunker = DocumentChunker(maxTokensPerChunk: 3500)

        // When
        let chunks = chunker.chunk(doc)

        // Then
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0].index, 0)
    }

    func testMultiChunkDocument() {
        // Given: Large document (10,000 words ~= 12,500 tokens)
        let doc = createParsedDocument(wordCount: 10000)
        let chunker = DocumentChunker(maxTokensPerChunk: 3500)

        // When
        let chunks = chunker.chunk(doc)

        // Then
        XCTAssertGreaterThan(chunks.count, 1)
        XCTAssertEqual(chunks[0].index, 0)
        XCTAssertEqual(chunks[1].index, 1)

        // Verify no chunk exceeds limit
        for chunk in chunks {
            XCTAssertLessThanOrEqual(chunk.estimatedTokens, 3700) // Allow small overage
        }
    }

    func testChunkOverlap() {
        // Given: Document requiring 3 chunks
        let doc = createParsedDocument(wordCount: 12000)
        let chunker = DocumentChunker(maxTokensPerChunk: 3500, overlapTokens: 200)

        // When
        let chunks = chunker.chunk(doc)

        // Then: Should have overlap content
        XCTAssertGreaterThanOrEqual(chunks.count, 3)
    }

    private func createParsedDocument(wordCount: Int) -> ParsedDocument {
        let words = Array(repeating: "word", count: wordCount)
        let text = words.joined(separator: " ")

        return ParsedDocument(
            id: UUID(),
            sourceFileName: "test.txt",
            documentType: .transcript,
            fullText: text,
            segments: [],
            parsedAt: Date()
        )
    }
}
```

### SummarisationPipelineTests.swift
**Location**: `MeetingPrepTests/Services/LLM/SummarisationPipelineTests.swift`

```swift
import XCTest
@testable import MeetingPrep

final class SummarisationPipelineTests: XCTestCase {

    func testProgressCallbacks() async throws {
        // Given: Mock LLM engine
        let mockEngine = MockLLMEngine()
        let pipeline = SummarisationPipeline(llmEngine: mockEngine)

        let doc = Document(fileName: "test.txt", fileType: .transcript, fileSize: 1024)
        let parsed = createLargeParsedDocument()

        var progressUpdates: [Progress] = []

        // When
        _ = try await pipeline.generateSummary(for: doc, parsedContent: parsed) { progress in
            progressUpdates.append(progress)
        }

        // Then
        XCTAssertGreaterThan(progressUpdates.count, 0)
        XCTAssertEqual(progressUpdates.last?.phase, .complete)
    }

    private func createLargeParsedDocument() -> ParsedDocument {
        // 15,000 word document
        let words = Array(repeating: "test", count: 15000)
        return ParsedDocument(
            id: UUID(),
            sourceFileName: "large.txt",
            documentType: .transcript,
            fullText: words.joined(separator: " "),
            segments: [],
            parsedAt: Date()
        )
    }
}
```

---

## Testing Strategy

### Manual Testing

1. **Short Document** (single chunk):
   - Import 500-word transcript
   - Verify no chunking occurs
   - Check progress indicator

2. **Long Document** (multiple chunks):
   - Import 5000-word transcript
   - Watch progress: "Summarizing... 25%", "50%", etc.
   - Verify final summary combines all chunks

3. **Very Long Document**:
   - Import 10,000+ word transcript
   - Verify chunking works
   - Check that key points from all sections appear

4. **Progress UI**:
   - Verify progress percentage updates
   - Check phase labels ("Preparing...", "Summarizing...", "Finalizing...")

---

## Acceptance Criteria

- ✅ Documents >3000 tokens are split into chunks
- ✅ Each chunk is summarized independently
- ✅ Chunk summaries are combined into final summary
- ✅ Progress callbacks fire at each stage
- ✅ UI shows progress percentage and phase
- ✅ All unit tests pass
- ✅ Long documents (10K+ words) process successfully
- ✅ Final summary is coherent and complete

---

## Known Limitations

- Audio transcription still placeholder (Build 7)
- No retry on chunk failure (Build 8)
- Simple paragraph-based chunking (could improve with semantic chunking)

---

## Next Steps (Build 7)

After Build 6 is complete:
- WhisperKit integration for audio transcription
- Two-stage progress (transcribe → summarize)
- Audio format support
