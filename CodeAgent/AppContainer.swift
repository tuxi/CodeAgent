//
//  AppContainer.swift
//  CodeAgent
//
//  Created by xiaoyuan on 2026/6/25.
//

import Foundation
import CodeAgentUI
import CoreKit

struct NetworkConfig: ApiConfiguration {
    var interceptor: RequestInterceptor?
    #if DEBUG
    var isDebugLogEnabled: Bool = true
    #else
    var isDebugLogEnabled: Bool = false
    #endif
    var baseURL: URL
    var commonHeaders: [String : String]
    var commonParameters: [String: Sendable] = [:]
    var timeout: TimeInterval = 50
    var decrypter: ApiDecrypter? = nil
}


@Observable
final class AppContainer {
    
    let wsClient: WebSocketClient
    
    init(wsClient: WebSocketClient) {
        self.wsClient = wsClient
    }
    
    func makeAgentClient() -> AgentClient {
        let mainConfig = NetworkConfig(
            interceptor: nil,
            baseURL: URL(string: "http://localhost:8787")!,
            commonHeaders: [:]
        )
        let apiProvider = ApiProvider(config: mainConfig)
        
        return DefaultAgentClient(provider: apiProvider, wsClient: wsClient)
    }
    
    func makeAgentDependencies() -> AgentDependencies {
        AgentDependencies(client: makeAgentClient())
    }
}
