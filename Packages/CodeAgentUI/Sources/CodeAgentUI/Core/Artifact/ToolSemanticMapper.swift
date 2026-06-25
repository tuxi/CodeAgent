//
//  ToolSemanticMapper.swift
//  CodeAgentUI
//
//  Domain-layer semantic mapper — 将 raw ToolCallItem 映射为 ArtifactNode。
//  纯函数、无状态、无 UI 依赖。Metadata First + Observation Fallback 策略。
//
//  架构位置：ConversationState reducer → ToolSemanticMapper → ArtifactNode
//  对照：`ToolCallItem`（raw execution）→ `ArtifactNode`（semantic projection）。
//

import Foundation
import CoreKit

// MARK: - ToolSemanticMapper

/// 工具执行的语义映射器。
/// 从 `ToolCallItem` 的 toolName + toolArgs + observation 中提取结构化 Artifact。
public struct ToolSemanticCompiler {

    /// 将一个已完成的 `ToolCallItem` 映射为可选的 `ArtifactNode`。
    /// - Parameters:
    ///   - tool: 已完成的工具调用项（须含 result）。
    ///   - turnID: 所属 turn 的协议标识符。
    /// - Returns: 语义映射后的 ArtifactNode；非 artifact 类工具返回 nil。
    public static func compile(_ tool: ToolCallItem, turnID: String) -> ArtifactNode? {
        guard tool.status == .completed || tool.status == .failed else { return nil }
        guard let kind = determineKind(toolName: tool.toolName) else { return nil }

        let title = extractTitle(tool: tool, kind: kind)
        let content = buildContent(tool: tool, kind: kind)

        guard let content else { return nil }

        return ArtifactNode(
            callID: tool.callID,
            turnID: turnID,
            kind: kind,
            title: title,
            content: content
        )
    }

    // MARK: - Kind determination (Metadata First)

    private static func determineKind(toolName: String) -> ArtifactKind? {
        let name = toolName.lowercased()

        // Diff / patch / edit tools
        let diffPatterns = ["write", "edit", "patch", "diff", "apply", "create", "save"]
        for p in diffPatterns where name.contains(p) {
            return .diff
        }

        // File read / view tools
        let filePatterns = ["read", "cat", "view", "open", "get", "list"]
        for p in filePatterns where name.contains(p) {
            return .file
        }

        // Terminal / shell tools
        let termPatterns = ["bash", "shell", "exec", "terminal", "run", "cmd"]
        for p in termPatterns where name.contains(p) {
            return .terminal
        }

        return nil
    }

    // MARK: - Title extraction

    private static func extractTitle(tool: ToolCallItem, kind: ArtifactKind) -> String {
        switch kind {
        case .diff, .file:
            return extractFilePath(from: tool) ?? tool.toolName
        case .terminal:
            return extractCommand(from: tool) ?? tool.toolName
        }
    }

    // MARK: - Content construction (Metadata First + Observation Fallback)

    private static func buildContent(tool: ToolCallItem, kind: ArtifactKind) -> ArtifactContent? {
        switch kind {
        case .diff:
            return buildDiffContent(tool)
        case .file:
            return buildFileContent(tool)
        case .terminal:
            return buildTerminalContent(tool)
        }
    }

    // MARK: Diff

    private static func buildDiffContent(_ tool: ToolCallItem) -> ArtifactContent? {
        let filePath = extractFilePath(from: tool)
        // Primary: observation as diff content
        let diffContent = tool.result?.observation ?? ""
        return .diff(DiffPayload(filePath: filePath, diffContent: diffContent))
    }

    // MARK: File

    private static func buildFileContent(_ tool: ToolCallItem) -> ArtifactContent? {
        let filePath = extractFilePath(from: tool) ?? "unknown"
        // Primary: observation as file content
        let content = tool.result?.observation ?? ""
        // Language: args first, then infer from extension
        let language = extractLanguage(from: tool, filePath: filePath)
        return .file(FilePayload(filePath: filePath, content: content, language: language))
    }

    // MARK: Terminal

    private static func buildTerminalContent(_ tool: ToolCallItem) -> ArtifactContent? {
        let command = extractCommand(from: tool) ?? "unknown"
        // Primary: observation as terminal output
        let output = tool.result?.observation ?? ""
        let exitCode = extractExitCode(from: tool)
        return .terminal(TerminalPayload(command: command, output: output, exitCode: exitCode))
    }

    // MARK: - Field extractors (args → observation fallback)

