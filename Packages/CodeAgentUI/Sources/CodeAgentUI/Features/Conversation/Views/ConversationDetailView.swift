//
//  ConversationDetailView.swift
//  CodeAgentUI
//
//  中间内容：选中会话的事件时间线 + 底部输入框。
//  点击时间线中的事件会驱动右侧 inspector。
//

import SwiftUI

public struct ConversationDetailView: View {

    @Environment(WorkspaceStore.self) private var store
    @Environment(AgentRouter.self) private var router

    @State private var messageText = ""

    private let conversationID: String?
    private let viewModel: ConversationViewModel?

    public init(conversationID: String? = nil) {
        self.conversationID = conversationID
        // viewModel 由 environment 或外部注入
        self.viewModel = nil
    }

    /// 带 ViewModel 的初始化。
    public init(conversationID: String?, viewModel: ConversationViewModel) {
        self.conversationID = conversationID
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let vm = viewModel ?? store.activeConversationViewModel {
                ConversationTimelineView(viewModel: vm)

                // 底部输入区域
                chatInput(vm: vm)
            } else if let id = conversationID, store.conversation(id: id) != nil {
                ConversationTimelineView(viewModel: placeholderViewModel)
            } else {
                ContentUnavailableView(
                    "选择一个会话",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("从左侧列表选择，查看对话详情")
                )
            }
        }
        .toolbar { toolbarContent }
    }

    // MARK: - Chat Input

    private func chatInput(vm: ConversationViewModel) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 8) {
                TextField("输入消息...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button {
                    guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    let text = messageText
                    messageText = ""
                    Task { await vm.sendMessage(text) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Placeholder (no active VM)

    private var placeholderViewModel: ConversationViewModel {
        let vm = ConversationViewModel(client: store.client)
        return vm
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Button {
                router.presentSheet(.pickerCategory)
            } label: {
                Label("新建", systemImage: "square.and.pencil")
            }
        }
        ToolbarItem {
            Button {
                store.isInspectorPresented.toggle()
            } label: {
                Label("详情", systemImage: "sidebar.right")
            }
            .disabled(conversationID == nil)
        }
    }
}
