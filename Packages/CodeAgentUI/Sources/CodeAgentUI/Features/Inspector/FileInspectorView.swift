//
//  FileInspectorView.swift
//  CodeAgent
//
//  Created by xiaoyuan on 2026/6/24.
//

import SwiftUI

struct FileInspectorView: View {

    let fileName: String

    var body: some View {

        VStack(alignment: .leading) {

            Text(fileName)
                .font(.title2)

            Divider()

            ScrollView {

                Text("""
# Script

这是生成的视频脚本内容...

第一段...

第二段...
""")
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )

            }

        }
        .padding()
    }
}
