# Meeting Prep & Logging Tool — Architecture

A macOS-native application for processing call transcripts and presentations
locally, summarising content, and organising meeting preparation.

---

## High-Level Overview

```
┌─────────────────────────────────────────────────────────┐
│                   SwiftUI Mac App                       │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │  Import &    │  │   Meeting    │  │   Summary &   │  │
│  │  Document    │  │   Prep       │  │   Log         │  │
│  │  Browser     │  │   View       │  │   Viewer      │  │
│  └──────┬───────┘  └──────┬───────┘  └───────┬───────┘  │
│         │                 │                   │          │
│  ┌──────┴─────────────────┴───────────────────┴───────┐  │
│  │              Core Services Layer                   │  │
│  │  ┌────────────┐ ┌─────────────┐ ┌──────────────┐  │  │
│  │  │ Document   │ │ Summariser  │ │  Meeting     │  │  │
│  │  │ Processor  │ │ (Local LLM) │ │  Store       │  │  │
│  │  └─────┬──────┘ └──────┬──────┘ └──────┬───────┘  │  │
│  └────────┼───────────────┼────────────────┼──────────┘  │
│           │               │                │             │
│  ┌────────┴───────────────┴────────────────┴──────────┐  │
│  │              Infrastructure Layer                  │  │
│  │  ┌──────────┐ ┌───────────┐ ┌───────────────────┐ │  │
│  │  │ File     │ │ MLX /     │ │ SwiftData /       │ │  │
│  │  │ Parsers  │ │ llama.cpp │ │ Core Data + SQLite│ │  │
│  │  └──────────┘ └───────────┘ └───────────────────┘ │  │
│  └────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## 1. Technology Choices

| Concern | Choice | Rationale |
|---|---|---|
| **UI framework** | SwiftUI (macOS 14+) | Native Mac experience, declarative, built-in document handling |
| **Local LLM runtime** | [MLX Swift](https://github.com/ml-explore/mlx-swift) | Apple's own ML framework, optimised for Apple Silicon unified memory; no network calls |
| **Summarisation model** | Quantised Mistral-7B or Llama-3-8B (GGUF/MLX format) | Good summarisation quality at a size that fits in 8–16 GB unified memory |
| **Audio transcription** | [WhisperKit](https://github.com/argmaxinc/WhisperKit) | Swift-native, runs Whisper on Core ML / Apple Neural Engine; fully offline |
| **Persistence** | SwiftData (backed by SQLite) | First-party, integrates directly with SwiftUI, lightweight |
| **PDF parsing** | PDFKit (built-in) | Ships with macOS, no dependency needed |
| **PPTX parsing** | ZIPFoundation + custom XML parser | PPTX is a ZIP of XML; lightweight to extract slide text |
| **Keynote (.key)** | Export-to-PDF bridge or iWork framework | Keynote files are protobuf-based; PDF export is more reliable |
| **Packaging** | Native .app bundle with embedded model weights | Single drag-to-Applications install; no server, no Docker |

---

## 2. Module Breakdown

### 2.1 Document Processor

Responsible for ingesting files and extracting structured text.

```
DocumentProcessor/
├── TranscriptParser.swift      // .txt, .vtt, .srt, .json (Zoom/Teams export)
├── PresentationParser.swift    // .pdf, .pptx, .key
├── AudioTranscriber.swift      // .m4a, .mp3, .wav → text via WhisperKit
├── DocumentChunker.swift       // Splits long docs into LLM-sized chunks
└── Models/
    ├── ParsedDocument.swift    // Uniform representation of extracted content
    └── DocumentChunk.swift     // Individual chunk with metadata
```

**Key type:**

```swift
struct ParsedDocument {
    let id: UUID
    let source: URL
    let kind: DocumentKind          // .transcript, .presentation, .audio
    let title: String
    let segments: [TextSegment]     // Speaker-attributed or slide-attributed blocks
    let createdAt: Date
}

