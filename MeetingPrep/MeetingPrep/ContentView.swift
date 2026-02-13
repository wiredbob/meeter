//
//  ContentView.swift
//  MeetingPrep
//
//  Build 2: Document import and mocked summarisation
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]
    @State private var selectedProject: Project?
    @State private var selectedDocument: Document?
    @State private var showingCreateProject = false
    @State private var projectToDelete: Project?
    @State private var triggerImport = false

    var body: some View {
        NavigationSplitView {
            ProjectListView(
                projects: projects,
                selectedProject: $selectedProject,
                showingCreateProject: $showingCreateProject,
                projectToDelete: $projectToDelete
            )
        } content: {
            if let project = selectedProject {
                ProjectDetailView(
                    project: project,
                    selectedDocument: $selectedDocument,
                    modelContext: modelContext,
                    triggerImport: $triggerImport
                )
            } else {
                ContentUnavailableView(
                    "No Project Selected",
                    systemImage: "folder",
                    description: Text("Select a project from the sidebar")
                )
            }
        } detail: {
            if let document = selectedDocument, let summary = document.summary {
                SummaryDetailView(document: document, summary: summary)
            } else if selectedDocument != nil {
                ContentUnavailableView(
                    "Processing...",
                    systemImage: "hourglass",
                    description: Text("Summary will appear shortly")
                )
            } else {
                ContentUnavailableView(
                    "No Document Selected",
                    systemImage: "doc",
                    description: Text("Select a document to view its summary")
                )
            }
        }
        .sheet(isPresented: $showingCreateProject) {
            ProjectEditView(mode: .create) { title, notes in
                createProject(title: title, notes: notes)
            }
        }
        .alert(
            "Delete Project",
            isPresented: .constant(projectToDelete != nil),
            presenting: projectToDelete
        ) { project in
            Button("Cancel", role: .cancel) {
                projectToDelete = nil
            }
            Button("Delete", role: .destructive) {
                deleteProject(project)
                projectToDelete = nil
            }
        } message: { project in
            Text("Delete '\(project.title)' and all associated documents? This cannot be undone.")
        }
        .onChange(of: triggerImport) { _, newValue in
            if newValue {
                triggerImport = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .createProject)) { _ in
            showingCreateProject = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .importDocument)) { _ in
            if selectedProject != nil {
                triggerImport = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .deleteDocument)) { _ in
            if let doc = selectedDocument {
                deleteDocument(doc)
            }
        }
    }

    private func createProject(title: String, notes: String) {
        let newProject = Project(title: title, notes: notes)
        modelContext.insert(newProject)
        try? modelContext.save()
        selectedProject = newProject
    }

    private func deleteProject(_ project: Project) {
        if selectedProject?.id == project.id {
            selectedProject = nil
        }
        modelContext.delete(project)
        try? modelContext.save()
    }

    private func deleteDocument(_ document: Document) {
        if selectedDocument?.id == document.id {
            selectedDocument = nil
        }
        modelContext.delete(document)
        try? modelContext.save()
    }
}

// MARK: - Project List View

struct ProjectListView: View {
    let projects: [Project]
    @Binding var selectedProject: Project?
    @Binding var showingCreateProject: Bool
    @Binding var projectToDelete: Project?
    @State private var projectToEdit: Project?

    var body: some View {
        List(selection: $selectedProject) {
            ForEach(projects) { project in
                ProjectRow(project: project)
                    .tag(project)
                    .contextMenu {
                        Button("Edit") {
                            projectToEdit = project
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            projectToDelete = project
                        }
                    }
            }
        }
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateProject = true
                } label: {
                    Label("New Project", systemImage: "plus")
                }
            }
        }
        .overlay {
            if projects.isEmpty {
                ContentUnavailableView(
                    "No Projects",
                    systemImage: "folder",
                    description: Text("Click + to create your first project")
                )
            }
        }
        .sheet(item: $projectToEdit) { project in
            ProjectEditView(mode: .edit(project)) { title, notes in
                project.title = title
                project.notes = notes
                project.touch()
            }
        }
    }
}

// MARK: - Project Row

