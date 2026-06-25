//
//  FileArtifactView.swift
//  CodeAgentUI
//
//  File artifact 渲染 — 代码查看器风格（等宽、深色背景、行号）。
//

import SwiftUI

/// 文件内容 artifact 的纯渲染视图。
struct FileArtifactView: View {
    let filePath: String
    let content: String
    let language: String?

    @State private var isExpanded = false

    private let maxCollapsedLines = 50

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 标题栏
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.caption)
                    Text("📄 \(shortFileName)")
                        .font(.caption.monospaced().weight(.medium))
                        .lineLimit(1)
                    if let lang = language {
                        Text(lang)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .background(.quaternary)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Text("\(lineCount) lines")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(numberedLines.enumerated()), id: \.offset) { index, line in
                            HStack(spacing: 8) {
                                // 行号
                                Text("\(index + 1)")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 32, alignment: .trailing)
                                // 内容
                                Text(line)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.primary)
                                    .textSelection(.enabled)
                                Spacer()
                            }
                        }
                    }
                    .padding(8)
                }
                .background(.black.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(maxHeight: 400)
            } else {
                // 折叠态：预览前 N 行
                let preview = previewLines
                if !preview.isEmpty {
                    Text(preview)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(10)
                }
            }
        }
        .padding(8)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Helpers

    private var shortFileName: String {
        (filePath as NSString).lastPathComponent
    }

    private var lineCount: Int {
        content.components(separatedBy: "\n").count
    }

    private var numberedLines: [String] {
        content.components(separatedBy: "\n")
    }

    private var previewLines: String {
        let lines = content.components(separatedBy: "\n")
        return lines.prefix(maxCollapsedLines).joined(separator: "\n")
    }
}