enum DocumentKind {
    case transcript
    case presentation
    case audio
}

struct TextSegment {
    let speaker: String?            // nil for slides
    let content: String
    let timestamp: TimeInterval?    // nil for slides
    let slideNumber: Int?           // nil for transcripts
}
```

### 2.2 Summariser (Local LLM)

Runs inference entirely on-device using MLX Swift.

```
Summariser/
├── LLMEngine.swift             // Loads model, manages context window
├── SummarisationPipeline.swift // Orchestrates chunked summarisation
├── PromptTemplates.swift       // System/user prompts for each task
└── Models/
    └── Summary.swift           // Output type
```

**Summarisation strategy — map-reduce for long documents:**

```
┌──────────┐  ┌──────────┐  ┌──────────┐
│ Chunk 1  │  │ Chunk 2  │  │ Chunk 3  │   ... N chunks
└────┬─────┘  └────┬─────┘  └────┬─────┘
     │              │              │
     ▼              ▼              ▼
 ┌────────┐    ┌────────┐    ┌────────┐
 │Summary │    │Summary │    │Summary │    MAP phase
 │   1    │    │   2    │    │   3    │    (parallel)
 └────┬───┘    └────┬───┘    └────┬───┘
      │             │              │
      └─────────────┼──────────────┘
                    ▼
              ┌───────────┐
              │  Final    │                REDUCE phase
              │  Summary  │
              └───────────┘
```

**Output type:**

```swift
struct Summary {
    let id: UUID
    let documentID: UUID
    let headline: String            // One-line summary
    let keyPoints: [String]         // Bullet points
    let actionItems: [ActionItem]   // Extracted to-dos
    let participants: [String]      // Detected speakers/attendees
    let fullSummary: String         // 2–3 paragraph narrative
    let generatedAt: Date
}

struct ActionItem {
    let description: String
    let assignee: String?
    let deadline: String?           // Freeform text extracted by LLM
}
```

### 2.3 Meeting Store (Persistence)

```
MeetingStore/
├── MeetingRecord.swift         // SwiftData @Model
├── DocumentRecord.swift        // SwiftData @Model
├── SummaryRecord.swift         // SwiftData @Model
└── MeetingRepository.swift     // Query helpers
```

**Data model (SwiftData):**

```swift
@Model
class MeetingRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var date: Date
    var notes: String
    var documents: [DocumentRecord]
    var summaries: [SummaryRecord]
    var tags: [String]
}
```

### 2.4 UI Layer (SwiftUI)

```
Views/
├── Sidebar/
│   ├── MeetingListView.swift       // Chronological list of meetings
│   └── MeetingRowView.swift
├── Import/
│   ├── ImportView.swift            // Drag-and-drop + file picker
│   └── ProcessingProgressView.swift
├── Prep/
│   ├── MeetingPrepView.swift       // Pre-meeting: aggregated summaries
│   └── ActionItemsView.swift
├── Detail/
│   ├── SummaryDetailView.swift     // Read full summary + key points
│   └── TranscriptBrowserView.swift // Searchable transcript viewer
└── Settings/
    └── ModelSettingsView.swift     // Select model, adjust generation params
```

**Navigation structure — three-column layout:**

```
┌──────────────┬───────────────────┬──────────────────────┐
│              │                   │                      │
│  Meetings    │  Meeting Detail   │  Document /          │
│  (sidebar)   │  + Summaries     │  Summary View        │
│              │                   │                      │
└──────────────┴───────────────────┴──────────────────────┘
```

---

## 3. Processing Pipeline

End-to-end flow from file import to viewable summary:

```
User drops file(s)
       │
       ▼
┌──────────────┐
│ Detect type  │  file extension + UTType
└──────┬───────┘
       │
       ├── .txt/.vtt/.srt/.json ──▶ TranscriptParser
       ├── .pdf/.pptx/.key ───────▶ PresentationParser
       └── .m4a/.mp3/.wav ────────▶ AudioTranscriber (WhisperKit)
                                          │
                                          ▼
                                   Raw transcript text
       │
       ▼
