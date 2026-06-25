//
//  ArtifactKind.swift
//  CodeAgentUI
//
//  Artifact 语义种类 — 从 tool 语义派生，非协议新增字段。
//

import Foundation

// MARK: - ArtifactKind

/// Artifact 的种类，由 `ToolSemanticMapper` 根据 toolName 判定。
/// 不在 agent-wire 协议中传输，纯客户端语义层。
public enum ArtifactKind: String, Sendable, CaseIterable {
    /// diff / patch / edit 类工具产出
    case diff
    /// 文件读取/列表类工具产出
    case file
    /// 终端/shell 命令工具产出
    case terminal
}
