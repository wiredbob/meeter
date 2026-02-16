# Build 7: Audio Transcription (WhisperKit)

**Goal**: Transcribe audio files to text using WhisperKit

**Estimated Effort**: 3-4 days

---

## Overview

Add on-device audio transcription using WhisperKit. Users can import audio recordings (.m4a, .mp3, .wav) and get automatic transcription followed by summarization.

---

## Features to Implement

### 1. Audio Transcriber

#### AudioTranscriber.swift
**Location**: `MeetingPrep/MeetingPrep/Services/Audio/AudioTranscriber.swift`

```swift
import Foundation
import WhisperKit

@MainActor
class AudioTranscriber {
    private var whisperKit: WhisperKit?
    private(set) var isModelLoaded = false

    enum TranscriptionError: Error {
        case modelNotLoaded
        case audioFileInvalid
        case transcriptionFailed
    }

    /// Load Whisper model (one-time setup)
    func loadModel(modelVariant: String = "base") async throws {
        whisperKit = try await WhisperKit(model: modelVariant)
        isModelLoaded = true
    }

    /// Transcribe audio file with progress
    func transcribe(
        audioURL: URL,
        onProgress: @escaping (TranscriptionProgress) -> Void
    ) async throws -> TranscriptionResult {
        guard let whisperKit = whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }

        // Validate audio file
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw TranscriptionError.audioFileInvalid
        }

        onProgress(TranscriptionProgress(phase: .loading, percent: 0.0))

        // Transcribe with progress callback
        let result = try await whisperKit.transcribe(
            audioPath: audioURL.path,
            decodeOptions: DecodeOptions(
                task: .transcribe,
                language: "en",
                temperature: 0.0,
                skipSpecialTokens: true
            )
        ) { progress in
            Task { @MainActor in
                onProgress(TranscriptionProgress(
                    phase: .transcribing,
                    percent: Double(progress.fractionCompleted)
                ))
            }
        }

        onProgress(TranscriptionProgress(phase: .complete, percent: 1.0))

        return TranscriptionResult(
            text: result.text,
            segments: result.segments.map { segment in
                TranscriptSegment(
                    text: segment.text,
                    startTime: segment.start,
                    endTime: segment.end,
                    speaker: nil  // WhisperKit doesn't do speaker diarization
                )
            }
        )
    }
}

struct TranscriptionProgress {
    enum Phase {
        case loading
        case transcribing
        case complete
    }

    let phase: Phase
    let percent: Double
}

struct TranscriptionResult {
    let text: String
    let segments: [TranscriptSegment]
}

struct TranscriptSegment {
    let text: String
    let startTime: Double
    let endTime: Double
    let speaker: String?
}
```

---

### 2. Update ParsedDocument for Audio

#### ParsedDocument.swift (modifications)
**Location**: `MeetingPrep/MeetingPrep/Models/ParsedDocument.swift`

```swift
extension ParsedDocument {
    /// Create from audio transcription result
    static func fromAudioTranscription(
        _ transcription: TranscriptionResult,
        sourceFileName: String
    ) -> ParsedDocument {
        ParsedDocument(
            id: UUID(),
            sourceFileName: sourceFileName,
            documentType: .audio,
            fullText: transcription.text,
            segments: transcription.segments.map { segment in
                TextSegment(
                    speaker: segment.speaker,
                    content: segment.text,
                    timestamp: segment.startTime,
                    pageNumber: nil
                )
            },
            parsedAt: Date()
        )
    }
}
```

---

### 3. Two-Stage Processing (Transcribe → Summarize)

#### Update ProjectDetailView
**Location**: `MeetingPrep/MeetingPrep/ContentView.swift`

