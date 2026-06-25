//
//  ApprovalRequest.swift
//  CodeAgentUI
//
//  DTO for `approval_request` control frames.
//  对照：`docs/client_integration_v1.md` §3.4。
//

import Foundation
import CoreKit

/// 审批请求：服务端推给客户端，要求用户确认副作用操作。
/// `id` 是关联键 — 回复 `approval_response` 时必须原样带回。
public struct ApprovalRequest: Sendable, Identifiable, Hashable {
    public let id: String
    public let toolName: String
    /// 结构化 JSON 对象，如 `{"command": "git push"}`。
    public let toolArgs: JSONValue?
    /// 超时毫秒数；deadline 内不回复视为拒绝。
    public let deadlineMs: Int?
    /// v1 可能缺省（审批器当前无 turn 上下文），按可选处理。
    public let sessionId: String?
    public let turnId: String?

    public init(
        id: String,
        toolName: String,
        toolArgs: JSONValue?,
        deadlineMs: Int?,
        sessionId: String?,
        turnId: String?
    ) {
        self.id = id
        self.toolName = toolName
        self.toolArgs = toolArgs
        self.deadlineMs = deadlineMs
        self.sessionId = sessionId
        self.turnId = turnId
    }

    /// 从 WireFrame 构造。
    static func from(wire: WireFrame) -> ApprovalRequest? {
        guard wire.type == "approval_request", let id = wire.id else { return nil }
        return ApprovalRequest(
            id: id,
            toolName: wire.toolName ?? "unknown",
            toolArgs: wire.toolArgs,
            deadlineMs: wire.deadlineMs,
            sessionId: wire.sessionId,
            turnId: wire.turnId
        )
    }
}
