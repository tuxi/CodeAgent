//
//  ConversationListView.swift
//  CodeAgent
//
//  CodeAgent's desktop-optimized conversation navigator.  It deliberately
//  owns presentation only; conversation data and mutations stay in AgentKit.
//

import SwiftUI
import AgentKit

struct ConversationListView: View {

    private let viewModel: ConversationListViewModel
    @Binding private var selected: ConversationRef?
    private let searchText: String

    @State private var renameTarget: ConversationRef?
    @State private var renameText = ""
    @State private var expandedWorkspaceIDs: Set<String> = []
    @State private var knownWorkspaceIDs: Set<String> = []
    @State private var didInitializeExpansion = false
    @State private var isProjectsExpanded = true

    init(
        viewModel: ConversationListViewModel,
        selected: Binding<ConversationRef?>,
        searchText: String = ""
    ) {
        self.viewModel = viewModel
        self._selected = selected
        self.searchText = searchText
    }

    var body: some View {
        let revision = viewModel.revision

        List(selection: $selected) {
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .listRowSeparator(.hidden)
            }

            if !viewModel.isLoading && filteredConversations.isEmpty && !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            if !groups.isEmpty {
                sectionHeader

                if isProjectsExpanded {
                    ForEach(groups) { group in
                        workspaceGroup(group, revision: revision)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .task { await viewModel.refresh() }
        .onAppear { syncExpandedWorkspaceIDs() }
        .onChange(of: viewModel.revision) { _, _ in syncExpandedWorkspaceIDs() }
        .onChange(of: searchText) { _, newValue in
            guard !newValue.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            isProjectsExpanded = true
            expandedWorkspaceIDs.formUnion(groups.map(\.id))
        }
        .alert("重命名任务", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("任务名称", text: $renameText)
            Button("取消", role: .cancel) { renameTarget = nil }
            Button("确定") {
                let name = renameText.trimmingCharacters(in: .whitespaces)
                if let target = renameTarget, !name.isEmpty {
                    Task {
                        if let updated = await viewModel.renameConversation(target, name: name),
                           selected?.id == updated.id {
                            selected = updated
                        }
                    }
                }
                renameTarget = nil
            }
        }
    }

    private var filteredConversations: [ConversationRef] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return viewModel.conversations }
        return viewModel.conversations.filter {
            $0.id.localizedCaseInsensitiveContains(query)
                || ($0.name ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    private var groups: [WorkspaceGroup] {
        var result: [WorkspaceGroup] = []
        var indexes: [String: Int] = [:]
        for conversation in filteredConversations {
            let descriptor = WorkspaceGroup.Descriptor(conversation: conversation)
            if let index = indexes[descriptor.id] {
                result[index].conversations.append(conversation)
            } else {
                indexes[descriptor.id] = result.count
                result.append(.init(
                    id: descriptor.id,
                    title: descriptor.title,
                    conversations: [conversation]
                ))
            }
        }
        return result
    }

    private var sectionHeader: some View {
        Button { isProjectsExpanded.toggle() } label: {
            HStack(spacing: 7) {
                Text("项目")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Image(systemName: isProjectsExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.top, 13)
            .padding(.bottom, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(.init())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func workspaceGroup(_ group: WorkspaceGroup, revision: Int) -> some View {
        let isExpanded = expandedWorkspaceIDs.contains(group.id)

        Button {
            if isExpanded { expandedWorkspaceIDs.remove(group.id) }
            else { expandedWorkspaceIDs.insert(group.id) }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "folder")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(group.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(.init())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)

        if isExpanded {
            ForEach(group.conversations, id: \.id) { ref in
                conversationRow(ref)
                    .id("\(ref.id)-\(revision)")
                    .tag(ref)
                    .listRowInsets(.init(top: 0, leading: 12, bottom: 0, trailing: 12))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .contextMenu {
                        Button {
                            renameTarget = ref
                            renameText = ref.name ?? ""
                        } label: {
                            Label("重命名", systemImage: "pencil")
                        }
                    }
            }
        }
    }

    private func conversationRow(_ ref: ConversationRef) -> some View {
        HStack(spacing: 8) {
            Text(ref.name ?? ref.id)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            if ref.isPaused {
                Spacer(minLength: 6)
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
            }
//            else if ref.name != nil {
//                Text(String(ref.id.prefix(8)))
//                    .font(.system(size: 11, design: .monospaced))
//                    .foregroundStyle(.tertiary)
//                    .lineLimit(1)
//            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
//        .background {
//            if selected?.id == ref.id {
//                RoundedRectangle(cornerRadius: 8, style: .continuous)
//                    .fill(Color.primary.opacity(0.10))
//            }
//        }
//        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func syncExpandedWorkspaceIDs() {
        let currentIDs = Set(groups.map(\.id))
        guard !currentIDs.isEmpty else { return }
        if !didInitializeExpansion {
            // 每次启动从紧凑的项目概览开始；展开状态只在本次运行内由用户控制。
            expandedWorkspaceIDs = []
            didInitializeExpansion = true
        } else {
            expandedWorkspaceIDs.formUnion(currentIDs.subtracting(knownWorkspaceIDs))
            expandedWorkspaceIDs.formIntersection(currentIDs)
        }
        knownWorkspaceIDs = currentIDs
    }
}

private struct WorkspaceGroup: Identifiable {
    struct Descriptor {
        let id: String
        let title: String

        init(conversation: ConversationRef) {
            guard !conversation.workspacePath.isEmpty else {
                id = "chat"
                title = "聊天"
                return
            }
            if let workspace = conversation.workspace {
                id = "workspace:\(workspace.id)"
                title = workspace.displayName
                return
            }
            let path = URL(fileURLWithPath: conversation.workspacePath).standardizedFileURL.path
            id = "path:\(path)"
            title = URL(fileURLWithPath: path).lastPathComponent
        }
    }

    let id: String
    let title: String
    var conversations: [ConversationRef]
}
