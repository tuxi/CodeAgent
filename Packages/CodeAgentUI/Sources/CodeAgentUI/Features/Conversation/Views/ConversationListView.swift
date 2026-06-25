//
//  ConversationListView.swift
//  CodeAgentUI
//
//  会话列表 — 侧栏内容。从 `ConversationListViewModel` 读取数据。
//

import SwiftUI

struct ConversationListView: View {

    @State private var viewModel: ConversationListViewModel
    @Environment(WorkspaceStore.self) private var store
    @Binding var selectedID: String?

    init(viewModel: ConversationListViewModel, selectedID: Binding<String?>) {
        self.viewModel = viewModel
        self._selectedID = selectedID
    }

    var body: some View {
        List(selection: $selectedID) {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            ForEach(viewModel.conversations) { ref in
                ConversationRow(ref: ref)
                    .tag(ref.id)
            }
        }
        .listStyle(.sidebar)
        .task {
            await viewModel.refresh()
        }
        .toolbar {
            ToolbarItem {
                Button {
                    Task {
                        if let ref = await viewModel.createConversation() {
                            selectedID = ref.id
                        }
                    }
                } label: {
                    Label("新建会话", systemImage: "square.and.pencil")
                }
            }
        }
    }
}

// MARK: - ConversationRow

private struct ConversationRow: View {
    let ref: ConversationRef

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ref.id)
                .font(.body)
                .lineLimit(1)
            Text("v1 — 无 metadata")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
