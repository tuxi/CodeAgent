//
//  TimelineEvent.swift
//  CodeAgent
//
//  Created by xiaoyuan on 2026/6/24.
//

import Foundation

public enum TimelineEventType {
    case user
    case assistant
    case thinking
    case tool
    case todo
    case artifact
}

public struct TimelineEvent: Identifiable {

    public let id: String
    public let type: TimelineEventType
    public let title: String
    public let detail: String

    public init(id: String = UUID().uuidString, type: TimelineEventType, title: String, detail: String) {
        self.id = id
        self.type = type
        self.title = title
        self.detail = detail
    }
}
