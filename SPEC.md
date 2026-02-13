# MeetingPrep — Technical Specification

## Phase 1: UI Demo MVP (Mocked Backend)

**Goal**: Build a clickable, interactive UI prototype demonstrating core UX flows with hardcoded/mocked data. No real LLM integration, file parsing, or audio transcription.

**Phase 2**: Replace mocked services with real implementation (LLM, parsers, WhisperKit).

---

## 1. Scope

### In Scope (Phase 1)
- ✅ Create/edit/delete projects
- ✅ Import documents (transcript, audio, presentation) with mocked processing
- ✅ Display mocked summaries with key points, action items, participants
- ✅ View document list and summary details
- ✅ Basic three-column navigation UI
- ✅ File picker integration (files selected but not actually processed)
- ✅ SwiftData persistence for projects and document metadata
- ✅ Mocked processing delays to simulate real behavior

### Out of Scope (Phase 1)
- ❌ Real LLM inference (MLX Swift)
- ❌ Audio transcription (WhisperKit)
- ❌ File parsing (PDF, PPTX, transcripts)
- ❌ Map-reduce summarization pipeline
- ❌ Settings/model selection
- ❌ Export functionality
- ❌ Search/filtering
- ❌ Tags

---

## 2. Data Models

### 2.1 Project

```swift
@Model
class Project {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var notes: String               // User-editable notes
    var documents: [Document]

    init(title: String, notes: String = "") {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.notes = notes
        self.documents = []
    }
}
```

### 2.2 Document

```swift
@Model
class Document {
    @Attribute(.unique) var id: UUID
    var fileName: String
    var fileType: DocumentType      // .transcript, .audio, .presentation
    var importedAt: Date
    var fileSize: Int64             // Bytes
    var summary: Summary?
    var project: Project?

    init(fileName: String, fileType: DocumentType, fileSize: Int64) {
        self.id = UUID()
        self.fileName = fileName
        self.fileType = fileType
        self.importedAt = Date()
        self.fileSize = fileSize
    }
}

enum DocumentType: String, Codable {
    case transcript     // .txt, .vtt, .srt, .json
    case audio          // .m4a, .mp3, .wav
    case presentation   // .pdf, .pptx, .key
}
```

### 2.3 Summary

```swift
@Model
class Summary {
    @Attribute(.unique) var id: UUID
    var headline: String                // One-line summary
    var keyPoints: [String]             // Bullet points
    var actionItems: [ActionItem]       // Codable struct
    var participants: [String]          // Detected speakers/attendees
    var fullSummary: String             // 2-3 paragraph narrative
    var generatedAt: Date
    var document: Document?

    init(headline: String, keyPoints: [String], actionItems: [ActionItem],
         participants: [String], fullSummary: String) {
        self.id = UUID()
        self.headline = headline
        self.keyPoints = keyPoints
        self.actionItems = actionItems
        self.participants = participants
        self.fullSummary = fullSummary
        self.generatedAt = Date()
    }
}

struct ActionItem: Codable, Hashable {
    let description: String
    let assignee: String?
    let deadline: String?
}
```

---

## 3. UI Structure

### 3.1 Navigation Layout

Three-column layout (macOS standard):

```
┌─────────────────┬──────────────────────┬──────────────────────┐
│  Sidebar        │  Main Content        │  Detail Panel        │
│  (Projects)     │  (Documents List)    │  (Summary Detail)    │
│                 │                      │                      │
│  + New Project  │  + Import Document   │  [Summary content]   │
│                 │                      │                      │
│  Project 1      │  Document 1          │  Headline            │
│  Project 2 ✓    │  Document 2 ✓        │  Key Points          │
│  Project 3      │  Document 3          │  Action Items        │
│                 │                      │  Participants        │
│                 │                      │  Full Summary        │
└─────────────────┴──────────────────────┴──────────────────────┘
```

### 3.2 Views Specification

#### ProjectListView (Sidebar)
- **Header**: "Projects" + "+" button (create new project)
- **List items**:
  - Project title
  - Document count badge (e.g., "3 docs")
  - Date (created or last updated)
- **Selection**: Highlights selected project
- **Context menu**: Edit, Delete
- **Empty state**: "No projects. Click + to create one."

