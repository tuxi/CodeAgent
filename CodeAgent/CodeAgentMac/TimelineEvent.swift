//
//  TimelineEvent.swift
//  CodeAgent
//
//  Created by xiaoyuan on 2026/6/24.
//

import Foundation

enum TimelineEventType {
    case user
    case assistant
    case thinking
    case tool
    case todo
    case artifact
}

struct TimelineEvent: Identifiable {

    let id = UUID()

    let type: TimelineEventType

    let title: String

    let detail: String
}
