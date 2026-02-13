# Build 5: LLM Engine (Single Chunk)

**Goal**: Run local LLM inference on short documents (no chunking yet)

**Estimated Effort**: 3-4 days

---

## Overview

Replace parsed text display with **real AI-generated summaries** for short documents. This validates the LLM pipeline works before tackling chunking complexity.

---

## Features to Implement

### 1. LLM Engine

#### LLMEngine.swift
**Location**: `MeetingPrep/MeetingPrep/Services/LLM/LLMEngine.swift`

```swift
import MLX
import MLXLLM
import MLXRandom

@Observable
class LLMEngine {
    private var model: MLXLLM.Model?
    private(set) var isLoaded = false
    private(set) var modelName: String?

    enum LoadError: Error {
        case modelNotFound
        case invalidModelFormat
        case insufficientMemory
    }

    /// Load model from Application Support or bundle
    func loadModel(modelPath: String) async throws {
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw LoadError.modelNotFound
        }

        // Load MLX model
        let modelConfiguration = ModelConfiguration(id: modelPath)
        model = try await MLXLLM.Model.load(configuration: modelConfiguration)

        isLoaded = true
        modelName = URL(fileURLWithPath: modelPath).lastPathComponent
    }

    /// Generate text completion
    func generate(
        prompt: String,
        maxTokens: Int = 1024,
        temperature: Float = 0.3  // Low temp for factual summaries
    ) async throws -> String {
        guard let model = model else {
            throw LoadError.modelNotFound
        }

        let result = try await model.generate(
            prompt: prompt,
            parameters: GenerateParameters(
                temperature: temperature,
                topP: 0.9,
                maxTokens: maxTokens
            )
        )

        return result.output
    }

    /// Estimate token count (simple approximation)
    static func estimateTokenCount(_ text: String) -> Int {
        // Rough estimate: ~4 characters per token
        return text.count / 4
    }
}
```

---

### 2. Prompt Templates

#### PromptTemplates.swift
**Location**: `MeetingPrep/MeetingPrep/Services/LLM/PromptTemplates.swift`

```swift
struct PromptTemplates {

    /// System prompt for summarization
    static let systemPrompt = """
    You are an expert meeting summarizer. Your task is to analyze transcripts and \
    create structured summaries.

    Always respond in valid JSON format with the following structure:
    {
      "headline": "One-line summary of the meeting",
      "keyPoints": ["Point 1", "Point 2", "Point 3"],
      "actionItems": [
        {"description": "Task description", "assignee": "Name or null", "deadline": "Date or null"}
      ],
      "participants": ["Name 1", "Name 2"],
      "fullSummary": "2-3 paragraph narrative summary"
    }

    Rules:
    - Extract 3-5 key points
    - Identify concrete action items with assignees and deadlines when mentioned
    - List all participants/speakers
    - Write a clear, professional summary
    - Be factual and concise
    """

    /// User prompt template
    static func summarizationPrompt(for content: String) -> String {
        return """
        \(systemPrompt)

        Please analyze the following meeting content and provide a structured summary:

        ---
        \(content)
        ---

        Respond ONLY with valid JSON matching the schema above.
        """
    }
}
```

---

### 3. Real Summarisation Service

#### RealSummarisationService.swift
**Location**: `MeetingPrep/MeetingPrep/Services/RealSummarisationService.swift`

```swift
import Foundation

@MainActor
class RealSummarisationService {
    private let llmEngine: LLMEngine

    init(llmEngine: LLMEngine) {
        self.llmEngine = llmEngine
    }

    /// Generate summary for a document (single chunk only)
    func generateSummary(for document: Document, parsedContent: ParsedDocument) async throws -> Summary {
        // Validate document is small enough for single-chunk processing
        let tokenCount = LLMEngine.estimateTokenCount(parsedContent.fullText)
        guard tokenCount < 3000 else {
            throw SummarisationError.documentTooLarge(tokenCount: tokenCount)
        }

        // Generate prompt
        let prompt = PromptTemplates.summarizationPrompt(for: parsedContent.fullText)

        // Run LLM inference
        let response = try await llmEngine.generate(
            prompt: prompt,
            maxTokens: 1024,
            temperature: 0.3
        )

        // Parse JSON response
        let summaryData = try parseSummaryJSON(response)

        // Create Summary model
        return Summary(
            headline: summaryData.headline,
            keyPoints: summaryData.keyPoints,
            actionItems: summaryData.actionItems,
            participants: summaryData.participants,
            fullSummary: summaryData.fullSummary
        )
    }

    private func parseSummaryJSON(_ jsonString: String) throws -> SummaryData {
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        return try decoder.decode(SummaryData.self, from: data)
    }
}

enum SummarisationError: Error {
    case documentTooLarge(tokenCount: Int)
    case invalidJSONResponse
    case modelNotLoaded
}

// Internal parsing structure
private struct SummaryData: Codable {
    let headline: String
    let keyPoints: [String]
    let actionItems: [ActionItem]
    let participants: [String]
    let fullSummary: String
}
```

