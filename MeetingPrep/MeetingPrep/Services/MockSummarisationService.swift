//
//  MockSummarisationService.swift
//  MeetingPrep
//
//  Phase 1: Mocked summarisation with hardcoded data
//

import Foundation

/// Simulates LLM summarisation with hardcoded responses and processing delay
@MainActor
class MockSummarisationService {

    /// Simulate processing delay (2 seconds)
    private let processingDelay: Duration = .seconds(2)

    /// Generate a mocked summary for a document
    func generateSummary(for document: Document) async throws -> Summary {
        // Simulate processing time
        try await Task.sleep(for: processingDelay)

        // Return appropriate mocked summary based on document type
        switch document.fileType {
        case .transcript:
            return transcriptMockSummary
        case .audio:
            return audioMockSummary
        case .presentation:
            return presentationMockSummary
        }
    }

    // MARK: - Mocked Summaries

    private var transcriptMockSummary: Summary {
        Summary(
            headline: "Team discussed Q1 roadmap priorities and resource allocation",
            keyPoints: [
                "Feature X approved for Q1 release with March 15 deadline",
                "Hiring two additional engineers by end of February",
                "Weekly sync meetings moved to Tuesdays 10am",
                "Marketing campaign launch aligned with product release"
            ],
            actionItems: [
                ActionItem(
                    description: "Draft technical spec for Feature X",
                    assignee: "Sarah",
                    deadline: "Jan 20"
                ),
                ActionItem(
                    description: "Post job listings",
                    assignee: "HR Team",
                    deadline: "This week"
                ),
                ActionItem(
                    description: "Finalize marketing timeline",
                    assignee: "Mike",
                    deadline: nil
                )
            ],
            participants: ["Sarah Chen", "Mike Rodriguez", "Alex Kim", "Jordan Taylor"],
            fullSummary: """
            The team convened to finalize Q1 priorities and address resource constraints. Feature X was greenlit for the March 15 release, contingent on hiring two additional engineers by month-end. The group agreed to realign weekly syncs to Tuesday mornings to improve cross-functional coordination.

            Marketing presented a revised campaign timeline that synchronizes with the product launch window. Action items were assigned with clear ownership, though some deadlines remain flexible pending final roadmap approval.
            """
        )
    }

    private var audioMockSummary: Summary {
        Summary(
            headline: "Client call reviewing project status and next deliverables",
            keyPoints: [
                "Phase 1 delivered on schedule, client satisfied with quality",
                "Phase 2 scope expanded to include mobile app",
                "Budget increase approved for additional features",
                "Next milestone review scheduled for March 1"
            ],
            actionItems: [
                ActionItem(
                    description: "Send updated project proposal",
                    assignee: "Account Manager",
                    deadline: "Jan 18"
                ),
                ActionItem(
                    description: "Schedule mobile app kickoff",
                    assignee: "Project Lead",
                    deadline: "Next week"
                ),
                ActionItem(
                    description: "Update contract with new scope",
                    assignee: "Legal",
                    deadline: "Jan 25"
                )
            ],
            participants: ["Client Stakeholder", "Account Manager", "Project Lead"],
            fullSummary: """
            The client expressed strong satisfaction with Phase 1 deliverables, noting the team met all deadlines and quality benchmarks. Based on initial success, they requested scope expansion to include a mobile companion app.

            Budget discussions concluded with approval for the enhanced feature set. The team will reconvene on March 1 to review Phase 2 progress and validate the mobile app roadmap.
            """
        )
    }

    private var presentationMockSummary: Summary {
        Summary(
            headline: "Sales deck outlining product vision and competitive positioning",
            keyPoints: [
                "Product targets mid-market B2B segment with 50-500 employees",
                "Key differentiator: AI-powered automation vs manual workflows",
                "Pricing: $99/user/month with annual contracts",
                "Go-to-market strategy focuses on partner channels"
            ],
            actionItems: [
                ActionItem(
                    description: "Finalize demo environment",
                    assignee: "Product Team",
                    deadline: "Feb 1"
                ),
                ActionItem(
                    description: "Recruit 3 channel partners",
                    assignee: "Sales",
                    deadline: "End of Q1"
                ),
                ActionItem(
                    description: "Create customer case studies",
                    assignee: "Marketing",
                    deadline: "Feb 15"
                )
            ],
            participants: ["Sales Team", "Product Team", "Marketing"],
            fullSummary: """
            The sales deck positions the product as an AI-first solution for mid-market companies seeking to automate repetitive workflows. Competitive analysis highlights significant time savings versus legacy manual processes.

            Pricing strategy balances accessibility with revenue targets, while the partner-led go-to-market approach leverages existing distribution channels to accelerate market penetration.
            """
        )
    }
}
