//
//  ArtifactPayload.swift
//  CodeAgentUI
//
//  Artifact 的强类型 payload — 每种 kind 对应一个结构化数据。
//  使用 enum + associated value 而非 protocol，避免 type erasure 和 protocol explosion。
//

import Foundation

// MARK: - ArtifactContent

/// Artifact 的类型化内容 — v4 中 Artifact 是唯一的 UI 语义输出层。
/// 由 `ToolSemanticCompiler` 从 `ToolCallItem` 编译并结构化。
public enum ArtifactContent: Sendable {
    case diff(DiffPayload)
    case file(FilePayload)
    case terminal(TerminalPayload)
}

// MARK: - DiffPayload

/// Diff/patch/edit 类工具的结构化产出。
public struct DiffPayload: Sendable {
    /// 目标文件路径（可能为空，如纯 diff 输出）。
    public let filePath: String?
    /// diff 内容（unified diff 或 patch 文本）。
    public let diffContent: String

    public init(filePath: String?, diffContent: String) {
        self.filePath = filePath
        self.diffContent = diffContent
    }
}

// MARK: - FilePayload

/// 文件读取类工具的结构化产出。
public struct FilePayload: Sendable {
    /// 文件路径。
    public let filePath: String
    /// 文件内容。
    public let content: String
    /// 语言标识（如 "swift"、"python"），可缺省。
    public let language: String?

    public init(filePath: String, content: String, language: String?) {
        self.filePath = filePath
        self.content = content
        self.language = language
    }
}

// MARK: - TerminalPayload

/// 终端命令的结构化产出。
public struct TerminalPayload: Sendable {
    /// 执行的命令。
    public let command: String
    /// 终端输出文本。
    public let output: String
    /// 退出码（nil 表示无法确定）。
    public let exitCode: Int?

    public init(command: String, output: String, exitCode: Int?) {
        self.command = command
        self.output = output
        self.exitCode = exitCode
    }
}