#### ProjectDetailView (Main Content)
- **Header**:
  - Project title (editable inline)
  - "Import" button
  - Document count
- **Document list**:
  - Rows showing: filename, file type icon, import date, summary status
  - Summary status: "Processing..." or checkmark ✓
  - Click row to view summary in detail panel
- **Empty state**: "No documents. Click Import to add."

#### SummaryDetailView (Detail Panel)
- **Header**: Document filename
- **Sections**:
  1. **Headline** (large text, one-line)
  2. **Key Points** (bulleted list)
  3. **Action Items** (list with assignee/deadline if present)
  4. **Participants** (comma-separated or pills)
  5. **Full Summary** (paragraph text)
- **Empty state**: "Select a document to view summary."

#### ImportView (Sheet)
- **File picker**: Standard macOS file picker
- **Supported types**: `.txt`, `.vtt`, `.srt`, `.json`, `.m4a`, `.mp3`, `.wav`, `.pdf`, `.pptx`, `.key`
- **After selection**:
  - Close sheet
  - Add document to current project
  - Show "Processing..." for 2 seconds
  - Display mocked summary

#### ProjectEditView (Sheet)
- **Fields**:
  - Title (text field, required)
  - Notes (text editor, optional)
- **Buttons**: Cancel, Save
- **Validation**: Title cannot be empty

---

## 4. User Flows

### 4.1 Create Project
1. Click "+" in sidebar
2. Sheet appears with "New Project" title
3. User enters title (e.g., "Q1 Board Meeting")
4. Optional: add notes
5. Click "Save"
6. Project appears in sidebar and auto-selects

### 4.2 Import Document
1. Select project from sidebar
2. Click "Import" button in main content
3. File picker opens
4. User selects file (e.g., `transcript.txt`)
5. File picker closes
6. Document appears in list with "Processing..." status
7. After 2-second delay, status changes to ✓
8. Document is now clickable

### 4.3 View Summary
1. Click document row with ✓ status
2. Detail panel displays mocked summary:
   - Headline
   - Key points (3-5 bullets)
   - Action items (2-3 items)
   - Participants (2-4 names)
   - Full summary (2-3 paragraphs)

### 4.4 Edit Project
1. Right-click project in sidebar → "Edit"
2. Sheet appears with current title/notes
3. User modifies fields
4. Click "Save"
5. Project updates in sidebar

### 4.5 Delete Project
1. Right-click project in sidebar → "Delete"
2. Confirmation alert: "Delete [Project Name] and all documents?"
3. If confirmed, project and associated documents removed
4. Sidebar selects next project or shows empty state

### 4.6 Delete Document
1. Right-click document in list → "Delete"
2. Confirmation alert: "Delete [filename]?"
3. If confirmed, document and summary removed

---

## 5. Mocked Data Strategy

### 5.1 Mock Summaries

For Phase 1, use a predefined set of mocked summaries based on file type:

**Transcript files** (`.txt`, `.vtt`, `.srt`, `.json`):
```swift
Summary(
    headline: "Team discussed Q1 roadmap priorities and resource allocation",
    keyPoints: [
        "Feature X approved for Q1 release with March 15 deadline",
        "Hiring two additional engineers by end of February",
        "Weekly sync meetings moved to Tuesdays 10am",
        "Marketing campaign launch aligned with product release"
    ],
    actionItems: [
        ActionItem(description: "Draft technical spec for Feature X", assignee: "Sarah", deadline: "Jan 20"),
        ActionItem(description: "Post job listings", assignee: "HR Team", deadline: "This week"),
        ActionItem(description: "Finalize marketing timeline", assignee: "Mike", deadline: nil)
    ],
    participants: ["Sarah Chen", "Mike Rodriguez", "Alex Kim", "Jordan Taylor"],
    fullSummary: "The team convened to finalize Q1 priorities and address resource constraints. Feature X was greenlit for the March 15 release, contingent on hiring two additional engineers by month-end. The group agreed to realign weekly syncs to Tuesday mornings to improve cross-functional coordination.\n\nMarketing presented a revised campaign timeline that synchronizes with the product launch window. Action items were assigned with clear ownership, though some deadlines remain flexible pending final roadmap approval."
)
```

