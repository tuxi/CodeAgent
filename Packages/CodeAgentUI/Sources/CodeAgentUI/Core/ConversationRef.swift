//
//  ConversationRef.swift
//  CodeAgentUI
//
//  Created by xiaoyuan on 2026/6/25.
//

import Foundation

/// 会话引用：对应 `POST /v1/conversations` 与 `GET /v1/conversations` 的返回值。
/// v1 只返回 `id`，metadata（title / model / 时间）属于 P1-B。
public struct ConversationRef: Identifiable, Hashable, Sendable, Codable {
    public let id: String

    public init(id: String) {
        self.id = id
    }
}
