//
//  AgentNavigationDestination.swift
//  CodeAgentUI
//
//  Created by xiaoyuan on 2026/6/25.
//

import Foundation
import CoreKit

public enum AgentNavigationDestination: Hashable {
    case conversationDetail(conversation: ConversationRef)
    
    public var id: String {
        switch self {
        case .conversationDetail(let conversation):
            return "conversationDetail\(conversation)"
        }
    }
}