**Audio files** (`.m4a`, `.mp3`, `.wav`):
```swift
Summary(
    headline: "Client call reviewing project status and next deliverables",
    keyPoints: [
        "Phase 1 delivered on schedule, client satisfied with quality",
        "Phase 2 scope expanded to include mobile app",
        "Budget increase approved for additional features",
        "Next milestone review scheduled for March 1"
    ],
    actionItems: [
        ActionItem(description: "Send updated project proposal", assignee: "Account Manager", deadline: "Jan 18"),
        ActionItem(description: "Schedule mobile app kickoff", assignee: "Project Lead", deadline: "Next week"),
        ActionItem(description: "Update contract with new scope", assignee: "Legal", deadline: "Jan 25")
    ],
    participants: ["Client Stakeholder", "Account Manager", "Project Lead"],
    fullSummary: "The client expressed strong satisfaction with Phase 1 deliverables, noting the team met all deadlines and quality benchmarks. Based on initial success, they requested scope expansion to include a mobile companion app.\n\nBudget discussions concluded with approval for the enhanced feature set. The team will reconvene on March 1 to review Phase 2 progress and validate the mobile app roadmap."
)
```

**Presentation files** (`.pdf`, `.pptx`, `.key`):
```swift
Summary(
    headline: "Sales deck outlining product vision and competitive positioning",
    keyPoints: [
        "Product targets mid-market B2B segment with 50-500 employees",
        "Key differentiator: AI-powered automation vs manual workflows",
        "Pricing: $99/user/month with annual contracts",
        "Go-to-market strategy focuses on partner channels"
    ],
    actionItems: [
        ActionItem(description: "Finalize demo environment", assignee: "Product Team", deadline: "Feb 1"),
        ActionItem(description: "Recruit 3 channel partners", assignee: "Sales", deadline: "End of Q1"),
        ActionItem(description: "Create customer case studies", assignee: "Marketing", deadline: "Feb 15")
    ],
    participants: ["Sales Team", "Product Team", "Marketing"],
    fullSummary: "The sales deck positions the product as an AI-first solution for mid-market companies seeking to automate repetitive workflows. Competitive analysis highlights significant time savings versus legacy manual processes.\n\nPricing strategy balances accessibility with revenue targets, while the partner-led go-to-market approach leverages existing distribution channels to accelerate market penetration."
)
```

### 5.2 Processing Simulation

```swift
class MockSummarisationService {
    func generateSummary(for document: Document) async throws -> Summary {
        // Simulate processing delay
        try await Task.sleep(for: .seconds(2))

        // Return mocked summary based on document type
        switch document.fileType {
        case .transcript:
            return transcriptMockSummary
        case .audio:
            return audioMockSummary
        case .presentation:
            return presentationMockSummary
        }
    }
}
```

---

## 6. Technical Implementation Notes

### 6.1 Architecture (Phase 1)

```
SwiftUI Views
     │
     ▼
@Observable AppState
     │
     ▼
SwiftData ModelContext (Projects, Documents, Summaries)
     │
     ▼
MockSummarisationService (returns hardcoded summaries)
```

**No file parsing, no LLM, no WhisperKit in Phase 1.**

### 6.2 AppState

```swift
@Observable
class AppState {
    var selectedProject: Project?
    var selectedDocument: Document?
    var isImporting: Bool = false
    var isEditingProject: Bool = false

    let mockService = MockSummarisationService()

    func importDocument(url: URL, to project: Project, context: ModelContext) async {
        // Extract filename and type from URL
        let fileName = url.lastPathComponent
        let fileType = DocumentType.from(url: url)
        let fileSize = url.fileSize() ?? 0

        // Create document
        let document = Document(fileName: fileName, fileType: fileType, fileSize: fileSize)
        document.project = project
        project.documents.append(document)

        try? context.save()

        // Generate mocked summary
        let summary = try? await mockService.generateSummary(for: document)
        document.summary = summary

        try? context.save()
    }
}
```

### 6.3 File Type Detection

```swift
extension DocumentType {
    static func from(url: URL) -> DocumentType {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "txt", "vtt", "srt", "json":
            return .transcript
        case "m4a", "mp3", "wav":
            return .audio
        case "pdf", "pptx", "key":
            return .presentation
        default:
            return .transcript  // Default fallback
        }
    }
}
```

### 6.4 SwiftData Setup

