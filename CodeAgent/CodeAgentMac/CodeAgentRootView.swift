//
//  CodeAgentRootView.swift
//  CodeAgent
//
//  Created by xiaoyuan on 2026/6/24.
//

#if os(macOS)

import SwiftUI

struct CodeAgentRootView: View {
    
    @State private var selection: InspectorSelection?
    
    var body: some View {
        NavigationSplitView {
            SidebarView()
        } content: {
            ConversationTimelineView(selection: $selection)
        } detail: {
            InspectorView(selection: selection)
        }
        .navigationSplitViewStyle(.balanced)
    }
}

#Preview {
    CodeAgentRootView()
}

#endif
