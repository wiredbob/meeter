# Build 1: Foundation + Basic CRUD

## What's Implemented

✅ **SwiftData Models**
- `Project` with title, notes, created/updated dates
- `Document` with file metadata and type detection
- `Summary` with headline, key points, action items, participants
- Proper cascade deletion relationships

✅ **Project Management**
- Create new projects (+ button in toolbar)
- Edit existing projects (right-click → Edit)
- Delete projects with confirmation (right-click → Delete)
- Project list sorted by creation date (newest first)

✅ **UI Components**
- Three-column NavigationSplitView layout
- ProjectListView sidebar with toolbar
- ProjectEditView sheet for create/edit
- Empty states when no projects exist
- Context menu on project rows

✅ **Data Persistence**
- SwiftData persistence to disk
- Data survives app restarts
- Cascade deletion (deleting project removes all documents/summaries)

## How to Test

### 1. Open the Project
```bash
cd MeetingPrep
open MeetingPrep.xcodeproj
```

### 2. Build and Run
- Select "My Mac" as the target
- Press Cmd+R or click Run
- App should launch with empty state

### 3. Test Project Creation
1. Click "+" button in toolbar
2. Sheet appears with "New Project" title
3. Enter title: "Q1 Board Meeting"
4. Add notes: "Quarterly review and planning"
5. Click "Save"
6. Project appears in sidebar and auto-selects
7. Detail view shows "Build 1 Complete!" status

### 4. Test Project Editing
1. Right-click on the project
2. Select "Edit"
3. Change title to "Q1 Board Meeting - Updated"
4. Click "Save"
5. Sidebar updates with new title

### 5. Test Creating Multiple Projects
1. Create 2-3 more projects with different names
2. Verify they appear in chronological order (newest first)
3. Click between projects to test selection

### 6. Test Persistence
1. Create a project: "Persistence Test"
2. Quit the app (Cmd+Q)
3. Relaunch the app
4. Verify "Persistence Test" project still exists ✅

### 7. Test Project Deletion
1. Right-click on a project
2. Select "Delete"
3. Confirmation alert appears
4. Click "Delete"
5. Project disappears from list
6. If it was selected, detail view shows "Select a project"

### 8. Test Empty State
1. Delete all projects
2. Sidebar shows empty state: "No Projects"
3. Message: "Click + to create your first project"

## Expected Behavior

### ✅ Working Features
- Projects persist across app restarts
- Create/Edit/Delete operations work smoothly
- Navigation and selection work correctly
- Empty states display appropriately
- Confirmation alerts prevent accidental deletions
- SwiftData relationships maintain integrity

### 🚧 Not Implemented Yet (Build 2+)
- Document import
- File picker
- Mocked summaries
- Summary display
- Processing animations
- Three-column detail panel with actual content

## File Structure

```
MeetingPrep/
├── MeetingPrep.xcodeproj/
│   └── project.pbxproj
└── MeetingPrep/
    ├── MeetingPrepApp.swift          // App entry point
    ├── ContentView.swift              // Main UI with sidebar
    ├── MeetingPrep.entitlements       // Sandbox permissions
    └── Models/
        ├── Project.swift              // Project data model
        ├── Document.swift             // Document data model
        └── Summary.swift              // Summary data model
```

## Known Issues / Limitations

- No actual document import yet (placeholder detail view)
- No summary generation (Build 2)
- No file parsing (Build 2)
- Basic styling (macOS system defaults)

## Next Steps: Build 2

Build 2 will add:
- Document import with file picker
- MockSummarisationService
- 2-second processing simulation
- Document list view
- Processing status indicators
- Real document → summary workflow

## Requirements

- macOS 14.0+ (Sonoma)
- Xcode 15+
- Apple Silicon or Intel Mac

## Success Criteria ✅

All Build 1 acceptance criteria met:

- ✅ User can create a new project with title and notes
- ✅ User can edit project title and notes
- ✅ User can delete project (with confirmation)
- ✅ Projects persist across app restarts
- ✅ Sidebar shows project list ordered by creation date
- ✅ Empty states shown when no projects exist
- ✅ SwiftData relationships work correctly
