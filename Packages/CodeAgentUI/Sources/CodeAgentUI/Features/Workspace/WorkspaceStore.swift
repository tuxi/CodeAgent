//
//  WorkspaceStore.swift
//  CodeAgentUI
//
//  三栏工作区的 UI 状态中心：
//  - `selectedTab`：侧栏顶部一级分区
//  - `selectedConversationID`：驱动中间对话详情
//  - `inspectorSelection` / `isInspectorPresented`：驱动右侧 `.inspector` 详情
//  - 持有 `RuntimeClient`，管理 `ConversationListViewModel` 和活跃的 `ConversationViewModel`
//

import SwiftUI

/// 三栏工作区的 UI 选中态。
/// 这里只放"选中态"和 ViewModel 管理，跨栏的二级 push / sheet / cover 由 `AgentRouter` 负责。
@MainActor
@Observable
public final class WorkspaceStore {

    // MARK: - Tab & Selection

    public var selectedTab: SidebarTab = .workflow {
        didSet {
            guard oldValue != selectedTab else { return }
            selectedConversationID = nil
            dismissInspector()
        }
    }

    public var selectedConversationID: String? {
        didSet {
            guard oldValue != selectedConversationID else { return }
            if let id = selectedConversationID {
                Task { await connectToConversation(id: id) }
            } else {
                activeConversationViewModel = nil
            }
        }
    }

    public private(set) var inspectorSelection: InspectorSelection?
    public var isInspectorPresented: Bool = false

    // MARK: - Runtime Client

    /// 与 CodeAgent Runtime 通信的客户端（agent-wire v1）。
    public let client: RuntimeClient

    // MARK: - ViewModels

    /// 侧栏会话列表的 ViewModel。
    public let listViewModel: ConversationListViewModel

    /// 当前选中会话的 ViewModel（nil 表示未选中或 mock 模式）。
    public private(set) var activeConversationViewModel: ConversationViewModel?

    // MARK: - Init

    public init(client: RuntimeClient = DefaultAgentClient()) {
        self.client = client
        self.listViewModel = ConversationListViewModel(client: client)
    }

    // MARK: - Conversation Management

    /// 连接指定会话并开始消费事件流。
    private func connectToConversation(id: String) async {
        let vm = ConversationViewModel(client: client)
        let ref = ConversationRef(id: id)
        await vm.connect(to: ref)
        activeConversationViewModel = vm
    }

    // MARK: - Inspector

    /// 点击对话详情里的某个内容时调用，弹出右侧检查器。
    public func showInspector(_ selection: InspectorSelection) {
        inspectorSelection = selection
        isInspectorPresented = true
    }

    public func dismissInspector() {
        inspectorSelection = nil
        isInspectorPresented = false
    }
}

// MARK: - Legacy mock bridge

extension WorkspaceStore {
    /// 向后兼容 — 来自 ConversationRef 列表的视图数据。
    /// 待 `ConversationSummary` 完成迁移后可移除。
    public func conversation(id: String?) -> ConversationSummary? {
        guard let id, let ref = listViewModel.conversations.first(where: { $0.id == id }) else {
            return nil
        }
        return ConversationSummary(
            id: ref.id,
            tab: selectedTab,
            title: ref.id,
            subtitle: "v1 会话",
            updatedAt: .now
        )
    }

    /// 向后兼容 — mock conversations 已被 listViewModel 替代。
    @available(*, deprecated, message: "使用 listViewModel.conversations")
    public var conversations: [ConversationSummary] {
        listViewModel.conversations.map { ref in
            ConversationSummary(
                id: ref.id,
                tab: selectedTab,
                title: ref.id,
                subtitle: "v1 会话",
                updatedAt: .now
            )
        }
    }
}
