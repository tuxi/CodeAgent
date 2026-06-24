//
//  InspectorView.swift
//  CodeAgent
//
//  Created by xiaoyuan on 2026/6/24.
//

import SwiftUI

struct InspectorView: View {

    let selection: InspectorSelection?

    var body: some View {

        Group {

            switch selection {

            case .file(let file):

                FileInspectorView(
                    fileName: file
                )

            case .todo(let todo):

                TodoInspectorView(
                    todoName: todo
                )

            case .tool(let tool):

                ToolInspectorView(
                    toolName: tool
                )

            default:

                ContentUnavailableView(
                    "Nothing Selected",
                    systemImage: "sidebar.right"
                )
            }

        }
    }
}