    /// 提取文件路径：toolArgs 优先，observation 降级。
    private static func extractFilePath(from tool: ToolCallItem) -> String? {
        // Primary: toolArgs structured fields
        if let args = tool.toolArgs {
            let path = args["file_path"].stringValue
            if !path.isEmpty { return path }
            let altPath = args["path"].stringValue
            if !altPath.isEmpty { return altPath }
            let file = args["file"].stringValue
            if !file.isEmpty { return file }
        }

        // Fallback: parse from observation (common patterns like "--- a/path" or "+++ b/path")
        if let obs = tool.result?.observation {
            return parseFilePathFromObservation(obs)
        }

        return nil
    }

    /// 提取命令：toolArgs 优先，observation 降级。
    private static func extractCommand(from tool: ToolCallItem) -> String? {
        // Primary: toolArgs
        if let args = tool.toolArgs {
            let cmd = args["command"].stringValue
            if !cmd.isEmpty { return cmd }
            let altCmd = args["cmd"].stringValue
            if !altCmd.isEmpty { return altCmd }
        }

        // Fallback: parse from observation
        if let obs = tool.result?.observation {
            return parseCommandFromObservation(obs)
        }

        return nil
    }

    /// 提取语言：args 优先，文件扩展名推断。
    private static func extractLanguage(from tool: ToolCallItem, filePath: String) -> String? {
        // Primary: toolArgs
        if let args = tool.toolArgs {
            let lang = args["language"].stringValue
            if !lang.isEmpty { return lang }
        }

        // Fallback: infer from file extension
        return inferLanguage(from: filePath)
    }

    /// 提取退出码：从 observation 中解析。
    private static func extractExitCode(from tool: ToolCallItem) -> Int? {
        // Primary: toolArgs
        if let args = tool.toolArgs {
            let code = args["exit_code"].intValue
            if code != 0 || args["exit_code"].stringValue == "0" { return code }
        }

        // Fallback: parse from observation
        if let obs = tool.result?.observation {
            return parseExitCodeFromObservation(obs)
        }

        return nil
    }

    // MARK: - Observation fallback parsers

    private static func parseFilePathFromObservation(_ obs: String) -> String? {
        // Match common diff/patch path patterns
        let patterns = [
            #"^\+\+\+ b/(.+)$"#,         // "+++ b/path/to/file.swift"
            #"^--- a/(.+)$"#,             // "--- a/path/to/file.swift"
            #"^(?:File|Path):\s*(.+)$"#,  // "File: path/to/file.swift"
            #"^#+\s*(.+\.\w+)"#,          // "## path/to/file.swift"
        ]
        for pattern in patterns {
            if let match = obs.firstMatch(for: pattern) {
                return match
            }
        }
        return nil
    }

    private static func parseCommandFromObservation(_ obs: String) -> String? {
        // Match "$ command" pattern
        if let match = obs.firstMatch(for: #"^\$\s+(.+)$"#) {
            return match
        }
        // Use first non-empty line as command
        let firstLine = obs.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespaces)
        if let line = firstLine, !line.isEmpty, line.count < 200 {
            return line
        }
        return nil
    }

    private static func parseExitCodeFromObservation(_ obs: String) -> Int? {
        let patterns = [
            #"exit(?:\s*code)?[:\s]*(\d+)"#,
            #"exited with (\d+)"#,
            #"\[exit[:\s]*(\d+)\]"#,
        ]
        for pattern in patterns {
            if let match = obs.firstMatch(for: pattern) {
                return Int(match)
            }
        }
        return nil
    }

    private static func inferLanguage(from filePath: String) -> String? {
        let ext = (filePath as NSString).pathExtension.lowercased()
        let map: [String: String] = [
            "swift": "swift", "m": "objc", "h": "objc",
            "py": "python", "js": "javascript", "ts": "typescript",
            "go": "go", "rs": "rust", "java": "java", "kt": "kotlin",
            "c": "c", "cpp": "cpp", "hpp": "cpp",
            "rb": "ruby", "php": "php", "sh": "bash", "bash": "bash",
            "yaml": "yaml", "yml": "yaml", "json": "json", "xml": "xml",
            "md": "markdown", "sql": "sql",
            "html": "html", "css": "css", "scss": "scss",
        ]
        return map[ext] ?? (ext.isEmpty ? nil : ext)
    }
}

// MARK: - Regex helper

private extension String {
    func firstMatch(for pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]),
              let match = regex.firstMatch(in: self, range: NSRange(startIndex..., in: self)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: self) else {
            return nil
        }
        return String(self[range])
    }
}
