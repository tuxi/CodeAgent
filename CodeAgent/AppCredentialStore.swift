//
//  AppCredentialStore.swift
//  CodeAgent
//
//  Created by xiaoyuan on 2026/7/12.
//

import Foundation
import AgentKit
import CoreKit

final class AppCredentialStore: CredentialStore, Sendable {
   
    private let authManager: AuthManager
    
    init(authManager: AuthManager) {
        self.authManager = authManager
    }
    
    func resolve(_ target: AgentKit.CredentialTarget) async throws -> AgentKit.Credential? {
        guard target == .gateway,
              let token = await authManager.token
        else { return nil }
        return makeCredential(accessToken: token.accessToken,
                              refreshToken: token.refreshToken,
                              expiresAt: token.accessExpireDate)
    }

    // WebSocket 连接时需要同步获取 Token，走 nonisolated accessor
    func resolveSync(_ target: CredentialTarget) -> Credential? {
        guard target == .gateway,
              let accessToken = authManager.accessToken
        else { return nil }
        return makeCredential(accessToken: accessToken,
                              refreshToken: authManager.refreshToken,
                              expiresAt: nil)
    }

    func all() async throws -> AgentKit.CredentialMap {
        var map = CredentialMap()
        if let cred = try await resolve(.gateway) {
            map[.gateway] = cred
        }
        return map
    }
    
    func set(_ credential: AgentKit.Credential, for target: AgentKit.CredentialTarget) async throws {
        
    }
    
    func remove(_ target: AgentKit.CredentialTarget) async throws {
        
    }
    
    func clear() async throws {}

    // MARK: - Private

    private func makeCredential(accessToken: String,
                                refreshToken: String?,
                                expiresAt: Date?) -> Credential {
        Credential(
            kind: .bearer,
            secret: accessToken,
            expiresAt: expiresAt,
            metadata: refreshToken.map { ["refresh_token": $0] } ?? [:]
        )
    }

}
