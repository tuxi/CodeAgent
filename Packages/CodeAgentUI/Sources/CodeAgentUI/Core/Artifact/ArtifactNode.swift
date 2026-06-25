//
//  ArtifactNode.swift
//  CodeAgentUI
//
//  Artifact 语义图的节点 — 一个 tool 执行产出的结构化投影。
//  v4.3: 关系通过 ArtifactGraph.edges 表达，不再内嵌 relatedCallIDs。
//

import Foundation

// MARK: - ArtifactNode

/// 工具执行的语义副产物节点。
///
/// Identity = `callID`（协议级 tool identity），一个 tool 至多一个 ArtifactNode。
/// 节点间关系由 `ArtifactGraph.edges` 管理，不内嵌于节点中。
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

    // MARK: - Init

    public init(
        callID: String,
        turnID: String,
        kind: ArtifactKind,
        title: String,
        content: ArtifactContent
    ) {
        self.callID = callID
        self.turnID = turnID
        self.kind = kind
        self.title = title
        self.content = content
    }
}
