# Build 2: Document Import + Mocked Processing

## What's New in Build 2

✅ **MockSummarisationService**
- Three hardcoded summaries (transcript, audio, presentation)
- 2-second processing delay to simulate real LLM inference
- Different summary content based on document type

✅ **File Import Workflow**
- File picker with supported file types
- Multi-file import support
- Automatic document type detection from extension
- File size capture and formatting

✅ **Three-Column Navigation**
- Sidebar: Projects list
- Content: Document list with import button
- Detail: Summary viewer

✅ **Document List View**
- Shows all documents in selected project
- Displays: filename, type icon, file size, import date
- Processing indicator (spinning wheel) during summarisation
- Checkmark when summary is ready
- Right-click to delete documents

✅ **Summary Display**
- Headline (one-line summary)
- Key points (bullet list)
- Action items (with assignee and deadline)
- Participants (as pills/tags)
- Full summary (paragraph text)
- Generation timestamp

## Supported File Types

### Transcripts
- `.txt` - Plain text
- `.vtt` - WebVTT subtitles
- `.srt` - SubRip subtitles
- `.json` - JSON format (Zoom/Teams exports)

### Audio
- `.m4a` - MPEG-4 Audio
- `.mp3` - MP3 Audio
- `.wav` - WAV Audio

### Presentations
- `.pdf` - PDF documents
- `.pptx` - PowerPoint presentations
- `.key` - Keynote presentations

## How to Test

### 1. Build and Run
```bash
cd MeetingPrep
open MeetingPrep.xcodeproj
```

Press Cmd+R to build and run.

### 2. Create a Test Project
1. Click "+" in sidebar
2. Create project: "Test Import"
3. Click "Save"

### 3. Test Single File Import
1. Click "Import" button in document list
2. File picker opens
3. Select any supported file (create a test `.txt` file if needed)
4. File picker closes
5. Document appears in list with **processing indicator** (spinning wheel)
6. After **2 seconds**, indicator changes to **green checkmark ✓**
7. Click the document row
8. Summary appears in detail panel on the right

### 4. Test Different File Types
Create test files and import each type:

**Transcript** (`test-transcript.txt`):
- Summary will show: "Team discussed Q1 roadmap priorities..."
- Action items about drafting specs and hiring

**Audio** (`test-audio.m4a`):
- Summary will show: "Client call reviewing project status..."
- Action items about proposals and kickoffs

**Presentation** (`test-deck.pdf`):
- Summary will show: "Sales deck outlining product vision..."
- Action items about demo environment and partnerships

### 5. Test Multi-File Import
1. Click "Import"
2. Select **multiple files** (Cmd+Click)
3. Click "Open"
4. All files appear with processing indicators
5. They process sequentially (2 seconds each)
6. Checkmarks appear as each completes

### 6. Test Summary Display Components
Click on a processed document and verify:

✅ **Headline** displays prominently at top
✅ **Key Points** shown as bulleted list (3-5 points)
✅ **Action Items** with:
  - Description
  - Assignee (person icon)
  - Deadline (calendar icon)
✅ **Participants** shown as colored pills/tags
✅ **Full Summary** as paragraph text (2-3 paragraphs)
✅ **Generation timestamp** at bottom

### 7. Test Document Deletion
1. Right-click on a document in the list
2. Select "Delete"
3. Confirmation alert appears
4. Click "Delete"
5. Document and summary removed from database
6. If it was selected, detail panel shows "No Document Selected"

### 8. Test Empty States
**No documents:**
1. Delete all documents from a project
2. Verify "No Documents" empty state with "Click Import to add"

**No summary yet:**
1. Import a file
2. Click it immediately while processing
3. Detail shows "Processing..." empty state

**No document selected:**
1. Have documents but none selected
2. Detail shows "No Document Selected"

### 9. Test Persistence
1. Import several documents with summaries
2. Quit app (Cmd+Q)
3. Relaunch app
4. Verify:
   - ✅ All documents persist
   - ✅ All summaries persist
   - ✅ Processing state is NOT persisted (no documents stuck "processing")
   - ✅ Checkmarks show for completed documents

