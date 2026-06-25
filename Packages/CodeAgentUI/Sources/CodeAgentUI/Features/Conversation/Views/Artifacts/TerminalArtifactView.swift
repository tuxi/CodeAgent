//
//  TerminalArtifactView.swift
//  CodeAgentUI
//
//  Terminal artifact 渲染 — 终端风格（深色背景、等宽字体、exit code）。
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

/// 终端输出 artifact 的纯渲染视图。
struct TerminalArtifactView: View {
    let command: String
    let output: String
    let exitCode: Int?

    @State private var isExpanded = false
    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 标题栏
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "terminal")
                        .font(.caption)
                    Text("$ \(command)")
                        .font(.caption.monospaced().weight(.medium))
                        .lineLimit(1)
                    if let code = exitCode {
                        Text(code == 0 ? "✓ 0" : "✗ \(code)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(code == 0 ? .green : .red)
                            .padding(.horizontal, 4)
                            .background(code == 0 ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ScrollView([.horizontal, .vertical]) {
                        Text(output)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.green)
                            .textSelection(.enabled)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(.black.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .frame(maxHeight: 300)

                    // 复制按钮
                    HStack {
                        Spacer()
                        Button {
                            copyToClipboard(output)
                            showCopied = true
                            Task {
                                try? await Task.sleep(nanoseconds: 1_500_000_000)
                                showCopied = false
                            }
                        } label: {
                            Label(
                                showCopied ? "Copied!" : "Copy",
                                systemImage: showCopied ? "checkmark" : "doc.on.doc"
                            )
                            .font(.caption2)
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(showCopied ? .green : .secondary)
                    }
                }
            } else {
                // 折叠态：预览输出前几行
                let preview = previewLines
                if !preview.isEmpty {
                    Text(preview)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(5)
                }
            }
        }
        .padding(8)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Helpers

    private var previewLines: String {
        let lines = output.components(separatedBy: "\n")
        return lines.prefix(8).joined(separator: "\n")
    }

    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}
