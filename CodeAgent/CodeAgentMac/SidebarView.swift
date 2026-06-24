//
//  SidebarView.swift
//  CodeAgent
//
//  Created by xiaoyuan on 2026/6/24.
//

import SwiftUI

struct SidebarView: View {

    let sessions = [
        "DreamAI",
        "AI Video",
        "MCP Debug",
        "iOS Agent"
    ]

    var body: some View {

        List {

            Section("Recent") {

                ForEach(sessions, id: \.self) { item in

                    Label(item, systemImage: "bubble.left")
                }
            }

        }
        .navigationTitle("CodeAgent")
    }
}