### 10. Test Three-Column Navigation
1. Click different projects in sidebar → document list updates
2. Click different documents → summary detail updates
3. Import document in one project → doesn't affect other projects
4. Delete project → all its documents deleted (cascade)

## Expected Behavior

### ✅ Working Features
- File picker with type filtering
- Multi-file import
- Document type detection from extension
- 2-second mocked processing delay
- Different summaries for different document types
- Processing indicators (spinner → checkmark)
- Full summary display with all sections
- Document deletion with confirmation
- Three-column navigation
- Empty states
- Persistence of documents and summaries

### 🎯 Mocked Behavior (Not Real)
- File content is NOT actually parsed (files just need to exist)
- Audio is NOT transcribed (WhisperKit not integrated)
- Summaries are hardcoded (not generated by LLM)
- Processing time is exactly 2 seconds (not based on file size)

### 🚧 Not Implemented Yet (Build 3+)
- Editing summaries
- Exporting summaries
- Search/filter documents
- Tags
- Settings

## File Structure

```
MeetingPrep/
├── MeetingPrep.xcodeproj/
└── MeetingPrep/
    ├── MeetingPrepApp.swift
    ├── ContentView.swift              // Updated: Three-column layout
    ├── MeetingPrep.entitlements
    ├── Models/
    │   ├── Project.swift
    │   ├── Document.swift
    │   └── Summary.swift
    └── Services/                       // NEW
        └── MockSummarisationService.swift
```

## Key Implementation Details

### Document Type Detection
```swift
DocumentType.from(url: fileURL)
// .txt, .vtt, .srt, .json → .transcript
// .m4a, .mp3, .wav → .audio
// .pdf, .pptx, .key → .presentation
```

### Processing Flow
```
User clicks Import
    ↓
File picker opens
    ↓
User selects file(s)
    ↓
For each file:
  1. Create Document record
  2. Add to project
  3. Save to SwiftData
  4. Show processing indicator
  5. await mockService.generateSummary() // 2 seconds
  6. Create Summary record
  7. Link to document
  8. Save to SwiftData
  9. Hide processing indicator, show checkmark
```

### Summary Content Variation
- **Transcript files**: Team meeting summary, roadmap discussion
- **Audio files**: Client call summary, project status update
- **Presentation files**: Sales deck summary, product positioning

## Known Issues / Limitations

- Files are not actually opened/parsed (just need to exist)
- All transcripts get the same summary (no content variation)
- Processing is sequential (not parallel)
- No progress percentage (just spinner)
- No error handling for failed processing

## Success Criteria ✅

All Build 2 acceptance criteria met:

- ✅ User can import supported file types into a project
- ✅ File picker filters to supported extensions
- ✅ Document appears in list immediately with "Processing..." status
- ✅ After 2 seconds, status changes to ✓ and summary is viewable
- ✅ Documents persist across app restarts
- ✅ Summary displays: headline, key points, action items, participants, full summary
- ✅ Action items show assignee and deadline if present
- ✅ Participants displayed as pills
- ✅ Three-column navigation works correctly
- ✅ Can delete documents with confirmation

## Next Steps: Build 3

Build 3 will add:
- Summary detail view polish (better formatting, copy buttons)
- Export summaries (Markdown, PDF, plain text)
- Search/filter documents
- Optional: Tags and categories
- Optional: Editing project notes inline

## Requirements

- macOS 14.0+ (Sonoma)
- Xcode 15+
- Apple Silicon or Intel Mac

---

**Build 2 Complete!** 🎉

You now have a fully functional UI demo with:
- ✅ Project management
- ✅ Document import
- ✅ Mocked summarisation
- ✅ Summary display
- ✅ Three-column navigation
- ✅ Full data persistence

Test thoroughly and verify all acceptance criteria before moving to Build 3 (or Phase 2 real backend).
