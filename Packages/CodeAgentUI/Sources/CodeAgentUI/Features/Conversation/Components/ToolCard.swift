//
//  ToolCard.swift
//  CodeAgentUI
//
//  Chronological tool execution card.
//  Shows spinner while running, output on expand, Inspector link for artifacts.
//

import SwiftUI
import CoreKit

struct ToolCard: View {
    let tool: ToolNodePayload
    let store: WorkspaceStore

    @State private var isExpanded: Bool

    init(tool: ToolNodePayload, store: WorkspaceStore) {
        self.tool = tool
        self.store = store
        // Auto-expand while running
        self._isExpanded = State(initialValue: tool.status == .running)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // ── Header ──
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: statusIcon)
                        .font(.caption)
                        .foregroundStyle(statusColor)

                    Text(tool.toolName)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)

                    if tool.status == .running {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                    }

                    if tool.isAutoApproved {
                        Text("auto")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 3)
                            .background(.quaternary)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    if let code = tool.exitCode, code != 0 {
                        Text("exit \(code)")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            // ── Expanded content ──
            if isExpanded {
                Divider()
                    .padding(.vertical, 2)

                // Args
                if let args = tool.args, case .object(let dict) = args, !dict.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(dict.keys.sorted()), id: \.self) { key in
                            Text("\(key): \(dict[key]?.stringValue ?? "")")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                // Output
                if !tool.output.isEmpty {
                    Text(tool.output)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(20)
                        .textSelection(.enabled)
                }

                // Artifact → Inspector link
                if let artifact = tool.artifact {
                    Divider()
                        .padding(.vertical, 2)
                    Button {
                        openInInspector(artifact)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: artifactIcon(for: artifact))
                                .font(.caption2)
                            Text(SummaryRenderer.summary(for: artifact))
                                .font(.caption2)
                                .foregroundStyle(.blue)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Helpers

    private var statusIcon: String {
        if tool.isAutoApproved { return "bolt.fill" }
        switch tool.status {
        case .running: return "hourglass"
        case .completed: return "checkmark.circle"
        case .failed: return "xmark.circle"
        case .autoApproved: return "bolt.fill"
        }
    }

    private var statusColor: Color {
        if tool.isAutoApproved { return .blue }
        switch tool.status {
        case .running: return .secondary
        case .completed: return .green
        case .failed: return .red
        case .autoApproved: return .blue
        }
    }

    private func artifactIcon(for artifact: ArtifactNode) -> String {
        switch artifact.kind {
        case .fileRead: return "doc.text"
        case .fileCreated: return "doc.badge.plus"
        case .fileEdited: return "arrow.triangle.swap"
        case .commandRun: return "terminal"
        case .listFiles: return "folder.fill"
        }
    }

    private func openInInspector(_ artifact: ArtifactNode) {
        switch artifact.content {
        case .file(let payload):
            store.showInspector(.file(payload))
        case .diff(let payload):
            store.showInspector(.diff(payload))
        case .terminal(let payload):
            store.showInspector(.terminal(payload))
        }
    }
}