---

### 4. Settings View (Model Selection)

#### SettingsView.swift
**Location**: `MeetingPrep/MeetingPrep/Views/SettingsView.swift`

```swift
import SwiftUI

struct SettingsView: View {
    @State private var modelPath: String = ""
    @State private var isLoadingModel = false
    @State private var loadError: String?

    @Environment(\.dismiss) private var dismiss

    let llmEngine: LLMEngine

    var body: some View {
        Form {
            Section("LLM Model") {
                HStack {
                    TextField("Model Path", text: $modelPath)
                        .textFieldStyle(.roundedBorder)

                    Button("Browse...") {
                        selectModelFile()
                    }
                }

                if llmEngine.isLoaded, let name = llmEngine.modelName {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Loaded: \(name)")
                            .font(.caption)
                    }
                }

                if let error = loadError {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                Button(llmEngine.isLoaded ? "Reload Model" : "Load Model") {
                    Task {
                        await loadModel()
                    }
                }
                .disabled(modelPath.isEmpty || isLoadingModel)
            }

            Section("Info") {
                Text("Download a quantized MLX model (Phi-3-mini or Llama-3-8B) and select it above.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 300)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private func selectModelFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Select MLX model directory"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                modelPath = url.path
            }
        }
    }

    private func loadModel() async {
        isLoadingModel = true
        loadError = nil

        do {
            try await llmEngine.loadModel(modelPath: modelPath)
        } catch {
            loadError = "Failed to load model: \(error.localizedDescription)"
        }

        isLoadingModel = false
    }
}
```

---

### 5. Integration

#### Update MeetingPrepApp.swift
**Location**: `MeetingPrep/MeetingPrep/MeetingPrepApp.swift`

```swift
import SwiftUI
import SwiftData

@main
struct MeetingPrepApp: App {
    @State private var llmEngine = LLMEngine()
    @State private var showingSettings = false

    var body: some Scene {
        WindowGroup {
            ContentView(llmEngine: llmEngine)
        }
        .modelContainer(for: [Project.self, Document.self, Summary.self])
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Project") {
                    NotificationCenter.default.post(name: .createProject, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandMenu("Document") {
                Button("Import Document") {
                    NotificationCenter.default.post(name: .importDocument, object: nil)
                }
                .keyboardShortcut("i", modifiers: .command)

                Divider()

                Button("Delete Document") {
                    NotificationCenter.default.post(name: .deleteDocument, object: nil)
                }
                .keyboardShortcut(.delete, modifiers: [])
            }

            CommandGroup(after: .appSettings) {
                Button("Model Settings...") {
                    showingSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        // Settings window
        Window("Settings", id: "settings") {
            SettingsView(llmEngine: llmEngine)
        }
        .windowResizability(.contentSize)
    }
}
```

#### Update ContentView to use Real Service
**Location**: `MeetingPrep/MeetingPrep/ContentView.swift`

Modify `ProjectDetailView`:

```swift
struct ProjectDetailView: View {
    @Bindable var project: Project
    @Binding var selectedDocument: Document?
    let modelContext: ModelContext
    @Binding var triggerImport: Bool

    let llmEngine: LLMEngine  // NEW

    @State private var isImporting = false
    @State private var processingDocuments: Set<UUID> = []
    @State private var documentToDelete: Document?

    // Use real service if model loaded, otherwise fall back to mock
    private var summarisationService: any SummarisationServiceProtocol {
        if llmEngine.isLoaded {
            return RealSummarisationService(llmEngine: llmEngine)
        } else {
            return MockSummarisationService()
        }
    }

    // ... rest of implementation
}
```

---

## Unit Tests

### PromptTemplateTests.swift
**Location**: `MeetingPrepTests/Services/LLM/PromptTemplateTests.swift`

```swift
import XCTest
@testable import MeetingPrep

final class PromptTemplateTests: XCTestCase {

    func testSummarizationPromptFormat() {
        // Given
        let content = "Test meeting transcript"

        // When
        let prompt = PromptTemplates.summarizationPrompt(for: content)

        // Then
        XCTAssertTrue(prompt.contains("Test meeting transcript"))
        XCTAssertTrue(prompt.contains("JSON"))
        XCTAssertTrue(prompt.contains("headline"))
    }

    func testSystemPromptContainsRequiredFields() {
        // Then
        XCTAssertTrue(PromptTemplates.systemPrompt.contains("headline"))
        XCTAssertTrue(PromptTemplates.systemPrompt.contains("keyPoints"))
        XCTAssertTrue(PromptTemplates.systemPrompt.contains("actionItems"))
        XCTAssertTrue(PromptTemplates.systemPrompt.contains("participants"))
    }
}
```

