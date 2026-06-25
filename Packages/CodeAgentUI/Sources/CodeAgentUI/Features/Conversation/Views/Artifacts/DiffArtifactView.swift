//
//  DiffArtifactView.swift
//  CodeAgentUI
//
//  Diff artifact 渲染 — 等宽字体、+/- 行着色。
//

import SwiftUI

/// Diff/patch artifact 的纯渲染视图。
struct DiffArtifactView: View {
    let filePath: String?
    let diffContent: String

    @State private var isExpanded = false

    private let maxCollapsedLines = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 标题栏
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.caption)
                    Text("Diff: \(filePath ?? "unknown")")
                        .font(.caption.monospaced().weight(.medium))
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(diffLines) { line in
                            Text(line.text)
                                .font(.caption2.monospaced())
                                .foregroundStyle(line.color)
                                .textSelection(.enabled)
                        }
                    }
                }
                .frame(maxHeight: 300)
            } else {
                let preview = previewLines
                if !preview.isEmpty {
                    Text(preview)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(maxCollapsedLines)
                }
            }
        }
        .padding(8)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Line model

    private struct DiffLine: Identifiable {
        let id = UUID()
        let text: String
        let color: Color
    }

    /// 按行着色：+ 绿 / - 红 / @@ 蓝 / 其他 secondary。
    private var diffLines: [DiffLine] {
        diffContent.components(separatedBy: "\n").map { line in
            let color: Color
            if line.hasPrefix("+") {
                color = .green
            } else if line.hasPrefix("-") {
                color = .red
            } else if line.hasPrefix("@@") {
                color = .blue
            } else {
                color = .secondary
            }
            return DiffLine(text: line, color: color)
        }
    }

    private var previewLines: String {
        let lines = diffContent.components(separatedBy: "\n")
        return lines.prefix(maxCollapsedLines).joined(separator: "\n")
    }
}
