//
//  ToolSemanticMapper.swift
//  CodeAgentUI
//
//  P4.4: Semantic compiler — 将 raw ToolCallItem 编译为 Work Product。
//  Metadata First + Observation Fallback。
//  输出三层结构：summary（Timeline）→ path（元数据）→ content（详情）。
//

import Foundation
import CoreKit

// MARK: - ToolSemanticCompiler

/// 工具执行的语义编译器。
/// 从 `ToolCallItem` 编译 `ArtifactNode`（Work Product）— 唯一语义输出。
public struct ToolSemanticCompiler {

    /// 编译 Work Product。
    public static func compile(_ tool: ToolCallItem, turnID: String) -> ArtifactNode? {
        guard tool.status == .completed || tool.status == .failed else { return nil }
        guard let kind = determineKind(toolName: tool.toolName) else { return nil }

        let path = extractFilePath(from: tool)
        let content = buildContent(tool: tool, kind: kind)
        guard let content else { return nil }

        let summary = generateSummary(kind: kind, path: path, content: content, tool: tool)

        return ArtifactNode(
            callID: tool.callID,
            turnID: turnID,
            kind: kind,
            summary: summary,
            path: path,
            content: content
        )
    }

    // MARK: - Kind determination → WorkProductKind

    private static func determineKind(toolName: String) -> WorkProductKind? {
        let name = toolName.lowercased()

        // Write / edit / create → fileEdited (default), may refine later
        let writePatterns = ["write", "edit", "patch", "apply", "save"]
        for p in writePatterns where name.contains(p) {
            return .fileEdited
        }

        // Create / new → fileCreated
        let createPatterns = ["create", "new"]
        for p in createPatterns where name.contains(p) {
            return .fileCreated
        }

        // Read / view → fileRead
        let readPatterns = ["read", "cat", "view", "open", "get", "list"]
        for p in readPatterns where name.contains(p) {
            return .fileRead
        }

        // Terminal → commandRun
        let termPatterns = ["bash", "shell", "exec", "terminal", "run", "cmd"]
        for p in termPatterns where name.contains(p) {
            return .commandRun
        }

        // Search / grep / find → searchResult
        let searchPatterns = ["search", "grep", "find", "locate", "rg", "ag"]
        for p in searchPatterns where name.contains(p) {
            return .searchResult
        }

        return nil
    }

    // MARK: - Summary generation

    private static func generateSummary(
        kind: WorkProductKind,
        path: String?,
        content: ArtifactContent,
        tool: ToolCallItem
    ) -> String {
        let fileName = path.map { ($0 as NSString).lastPathComponent } ?? "file"

        switch (kind, content) {
        case (.fileRead, .file(let p)):
            let lines = p.content.components(separatedBy: "\n").count
            return "Read \(fileName) (\(lines) lines)"

        case (.fileCreated, .file(let p)):
            let lines = p.content.components(separatedBy: "\n").count
            return "Created \(fileName) (\(lines) lines)"

        case (.fileEdited, .diff(let p)):
            let added = p.addedLines
            let removed = p.removedLines
            var parts: [String] = []
            if added > 0 { parts.append("+\(added)") }
            if removed > 0 { parts.append("-\(removed)") }
            let delta = parts.isEmpty ? "" : " \(parts.joined(separator: " "))"
            return "Edited \(fileName)\(delta)"

        case (.fileEdited, .file(let p)):
            let lines = p.content.components(separatedBy: "\n").count
            return "Edited \(fileName) (\(lines) lines)"

        case (.commandRun, .terminal(let p)):
            let cmd = p.command
            let shortCmd = cmd.count > 40 ? String(cmd.prefix(40)) + "…" : cmd
            if let code = p.exitCode, code != 0 {
                return "Ran \(shortCmd) (exit \(code))"
            }
            return "Ran \(shortCmd)"

        case (.searchResult, _):
            let query = extractSearchQuery(from: tool) ?? "search"
            return "Search: \(query)"

        default:
            return tool.toolName
        }
    }

    // MARK: - Content construction

    private static func buildContent(tool: ToolCallItem, kind: WorkProductKind) -> ArtifactContent? {
        switch kind {
        case .fileEdited:
            // Prefer diff payload if observation looks like a diff
            let obs = tool.result?.observation ?? ""
            if obs.contains("@@") && (obs.contains("+") || obs.contains("-")) {
                return buildDiffContent(tool)
            }
            return buildFileContent(tool, isNew: false)

        case .fileCreated:
            return buildFileContent(tool, isNew: true)

        case .fileRead:
            return buildFileContent(tool, isNew: false)

        case .commandRun:
            return buildTerminalContent(tool)

        case .searchResult:
            // Search results rendered as file-like content for now
            return buildFileContent(tool, isNew: false)
        }
    }

