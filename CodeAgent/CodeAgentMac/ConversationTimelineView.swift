//
//  ConversationTimelineView.swift
//  CodeAgent
//
//  Created by xiaoyuan on 2026/6/24.
//

import SwiftUI

struct ConversationTimelineView: View {

    @Binding var selection: InspectorSelection?

    let events: [TimelineEvent] = [

        .init(
            type: .user,
            title: "User",
            detail: "帮我生成 AI 热点视频"
        ),

        .init(
            type: .thinking,
            title: "Thinking",
            detail: "正在分析热点..."
        ),

        .init(
            type: .tool,
            title: "search_news",
            detail: "搜索热点"
        ),

        .init(
            type: .todo,
            title: "Generate Script",
            detail: "Running"
        ),

        .init(
            type: .artifact,
            title: "script.md",
            detail: "生成完成"
        )
    ]

    var body: some View {

        ScrollView {

            LazyVStack(
                alignment: .leading,
                spacing: 16
            ) {

                ForEach(events) { event in

                    TimelineEventRow(
                        event: event
                    )
                    .onTapGesture {

                        switch event.type {

                        case .artifact:
                            selection = .file(event.title)

                        case .todo:
                            selection = .todo(event.title)

                        case .tool:
                            selection = .tool(event.title)

                        default:
                            break
                        }
                    }

                }

            }
            .padding()
        }
    }
}
