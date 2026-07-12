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
        else {
            return nil
        }
        return Credential(
            kind: .bearer,
            secret: token.accessToken,
            expiresAt: token.accessExpireDate,
            metadata: ["refresh_token": token.refreshToken]
        )
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
    
    func clear() async throws {
        
    }
    
}