```swift
struct ProjectDetailView: View {
    // ... existing properties

    @State private var audioTranscriber = AudioTranscriber()

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

            // Process based on file type
            do {
                let parsed: ParsedDocument

                if fileType == .audio {
                    // AUDIO: Two-stage process (transcribe → summarize)
                    parsed = try await transcribeAudio(url: url, fileName: fileName, documentId: document.id)
                } else {
                    // TEXT/PDF: Direct parsing
                    parsed = try parseFile(url: url, type: fileType)
                }

                // Generate summary
                if llmEngine.isLoaded {
                    let pipeline = SummarisationPipeline(llmEngine: llmEngine)
                    let summary = try await pipeline.generateSummary(
                        for: document,
                        parsedContent: parsed
                    ) { progress in
                        Task { @MainActor in
                            // Adjust progress for audio (0-50% transcription, 50-100% summarization)
                            let adjustedProgress = fileType == .audio
                                ? 0.5 + (progress.percent * 0.5)
                                : progress.percent

                            processingProgress[document.id] = ProcessingState(
                                phase: progress.phase.description,
                                progress: adjustedProgress
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
                // TODO: Show error in UI
            }

            // Remove from processing
            await MainActor.run {
                processingDocuments.remove(document.id)
                processingProgress.removeValue(forKey: document.id)
            }
        }
    }

    private func transcribeAudio(
        url: URL,
        fileName: String,
        documentId: UUID
    ) async throws -> ParsedDocument {
        // Load Whisper model if needed
        if !audioTranscriber.isModelLoaded {
            await MainActor.run {
                processingProgress[documentId] = ProcessingState(
                    phase: "Loading transcription model...",
                    progress: 0.0
                )
            }
            try await audioTranscriber.loadModel(modelVariant: "base")
        }

        // Transcribe
        let transcription = try await audioTranscriber.transcribe(audioURL: url) { progress in
            Task { @MainActor in
                let phase = progress.phase == .transcribing ? "Transcribing audio..." : "Loading..."
                processingProgress[documentId] = ProcessingState(
                    phase: phase,
                    progress: progress.percent * 0.5  // 0-50% for transcription
                )
            }
        }

        return .fromAudioTranscription(transcription, sourceFileName: fileName)
    }

    private func parseFile(url: URL, type: DocumentType) throws -> ParsedDocument {
        switch type {
        case .transcript:
            return try TranscriptParser.parse(from: url)
        case .presentation:
            return try PresentationParser.parsePDF(from: url)
        case .audio:
            fatalError("Audio should be handled by transcribeAudio()")
        }
    }
}
```

---

### 4. Settings: Whisper Model Selection

#### Update SettingsView.swift
**Location**: `MeetingPrep/MeetingPrep/Views/SettingsView.swift`

```swift
struct SettingsView: View {
    @State private var modelPath: String = ""
    @State private var isLoadingModel = false
    @State private var loadError: String?

    @State private var whisperModel: String = "base"
    @State private var isLoadingWhisper = false

    let llmEngine: LLMEngine
    let audioTranscriber: AudioTranscriber

    var body: some View {
        Form {
            Section("LLM Model") {
                // ... existing LLM settings
            }

            Section("Audio Transcription") {
                Picker("Whisper Model", selection: $whisperModel) {
                    Text("Tiny (fastest, least accurate)").tag("tiny")
                    Text("Base (balanced)").tag("base")
                    Text("Small (better quality)").tag("small")
                    Text("Medium (best quality, slow)").tag("medium")
                }

                if audioTranscriber.isModelLoaded {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Whisper model loaded")
                            .font(.caption)
                    }
                }

                Button("Preload Whisper Model") {
                    Task {
                        await loadWhisperModel()
                    }
                }
                .disabled(isLoadingWhisper)
            }

            Section("Info") {
                Text("Whisper models are downloaded automatically on first use.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 400)
    }

    private func loadWhisperModel() async {
        isLoadingWhisper = true
        do {
            try await audioTranscriber.loadModel(modelVariant: whisperModel)
        } catch {
            loadError = "Failed to load Whisper: \(error.localizedDescription)"
        }
        isLoadingWhisper = false
    }
}
```

---

## Unit Tests

### AudioTranscriberTests.swift
**Location**: `MeetingPrepTests/Services/Audio/AudioTranscriberTests.swift`

```swift
import XCTest
@testable import MeetingPrep

final class AudioTranscriberTests: XCTestCase {

    func testLoadModel() async throws {
        // Given
        let transcriber = AudioTranscriber()

        // When
        try await transcriber.loadModel(modelVariant: "tiny")

        // Then
        XCTAssertTrue(transcriber.isModelLoaded)
    }

    func testTranscribeWithoutModel() async {
        // Given
        let transcriber = AudioTranscriber()
        let audioURL = URL(fileURLWithPath: "/tmp/test.m4a")

        // When/Then
        await XCTAssertThrowsErrorAsync {
            _ = try await transcriber.transcribe(audioURL: audioURL) { _ in }
        }
    }

    func testTranscribeInvalidFile() async throws {
        // Given
        let transcriber = AudioTranscriber()
        try await transcriber.loadModel(modelVariant: "tiny")
        let invalidURL = URL(fileURLWithPath: "/nonexistent.m4a")

        // When/Then
        await XCTAssertThrowsErrorAsync {
            _ = try await transcriber.transcribe(audioURL: invalidURL) { _ in }
        }
    }
}
```