### LLMEngineTests.swift (Mock-based)
**Location**: `MeetingPrepTests/Services/LLM/LLMEngineTests.swift`

```swift
import XCTest
@testable import MeetingPrep

final class LLMEngineTests: XCTestCase {

    func testTokenEstimation() {
        // Given
        let text = "This is a test" // 14 characters

        // When
        let tokens = LLMEngine.estimateTokenCount(text)

        // Then
        XCTAssertEqual(tokens, 3) // 14/4 ≈ 3
    }

    func testLoadModelWithInvalidPath() async {
        // Given
        let engine = LLMEngine()

        // When/Then
        await XCTAssertThrowsErrorAsync {
            try await engine.loadModel(modelPath: "/nonexistent/path")
        }
    }
}
```

---

## Integration Tests (Requires Model)

### LLMIntegrationTests.swift
**Location**: `MeetingPrepTests/Integration/LLMIntegrationTests.swift`

```swift
import XCTest
@testable import MeetingPrep

final class LLMIntegrationTests: XCTestCase {

    var llmEngine: LLMEngine!

    override func setUp() async throws {
        llmEngine = LLMEngine()

        // Load test model (Phi-3-mini for CI)
        let modelPath = ProcessInfo.processInfo.environment["TEST_MODEL_PATH"] ?? ""
        guard !modelPath.isEmpty else {
            throw XCTSkip("TEST_MODEL_PATH not set")
        }

        try await llmEngine.loadModel(modelPath: modelPath)
    }

    func testGenerateSummaryFromShortTranscript() async throws {
        // Given
        let content = """
        Speaker 1: Let's discuss the Q1 roadmap.
        Speaker 2: We need to prioritize Feature X.
        Speaker 1: Agreed. Sarah, can you draft the spec by Friday?
        """

        let prompt = PromptTemplates.summarizationPrompt(for: content)

        // When
        let response = try await llmEngine.generate(prompt: prompt)

        // Then
        XCTAssertFalse(response.isEmpty)
        XCTAssertTrue(response.contains("headline") || response.contains("Q1"))
    }
}
```

---

## Testing Strategy

### Manual Testing

1. **Download Model**:
   - Download Phi-3-mini-4k MLX model (~2.3 GB)
   - Place in known location

2. **Load Model**:
   - Open Settings (Cmd+,)
   - Select model directory
   - Click "Load Model"
   - Verify "Loaded: phi-3-mini" appears

3. **Import Short Document**:
   - Create 500-word transcript
   - Import into project
   - Verify real summary appears (not mocked)
   - Check headline, key points, action items

4. **Verify JSON Parsing**:
   - Check that summary structure is correct
   - Verify no parsing errors in console

5. **Test Without Model**:
   - Don't load model
   - Import document
   - Verify mock service is used (fallback)

---

## Dependencies

Add to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.18.0"),
]
```

Update entitlements if needed for model file access.

---

## File Structure Changes

```
MeetingPrep/
├── MeetingPrep/
│   ├── Services/
│   │   └── LLM/                              // NEW FOLDER
│   │       ├── LLMEngine.swift
│   │       ├── PromptTemplates.swift
│   │       └── RealSummarisationService.swift
│   └── Views/
│       └── SettingsView.swift                // NEW
└── MeetingPrepTests/
    ├── Services/
    │   └── LLM/
    │       ├── PromptTemplateTests.swift
    │       └── LLMEngineTests.swift
    └── Integration/
        └── LLMIntegrationTests.swift         // NEW
```

---

## Acceptance Criteria

- ✅ Model can be loaded from Settings view
- ✅ Short documents (<3000 tokens) generate real summaries
- ✅ Summary JSON is parsed correctly
- ✅ Headline, key points, action items extracted
- ✅ Participants detected from content
- ✅ Falls back to mock if model not loaded
- ✅ All unit tests pass
- ✅ Integration tests pass with test model
- ✅ User sees "real" AI output in UI

---

## Known Limitations

- Only works for short documents (Build 6 adds chunking)
- Audio files still use placeholder (Build 7)
- No progress indication during inference (Build 8)
- Limited error handling (Build 8)

---

## Next Steps (Build 6)

After Build 5 is complete:
- Document chunking for long transcripts
- Map-reduce summarization pipeline
- Progress tracking
