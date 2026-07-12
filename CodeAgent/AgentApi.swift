//
//  AgentApi.swift
//  CodeAgent
//
//  Created by xiaoyuan on 2026/7/12.
//

import Foundation
import CoreKit
import Alamofire

enum AgentApi {
    case usage
    case models
}

extension AgentApi: ApiEndpoint {
    var path: String {
        switch self {
        case .usage:
            return "agent/usage"
        case .models:
            return "agent/models"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .usage, .models:
            return .get
        }
    }
    
    var parameters: [String : any Sendable] {
        [:]
    }
    
    var encoding: ApiParameterEncoding {
        .url
    }
    
}
