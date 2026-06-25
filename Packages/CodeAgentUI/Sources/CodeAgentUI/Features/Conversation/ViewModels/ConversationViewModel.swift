//
//  ConversationViewModel.swift
//  CodeAgentUI
//
//  单个会话的 ViewModel。持有 `ConversationState`（Turn State Machine）并暴露给 View。
//  通过 `RuntimeClient` 消费 agent-wire v1 事件流。
//  支持「先补历史、再接实时流」恢复流程。
//

import SwiftUI
import CoreKit

// MARK: - ConversationViewModel

@MainActor
@Observable
public final class ConversationViewModel {

    /// Turn State Machine — UI 唯一数据源（替代旧 TimelineState）。
    public private(set) var state = ConversationState()

    /// 当前会话引用。
    public private(set) var conversation: ConversationRef?

    /// P5.0 — 本会话绑定的工作区（创建时锁定，不可变）。
    /// 新建会话由 `commitDraft` 注入；从侧栏打开的历史会话回退到 `detail?.workspacePath`。
    public let workspace: Workspace?

    /// 是否已连接事件流。
    public private(set) var isConnected = false

    /// 会话概要（来自 `GET /v1/conversations/{id}`）。
    public private(set) var detail: ConversationDetail?

    /// 对话主干（来自 `GET /v1/conversations/{id}/messages`）。
    public private(set) var messages: [Message] = []

    private let client: RuntimeClient
    private var streamTask: Task<Void, Never>?

    // MARK: - Init

    public init(client: RuntimeClient, workspace: Workspace? = nil) {
        self.client = client
        self.workspace = workspace
    }

    /// 本会话用于展示的工作区标签：优先绑定的 `Workspace`，否则回退到 detail 里的路径名。
    public var workspaceDisplayName: String? {
        if let workspace { return workspace.name }
        if let path = detail?.workspacePath, !path.isEmpty {
            return URL(fileURLWithPath: path).lastPathComponent
        }
        return nil
    }

    // MARK: - Public API

    /// 连接指定会话：先拉历史回放 Timeline，再连 WS 收增量。
    /// 规范推荐恢复流程：`GET /events` → 渲染 → `connect()` → 增量。
    public func connect(to conversation: ConversationRef) async {
        self.conversation = conversation
        state = ConversationState()
        detail = nil
        messages = []

        // Phase 1: 拉取历史数据
        await fetchHistory(conversationID: conversation.id)

        // Phase 2: 连接实时流
        do {
            let stream = try await client.connect(conversationID: conversation.id)
            isConnected = true

            streamTask = Task { [weak self] in
                guard let self else { return }
                for await event in stream {
                    await self.handleEvent(event)
                }
                await self.setDisconnected()
            }
        } catch {
            isConnected = false
        }
    }

    /// 发送消息，驱动一轮对话。
    public func sendMessage(_ text: String) async {
        await client.sendMessage(text)
    }

    /// 回复审批请求。
    public func approve(id: String, approved: Bool) async {
        await client.sendApproval(id: id, approved: approved)
        state.resolveApproval(id: id, approved: approved)
    }

    /// 取消当前 turn。
    public func cancelTurn() async {
        await client.cancelTurn()
        if let id = state.currentTurnID {
            state.turns[id]?.status = .cancelled
            state.currentTurnID = nil
        }
    }

    /// 断开连接。
    public func disconnect() async {
        streamTask?.cancel()
        streamTask = nil
        await client.disconnect()
        isConnected = false
        conversation = nil
    }

    // MARK: - History

    /// 拉取会话详情、消息主干、历史事件，回放到 ConversationState。
    private func fetchHistory(conversationID: String) async {
        async let detailTask = try? client.getConversationDetail(id: conversationID)
        async let messagesTask = try? client.getMessages(conversationID: conversationID)
        async let eventsTask = try? client.getEvents(conversationID: conversationID)

        let (detailResult, messagesResult, eventsResult) = await (detailTask, messagesTask, eventsTask)

        self.detail = detailResult
        self.messages = messagesResult ?? []

        if let events = eventsResult {
            for event in events {
                state.reduce(event)
            }
        }
        state.historyReplayed = true
    }

    // MARK: - Event handling

    private func handleEvent(_ event: AgentEvent) async {
        state.reduce(event)
    }

    private func setDisconnected() async {
        isConnected = false
    }
}
