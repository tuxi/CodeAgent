//
//  ConversationDetail.swift
//  CodeAgentUI
//
//  DTO for `GET /v1/conversations/{id}` — 由事件派生的会话概要。
//  规范：`docs/client_integration_v1.md` §2 (历史读取)。
//

import Foundation

/// 会话概要（由已记录事件派生）。
public struct ConversationDetail: Sendable, Codable, Hashable {
    public let id: String
    public let turnCount: Int
    public let messageCount: Int
    public let createdAt: String
    public let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case turnCount = "turn_count"
        case messageCount = "message_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
