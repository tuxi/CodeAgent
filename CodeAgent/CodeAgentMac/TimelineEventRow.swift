//
//  TimelineEventRow.swift
//  CodeAgent
//
//  Created by xiaoyuan on 2026/6/24.
//

import SwiftUI

struct TimelineEventRow: View {

    let event: TimelineEvent

    var body: some View {

        VStack(alignment: .leading, spacing: 8) {

            Text(event.title)
                .font(.headline)

            Text(event.detail)
                .foregroundStyle(.secondary)

        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background)
        .clipShape(
            RoundedRectangle(cornerRadius: 12)
        )
    }
}