┌──────────────────┐
│ ParsedDocument   │  uniform representation
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ DocumentChunker  │  split into ≤ 4K token chunks
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ SummarisationPipeline │  map-reduce via LLMEngine
└──────┬───────────┘
       │
       ▼
┌──────────────┐
│ Summary      │  persisted to SwiftData
└──────┬───────┘
       │
       ▼
  UI updates via SwiftData observation
```

---

## 4. Local LLM Integration Detail

### Model management

```swift
class LLMEngine: ObservableObject {
    /// Model lives in the app bundle or ~/Library/Application Support/MeetingPrep/Models/
    private var model: MLXModel?

    func loadModel(from path: URL) async throws { ... }

    func generate(
        prompt: String,
        maxTokens: Int = 1024,
        temperature: Float = 0.3      // Low temperature for factual summaries
    ) async throws -> String { ... }
}
```

### Recommended models (MLX-quantised)

| Model | Size (Q4) | RAM needed | Quality |
|---|---|---|---|
| Llama-3-8B-Instruct | ~4.5 GB | ~6 GB | Good general summarisation |
| Mistral-7B-Instruct-v0.3 | ~4.1 GB | ~6 GB | Strong instruction following |
| Phi-3-mini-4k | ~2.3 GB | ~4 GB | Lighter option for 8 GB Macs |

Models are downloaded once on first launch and stored in Application Support.

---

## 5. Privacy & Security

- **No network calls** after initial model download. All inference runs on Apple Silicon GPU/ANE.
- Documents never leave the machine. SwiftData store is in the app sandbox.
- Optional: encrypt the SQLite store with `NSFileProtectionComplete`.
- The app requests only `com.apple.security.files.user-selected.read-only` for imported files.

---

## 6. Project Structure

```
MeetingPrep/
├── MeetingPrep.xcodeproj
├── MeetingPrep/
│   ├── App/
│   │   ├── MeetingPrepApp.swift        // @main entry point
│   │   └── AppState.swift              // Global observable state
│   ├── Core/
│   │   ├── DocumentProcessor/
│   │   ├── Summariser/
│   │   └── MeetingStore/
│   ├── Views/
│   │   ├── Sidebar/
│   │   ├── Import/
│   │   ├── Prep/
│   │   ├── Detail/
│   │   └── Settings/
│   ├── Resources/
│   │   └── PromptTemplates/            // .txt prompt files
│   └── Utilities/
│       ├── ChunkingUtils.swift
│       └── DateFormatting.swift
├── MeetingPrepTests/
├── MeetingPrepUITests/
└── Package.swift                        // SPM for WhisperKit, MLX Swift, ZIPFoundation
```

---

## 7. Dependencies (Swift Package Manager)

```swift
dependencies: [
    .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.18.0"),
    .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.9.0"),
    .package(url: "https://github.com/weichsel/ZIPFoundation", from: "0.9.0"),
]
```

---

## 8. Build & Run Requirements

- **macOS 14.0+ (Sonoma)** — required for SwiftData
- **Xcode 15+**
- **Apple Silicon Mac** — MLX requires Metal; Intel Macs would need a fallback to llama.cpp with CPU inference
- Minimum 8 GB unified memory (16 GB recommended for 7–8B parameter models)

---

## 9. Phase 1 Scope (Summarisation MVP)

The first deliverable focuses exclusively on summarisation:

1. Import transcript files (.txt, .vtt, .srt) and presentations (.pdf, .pptx)
2. Parse into `ParsedDocument`
3. Chunk and summarise via local LLM
4. Display summary with key points, action items, and participants
5. Persist meetings and summaries in SwiftData

Future phases can add: calendar integration, live recording, meeting templates,
comparative prep ("here's what changed since last meeting"), and search across
all historical summaries.
