//
//  MessageBubble.swift
//  CodeAgentUI
//
//  User / Assistant message bubble. User = right-aligned accent, Assistant = left-aligned quaternary.
//  Shows streaming cursor when isStreaming == true.
//

import SwiftUI

struct MessageBubble: View {
    let text: String
    let role: MessageRole
    var isStreaming: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if role == .assistant {
                // Assistant avatar / indicator
                VStack {
                    Image(systemName: "brain.head.profile")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.top, 4)
            }

            if role == .user { Spacer() }

            Text(text + (isStreaming ? "|" : ""))
                .font(.body)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    if role == .user {
                        Color.accentColor
                    } else {
                        Color(nsColor: .quaternaryLabelColor)
                    }
                }
                .foregroundStyle(role == .user ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .textSelection(.enabled)

            if role == .assistant { Spacer() }

            if role == .user {
                VStack {
                    Image(systemName: "person.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 4)
    }
}

#Preview {
    VStack(spacing: 16) {
        MessageBubble(text: "Hello, how are you?", role: .user)
        MessageBubble(text: "I'm doing well, thanks for asking!", role: .assistant)
        MessageBubble(text: "I'm still writing", role: .assistant, isStreaming: true)
    }
    .padding()
}
