//
//  ArtifactNode.swift
//  CodeAgentUI
//
//  Work Product 语义图节点 — P4.4 升级为 work-product-centric 模型。
//  三层结构：summary（Timeline 展示）→ path（元数据/导航）→ content（可滚动详情）。
//

import Foundation

// MARK: - ArtifactNode

/// 工具执行产生的 Work Product 节点。
///
/// Identity = `callID`（协议级 tool identity）。
/// 节点间关系由 `ArtifactGraph.edges` 管理。
///
/// 三层信息结构（对照 Claude Code）：
/// 1. `summary` — Timeline 显示，极短（如 "Edited file.swift +3 -1"）
/// 2. `path` — 文件路径或命令，可导航/可点击
/// 3. `content` — 可滚动详情（文件内容/diff/终端输出）
public struct ArtifactNode: Identifiable, Sendable {

    // MARK: - Identity

    public var id: String { callID }

    /// 协议级 tool 标识符。
    public let callID: String

    /// 所属 turn 的协议标识符。
    public let turnID: String

    // MARK: - Type

    /// Work Product 语义种类（P4.4: fileEdited/fileCreated/commandRun...）。
    public let kind: WorkProductKind

    // MARK: - Three-tier structure

    /// Timeline 展示摘要（如 "Edited skill-model.md +1 -1"）。
    public let summary: String

    /// 文件路径或命令（可导航的元数据，不在滚动区域内）。
    public let path: String?

    /// 可滚动详情内容。
    public let content: ArtifactContent

    // MARK: - Init

    public init(
        callID: String,
        turnID: String,
        kind: WorkProductKind,
        summary: String,
        path: String?,
        content: ArtifactContent
    ) {
        self.callID = callID
        self.turnID = turnID
        self.kind = kind
        self.summary = summary
        self.path = path
        self.content = content
    }
}