---

## Integration Tests (Requires Audio Samples)

### AudioTranscriptionIntegrationTests.swift
**Location**: `MeetingPrepTests/Integration/AudioTranscriptionIntegrationTests.swift`

```swift
import XCTest
@testable import MeetingPrep

final class AudioTranscriptionIntegrationTests: XCTestCase {

    func testTranscribeShortAudio() async throws {
        // Given
        let transcriber = AudioTranscriber()
        try await transcriber.loadModel(modelVariant: "tiny")

        // Test audio file (10 seconds of "Hello, this is a test")
        let audioURL = Bundle(for: Self.self).url(forResource: "test_audio", withExtension: "m4a")!

        var progressUpdates: [TranscriptionProgress] = []

        // When
        let result = try await transcriber.transcribe(audioURL: audioURL) { progress in
            progressUpdates.append(progress)
        }

        // Then
        XCTAssertFalse(result.text.isEmpty)
        XCTAssertGreaterThan(result.segments.count, 0)
        XCTAssertGreaterThan(progressUpdates.count, 0)
        XCTAssertEqual(progressUpdates.last?.phase, .complete)
    }
}
```

---

## Testing Strategy

### Manual Testing

1. **Download Whisper Model**:
   - Open Settings
   - Select "Base" model
   - Click "Preload Whisper Model"
   - Verify download completes (~150 MB)

2. **Import Short Audio** (30 seconds):
   - Import .m4a file
   - Watch progress: "Transcribing audio... 25%"
   - Then: "Summarizing... 75%"
   - Verify transcript appears in summary

3. **Import Long Audio** (5 minutes):
   - Import longer recording
   - Verify chunking + summarization works
   - Check that timestamps are preserved

4. **Test Different Formats**:
   - .m4a (AAC)
   - .mp3 (MP3)
   - .wav (PCM)

5. **Error Handling**:
   - Import corrupted audio → verify error
   - Import without model loaded → verify auto-load

---

## Dependencies

Add to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.18.0"),
    .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.9.0"),
]
```

Update entitlements for audio file access (already have read-write).

---

## File Structure Changes

```
MeetingPrep/
├── MeetingPrep/
│   └── Services/
│       └── Audio/                        // NEW FOLDER
│           └── AudioTranscriber.swift
└── MeetingPrepTests/
    ├── Services/
    │   └── Audio/
    │       └── AudioTranscriberTests.swift
    └── Integration/
        └── AudioTranscriptionIntegrationTests.swift
```

---

## Acceptance Criteria

- ✅ Whisper model can be selected and loaded
- ✅ Audio files (.m4a, .mp3, .wav) are transcribed
- ✅ Transcription progress is shown (0-50%)
- ✅ Summarization progress follows (50-100%)
- ✅ Final summary includes transcribed text
- ✅ Timestamps are preserved in segments
- ✅ All unit tests pass
- ✅ Integration test with real audio passes
- ✅ User sees complete audio → transcript → summary flow

---

## Known Limitations

- No speaker diarization (WhisperKit doesn't support it)
- English only (can add language detection later)
- Large audio files (>1 hour) may take several minutes
- No offline model download (downloads on first use)

---

## Performance Considerations

| Model | Size | Speed (realtime factor) | Quality |
|-------|------|-------------------------|---------|
| Tiny  | ~40 MB | 5-10x realtime | Basic |
| Base  | ~150 MB | 3-5x realtime | Good |
| Small | ~500 MB | 1-2x realtime | Better |
| Medium | ~1.5 GB | 0.5-1x realtime | Best |

Recommend **Base** as default (good balance).

---

## Next Steps (Build 8)

After Build 7 is complete:
- PPTX parsing (ZIPFoundation)
- Robust error handling
- Retry mechanisms
- Settings UI polish
- Production-ready edge cases