    // MARK: - Content builders

    private static func buildDiffContent(_ tool: ToolCallItem) -> ArtifactContent? {
        let filePath = extractFilePath(from: tool)
        let diffContent = tool.result?.observation ?? ""
        let (added, removed) = countDiffLines(diffContent)
        return .diff(DiffPayload(
            filePath: filePath,
            diffContent: diffContent,
            addedLines: added,
            removedLines: removed
        ))
    }

    private static func buildFileContent(_ tool: ToolCallItem, isNew: Bool) -> ArtifactContent? {
        let filePath = extractFilePath(from: tool) ?? "unknown"
        let content = tool.result?.observation ?? ""
        let language = extractLanguage(from: tool, filePath: filePath)
        return .file(FilePayload(
            filePath: filePath,
            content: content,
            language: language,
            isNew: isNew
        ))
    }

    private static func buildTerminalContent(_ tool: ToolCallItem) -> ArtifactContent? {
        let command = extractCommand(from: tool) ?? "unknown"
        let output = tool.result?.observation ?? ""
        let exitCode = extractExitCode(from: tool)
        return .terminal(TerminalPayload(command: command, output: output, exitCode: exitCode))
    }

    // MARK: - Diff line counting

    private static func countDiffLines(_ diff: String) -> (added: Int, removed: Int) {
        var added = 0
        var removed = 0
        for line in diff.components(separatedBy: "\n") {
            if line.hasPrefix("+") && !line.hasPrefix("+++") { added += 1 }
            else if line.hasPrefix("-") && !line.hasPrefix("---") { removed += 1 }
        }
        return (added, removed)
    }

    // MARK: - Field extractors

    private static func extractFilePath(from tool: ToolCallItem) -> String? {
        if let args = tool.toolArgs {
            for key in ["file_path", "path", "file", "target"] {
                let v = args[key].stringValue
                if !v.isEmpty { return v }
            }
        }
        if let obs = tool.result?.observation {
            return parseFilePathFromObservation(obs)
        }
        return nil
    }

    private static func extractCommand(from tool: ToolCallItem) -> String? {
        if let args = tool.toolArgs {
            for key in ["command", "cmd"] {
                let v = args[key].stringValue
                if !v.isEmpty { return v }
            }
        }
        if let obs = tool.result?.observation {
            return parseCommandFromObservation(obs)
        }
        return nil
    }

    private static func extractSearchQuery(from tool: ToolCallItem) -> String? {
        if let args = tool.toolArgs {
            for key in ["query", "q", "pattern", "search"] {
                let v = args[key].stringValue
                if !v.isEmpty { return v }
            }
        }
        return nil
    }

    private static func extractLanguage(from tool: ToolCallItem, filePath: String) -> String? {
        if let args = tool.toolArgs {
            let lang = args["language"].stringValue
            if !lang.isEmpty { return lang }
        }
        return inferLanguage(from: filePath)
    }

    private static func extractExitCode(from tool: ToolCallItem) -> Int? {
        if let args = tool.toolArgs {
            let code = args["exit_code"].intValue
            if code != 0 || args["exit_code"].stringValue == "0" { return code }
        }
        if let obs = tool.result?.observation {
            return parseExitCodeFromObservation(obs)
        }
        return nil
    }

    // MARK: - Observation fallback parsers

    private static func parseFilePathFromObservation(_ obs: String) -> String? {
        let patterns = [
            #"^\+\+\+ b/(.+)$"#,
            #"^--- a/(.+)$"#,
            #"^(?:File|Path):\s*(.+)$"#,
            #"^#+\s*(.+\.\w+)"#,
        ]
        for pattern in patterns {
            if let match = obs.firstMatch(for: pattern) { return match }
        }
        return nil
    }

    private static func parseCommandFromObservation(_ obs: String) -> String? {
        if let match = obs.firstMatch(for: #"^\$\s+(.+)$"#) { return match }
        let firstLine = obs.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespaces)
        if let line = firstLine, !line.isEmpty, line.count < 200 { return line }
        return nil
    }

    private static func parseExitCodeFromObservation(_ obs: String) -> Int? {
        let patterns = [
            #"exit(?:\s*code)?[:\s]*(\d+)"#,
            #"exited with (\d+)"#,
            #"\[exit[:\s]*(\d+)\]"#,
        ]
        for pattern in patterns {
            if let match = obs.firstMatch(for: pattern) { return Int(match) }
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