struct ProjectRow: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.title)
                .font(.headline)

            HStack(spacing: 8) {
                Label("\(project.documents.count)", systemImage: "doc")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(project.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Project Edit View (Sheet)

struct ProjectEditView: View {
    enum Mode {
        case create
        case edit(Project)

        var title: String {
            switch self {
            case .create: return "New Project"
            case .edit: return "Edit Project"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let mode: Mode
    let onSave: (String, String) -> Void

    @State private var title: String
    @State private var notes: String

    init(mode: Mode, onSave: @escaping (String, String) -> Void) {
        self.mode = mode
        self.onSave = onSave

        switch mode {
        case .create:
            _title = State(initialValue: "")
            _notes = State(initialValue: "")
        case .edit(let project):
            _title = State(initialValue: project.title)
            _notes = State(initialValue: project.notes)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Project Title", text: $title)
                } header: {
                    Text("Title")
                }

                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                } header: {
                    Text("Notes")
                } footer: {
                    Text("Optional notes about this project")
                }
            }
            .formStyle(.grouped)
            .navigationTitle(mode.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(width: 400, height: 300)
    }

    private func save() {
        onSave(title, notes)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Project Detail View (Build 2)

struct ProjectDetailView: View {
    @Bindable var project: Project
    @Binding var selectedDocument: Document?
    let modelContext: ModelContext
    @Binding var triggerImport: Bool

    @State private var isImporting = false
    @State private var processingDocuments: Set<UUID> = []
    @State private var documentToDelete: Document?

    private let mockService = MockSummarisationService()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.title)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("\(project.documents.count) documents")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    isImporting = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Document List
            if project.documents.isEmpty {
                ContentUnavailableView(
                    "No Documents",
                    systemImage: "doc",
                    description: Text("Click Import to add documents")
                )
            } else {
                List(selection: $selectedDocument) {
                    ForEach(project.documents) { document in
                        DocumentRow(
                            document: document,
                            isProcessing: processingDocuments.contains(document.id)
                        )
                        .tag(document)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                documentToDelete = document
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
                .listStyle(.sidebar)
                .animation(.smooth, value: project.documents.count)
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: allowedFileTypes,
            allowsMultipleSelection: true
        ) { result in
            Task {
                await handleImport(result)
            }
        }
        .alert(
            "Delete Document",
            isPresented: .constant(documentToDelete != nil),
            presenting: documentToDelete
        ) { document in
            Button("Cancel", role: .cancel) {
                documentToDelete = nil
            }
            Button("Delete", role: .destructive) {
                deleteDocument(document)
                documentToDelete = nil
            }
        } message: { document in
            Text("Delete '\(document.fileName)'? This cannot be undone.")
        }
        .onChange(of: triggerImport) { _, newValue in
            if newValue {
                isImporting = true
            }
        }
    }

    private var allowedFileTypes: [UTType] {
        [
            .plainText,         // .txt
            .json,              // .json
            .mp3,               // .mp3
            .mpeg4Audio,        // .m4a
            .wav,               // .wav
            .pdf,               // .pdf
            UTType(filenameExtension: "vtt")!,   // .vtt
            UTType(filenameExtension: "srt")!,   // .srt
            UTType(filenameExtension: "pptx")!,  // .pptx
            UTType(filenameExtension: "key")!,   // .key
        ]
    }

    private func handleImport(_ result: Result<[URL], Error>) async {
        guard case .success(let urls) = result else { return }

        for url in urls {
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access security-scoped resource for: \(url)")
                continue
            }

            defer {
                url.stopAccessingSecurityScopedResource()
            }

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

            // Generate summary using real file parsing
            do {
                let summary = try await mockService.generateSummary(for: document, fileURL: url)
                summary.document = document
                document.summary = summary
                modelContext.insert(summary)
                try? modelContext.save()
            } catch {
                print("Failed to generate summary: \(error)")
                // Create error summary
                let errorSummary = Summary(
                    headline: "Error parsing \(document.fileName)",
                    keyPoints: ["Error: \(error.localizedDescription)"],
                    actionItems: [],
                    participants: [],
                    fullSummary: "Failed to parse file: \(error.localizedDescription)"
                )
                errorSummary.document = document
                document.summary = errorSummary
                modelContext.insert(errorSummary)
                try? modelContext.save()
            }

            // Remove from processing
            await MainActor.run {
                processingDocuments.remove(document.id)
            }
        }
    }

    private func deleteDocument(_ document: Document) {
        if selectedDocument?.id == document.id {
            selectedDocument = nil
        }
        modelContext.delete(document)
        try? modelContext.save()
    }
}

// MARK: - Document Row

struct DocumentRow: View {
    let document: Document
    let isProcessing: Bool

    var body: some View {
        HStack(spacing: 12) {
            // File type icon
            Image(systemName: document.fileType.iconName)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(document.fileName)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(document.fileType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text(document.fileSizeFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text(document.importedAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Processing indicator or checkmark
            if isProcessing {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 20, height: 20)
            } else if document.isProcessed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Summary Detail View (Build 4)

struct SummaryDetailView: View {
    let document: Document
    let summary: Summary

    @State private var showingExportMenu = false
    @State private var copiedSection: String?
    @State private var selectedTab: SummaryTab = .summary

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

                // Export menu
                Menu {
                    Button {
                        ExportService.copyToClipboard(summary: summary, document: document, format: .markdown)
                        showCopiedToast()
                    } label: {
                        Label("Copy as Markdown", systemImage: "doc.on.clipboard")
                    }

                    Button {
                        ExportService.copyToClipboard(summary: summary, document: document, format: .plainText)
                        showCopiedToast()
                    } label: {
                        Label("Copy as Text", systemImage: "doc.plaintext")
                    }

                    Divider()

                    Button {
                        ExportService.saveToFile(summary: summary, document: document, format: .markdown)
                    } label: {
                        Label("Export as Markdown...", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        ExportService.saveToFile(summary: summary, document: document, format: .plainText)
                    } label: {
                        Label("Export as Text...", systemImage: "square.and.arrow.down")
                    }
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

    // MARK: - Formatted Summary View

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

                // Key Points
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

                // Action Items
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

                // Participants
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
                        .textSelection(.enabled)
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

    // MARK: - Raw Text View

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

// MARK: - Action Item Row

struct ActionItemRow: View {
    let item: ActionItem

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.description)
                    .font(.body)

                HStack(spacing: 12) {
                    if let assignee = item.assignee {
                        HStack(spacing: 4) {
                            Image(systemName: "person")
                                .font(.caption2)
                            Text(assignee)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }

                    if let deadline = item.deadline {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(deadline)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Flow Layout Helper

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Project.self, Document.self, Summary.self], inMemory: true)
}