```swift
@main
struct MeetingPrepApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Project.self, Document.self, Summary.self])
    }
}
```

---

## 7. Visual Design Notes

### 7.1 Color & Styling
- Use macOS system colors (`Color.accentColor`, `Color.secondary`)
- SF Symbols for icons (document types, actions)
- Standard macOS spacing and padding
- Native list styles (`ListStyle.sidebar`)

### 7.2 Icons
- **Transcript**: `doc.text`
- **Audio**: `waveform`
- **Presentation**: `doc.richtext`
- **Processing**: `arrow.clockwise` (animated)
- **Complete**: `checkmark.circle.fill`

### 7.3 Typography
- **Headline**: `.title` (bold)
- **Key points**: `.body` with bullet prefix
- **Action items**: `.callout` with assignee in secondary color
- **Full summary**: `.body` with multi-paragraph spacing

---

## 8. Acceptance Criteria (Phase 1)

### AC1: Project Management
- ✅ User can create a new project with title and notes
- ✅ User can edit project title and notes
- ✅ User can delete project (with confirmation)
- ✅ Projects persist across app restarts
- ✅ Sidebar shows project list ordered by creation date (newest first)

### AC2: Document Import
- ✅ User can import supported file types into a project
- ✅ File picker filters to supported extensions
- ✅ Document appears in list immediately with "Processing..." status
- ✅ After 2 seconds, status changes to ✓ and summary is viewable
- ✅ Documents persist across app restarts

### AC3: Summary Display
- ✅ Clicking a processed document shows summary in detail panel
- ✅ Summary displays: headline, key points, action items, participants, full summary
- ✅ Action items show assignee and deadline if present
- ✅ Participants displayed as comma-separated list or pills

### AC4: UI Navigation
- ✅ Three-column layout: sidebar (projects) → main (documents) → detail (summary)
- ✅ Selecting different projects updates document list
- ✅ Selecting different documents updates summary detail
- ✅ Empty states shown when no projects/documents/summaries exist

### AC5: Data Persistence
- ✅ All projects, documents, and summaries persist in SwiftData
- ✅ Relationships maintained (Project ↔ Documents ↔ Summary)
- ✅ Deleting project removes associated documents and summaries
- ✅ Deleting document removes associated summary

---

## 9. Phase 2 Transition Plan

When moving to Phase 2 (real backend), replace:

1. **MockSummarisationService** → **LLMEngine + SummarisationPipeline**
2. **Hardcoded summaries** → **Real LLM inference with MLX Swift**
3. **File type detection** → **File parsing** (TranscriptParser, PresentationParser, AudioTranscriber)
4. **2-second delay** → **Real processing time with progress updates**
5. **Static mocked data** → **Chunking, map-reduce, prompt templates**

**Data models remain unchanged** — Phase 1 database schema is production-ready.

---

## 10. Development Checklist

### Core Models
- [ ] Define `Project`, `Document`, `Summary`, `ActionItem` SwiftData models
- [ ] Create `MockSummarisationService` with 3 hardcoded summaries
- [ ] Implement `DocumentType.from(url:)` file type detection

### UI Views
- [ ] `ProjectListView` (sidebar with create/edit/delete)
- [ ] `ProjectDetailView` (document list with import button)
- [ ] `SummaryDetailView` (summary display with all sections)
- [ ] `ImportView` (file picker sheet)
- [ ] `ProjectEditView` (create/edit project sheet)

### App State & Logic
- [ ] `AppState` observable object
- [ ] `importDocument` async method with mocked processing
- [ ] Project CRUD operations
- [ ] Document deletion
- [ ] SwiftData model container setup

### Polish
- [ ] Empty states for all views
- [ ] Confirmation alerts for destructive actions
- [ ] SF Symbols icons for file types
- [ ] Processing animation
- [ ] Keyboard shortcuts (Cmd+N for new project, etc.)

---

## 11. Out of Scope (Explicitly Deferred)

- Settings view
- Model selection/download
- Export summaries
- Search/filter
- Tags
- Editing summaries
- Action item completion tracking
- Calendar integration
- Real-time recording
- Performance optimization
- Error handling (beyond basic alerts)
- Accessibility (beyond standard SwiftUI defaults)
- Localization
- Dark mode customization (use system default)

---

**End of Phase 1 Specification**
