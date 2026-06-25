//
//  ArtifactNode.swift
//  CodeAgentUI
//
//  Artifact 语义图的节点 — 一个 tool 执行产出的结构化投影。
//  Flat + relations 模型（非 tree）：通过 `relatedCallIDs` 表达关联图，UI 负责 grouping。
//

import Foundation

// MARK: - ArtifactNode

/// 工具执行的语义副产物节点。
///
/// Identity = `callID`（协议级 tool identity），一个 tool 至多一个 ArtifactNode。
/// 多个相关 artifact 通过 `relatedCallIDs` 形成 flat graph，UI 可按需 grouping。
///
/// 对照：`ToolCallItem`（raw execution）→ `ArtifactNode`（semantic projection）。
public struct ArtifactNode: Identifiable, Sendable {

    // MARK: - Identity

    public var id: String { callID }

    /// 协议级 tool 标识符，与 `ToolCallItem.callID` 一致。
    public let callID: String

    /// 所属 turn 的协议标识符。
    public let turnID: String

    // MARK: - Type

    /// Artifact 语义种类。
    public let kind: ArtifactKind

    /// 人类可读标题（如文件名、命令）。
    public let title: String

    /// 类型化内容 — v4 中 Artifact 是唯一的 UI 语义输出层。
    public let content: ArtifactContent

    // MARK: - Relations（flat graph）

    /// 关联的同 turn artifact 的 callID 列表。
    /// 例如 `write_file` 产生的 diff 可能关联到 `read_file` 的 file artifact。
    public var relatedCallIDs: [String]

    // MARK: - Init

    public init(
        callID: String,
        turnID: String,
        kind: ArtifactKind,
        title: String,
        content: ArtifactContent,
        relatedCallIDs: [String] = []
    ) {
        self.callID = callID
        self.turnID = turnID
        self.kind = kind
        self.title = title
        self.content = content
        self.relatedCallIDs = relatedCallIDs
    }
}
