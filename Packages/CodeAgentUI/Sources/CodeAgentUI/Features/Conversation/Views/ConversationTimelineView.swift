//
//  ConversationTimelineView.swift
//  CodeAgent
//
//  对话事件时间线。从 `ConversationViewModel.state`（Turn State Machine）读取数据。
//  PR-1：过渡渲染，按 Turn 分组但平铺展示。
//  PR-2：替换为 `TurnCardView`，以 Turn 为完整 UI 单位。
//

import SwiftUI
import CoreKit

public struct ConversationTimelineView: View {

    @Environment(WorkspaceStore.self) private var store
    let viewModel: ConversationViewModel

    public init(viewModel: ConversationViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(viewModel.state.orderedTurns) { turn in
                        TurnCardView(turn: turn, viewModel: viewModel)
                            .id(turn.id)
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.state.orderedTurns.count) { _, _ in
                if let last = viewModel.state.orderedTurns.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - TurnCardView (PR-1 transitional)

/// PR-1 过渡卡片 — 按 Turn 分组但平铺渲染。
/// PR-2 将拆分为完整的 section-based 布局。
private struct TurnCardView: View {
    let turn: TurnGroup
    let viewModel: ConversationViewModel

    @State private var thinkingExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── 用户气泡 ──
            UserBubble(text: turn.userMessage)

            // ── 思考（折叠）──
            if !turn.thoughts.isEmpty {
                ThinkingSection(thoughts: turn.thoughts, isExpanded: $thinkingExpanded)
            }

            // ── 工具调用 ──
            ForEach(turn.toolCallIDs, id: \.self) { callID in
                if let item = turn.toolCalls[callID] {
                    ToolCardView(item: item)
                }
            }

            // ── 审批请求 ──
            ForEach(turn.approvalRequests) { approval in
                if !approval.resolved {
                    ApprovalCardInline(
                        request: approval.request,
                        onApprove: {
                            Task { await viewModel.approve(id: approval.request.id, approved: true) }
                        },
                        onReject: {
                            Task { await viewModel.approve(id: approval.request.id, approved: false) }
                        }
                    )
                }
            }

            // ── Todo ──
            if let lastSnapshot = turn.todoSnapshots.last, !lastSnapshot.todos.isEmpty {
                TodoSectionView(todos: lastSnapshot.todos)
            }

            // ── Subagent ──
            ForEach(turn.subagentRefs) { sub in
                SubagentRow(item: sub)
            }

            // ── 助手气泡（streaming）──
            if !turn.assistantMessage.isEmpty || turn.status == .active {
                AssistantBubble(text: turn.assistantMessage, isStreaming: turn.status == .active)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(turn.status == .active ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Sub-components (PR-1 minimal)

private struct UserBubble: View {
    let text: String

    var body: some View {
        HStack {
            Spacer()
            Text(text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct AssistantBubble: View {
    let text: String
    let isStreaming: Bool

    var body: some View {
        HStack {
            Text(text + (isStreaming ? "|" : ""))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Spacer()
        }
    }
}

private struct ThinkingSection: View {
    let thoughts: [ThoughtItem]
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Label("Thinking", systemImage: "brain")
                        .font(.caption.weight(.medium))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(thoughts) { thought in
                    Text(thought.text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 20)
                }
            }
        }
    }
}

private struct ToolCardView: View {
    let item: ToolCallItem

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: statusIcon)
                        .font(.caption)
                    Text(item.toolName)
                        .font(.caption.monospaced().weight(.medium))
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            if expanded {
                if let args = item.toolArgs, case .object(let dict) = args {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(dict.keys.sorted()), id: \.self) { key in
                            Text("\(key): \(dict[key]?.stringValue ?? "")")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.leading, 20)
                }

                if let result = item.result {
                    if let obs = result.observation, !obs.isEmpty {
                        Text(obs)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 20)
                            .lineLimit(5)
                    }
                    if let err = result.error, !err.isEmpty {
                        Text("Error: \(err)")
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .padding(.leading, 20)
                    }
                }
            }
        }
    }

    private var statusIcon: String {
        switch item.status {
        case .running: return "hourglass"
        case .completed: return "checkmark.circle"
        case .failed: return "xmark.circle"
        }
    }
}

private struct ApprovalCardInline: View {
    let request: ApprovalRequest
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("审批: \(request.toolName)", systemImage: "exclamationmark.shield")
                .font(.caption.weight(.medium))

            HStack(spacing: 8) {
                Button("允许", action: onApprove)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button("拒绝", role: .destructive, action: onReject)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct TodoSectionView: View {
    let todos: [TodoItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(todos, id: \.content) { todo in
                HStack(spacing: 4) {
                    Image(systemName: todo.status == .completed ? "checkmark.circle.fill" : "circle")
                        .font(.caption)
                        .foregroundStyle(todo.status == .completed ? .green : .secondary)
                    Text(todo.activeForm ?? todo.content)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .strikethrough(todo.status == .completed)
                }
            }
        }
    }
}

private struct SubagentRow: View {
    let item: SubagentItem

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "rectangle.stack")
                .font(.caption)
            Text("Sub-agent: \(item.prompt)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
