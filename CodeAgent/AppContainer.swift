//
//  AppContainer.swift
//  CodeAgent
//
//  Example app dependency container.
//  Demonstrates:
//    - AgentKit integration (AccountManager, ModelSettingsStore, ToolRegistry)
//    - Dreamlog business logic (UserManager, BillingManager via ApiProvider)
//    - Client tool registration for P1 client tool execution.
//

import Foundation
import AgentKit
import CoreKit
import FeatureAuth

struct BaseHeader: Encodable, Sendable {
    let deviceId: String
    let deviceType: String
    let deviceName: String
    let os: String
    let appVersion: String
    
    enum CodingKeys: String, CodingKey {
        case deviceId = "X-Device-ID"
        case deviceType = "X-Device-Type"
        case deviceName = "X-Device-Name"
        case os = "X-OS-Version"
        case appVersion = "X-App-Version"
    }
    
    /// 从DeviceInfo初始化BaseHeader
    init(deviceInfo: DeviceInfo) {
        self.deviceId = deviceInfo.deviceId
        self.deviceType = deviceInfo.deviceType
        self.deviceName = deviceInfo.deviceName
        self.os = deviceInfo.osVersion
        self.appVersion = deviceInfo.appVersion
    }
    
    /// 转换为字典格式（用于设置header）
    func toDictionary() -> [String: String]? {
        do {
            let data = try JSONEncoder().encode(self)
            guard let dict = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? [String: String] else {
                return nil
            }
            return dict
        } catch {
            DLLog("BaseHeader编码失败: \(error)")
            return nil
        }
    }
}

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

@MainActor
@Observable
final class AppContainer {
    
    let authManager: AuthManager
    let userManager: UserManager
    let deviceManager: DeviceManager
    
    private let baseHeaders: [String: String]
    private(set) var apiProvider: ApiProvider?
    
    let environmentManager: EnvironmentManager
    
    /// AgentKit 用户身份管理 —— 登录 / Token 刷新 / 登出。
    let agentManager: AgentManager

    /// AgentKit 模型管理 —— 模型列表 + 本地偏好。
    let modelSettings: ModelSettingsStore

    /// 客户端工具注册表 — 注册本地可执行工具。
    let toolRegistry: ToolRegistry

    /// Product-specific additions to AgentKit's otherwise generic Timeline.
    let timelineExtensions: [any TimelineExtension]

    // MARK: - Dreamlog 业务层（示例：如何在真实 App 中集成）

    /// Dreamlog 网络层 —— 基于 Alamofire 的 API 请求。
    /// 需要 Alamofire 依赖（通过 SPM 或 Xcode 添加）。
    /// let apiProvider: ApiProvider

    /// 用户资料管理 —— 从后端获取/更新用户信息。
    /// let userManager: UserManager

    /// 计费/订阅管理 —— 钱包、权益、订阅中心。
    /// let billingManager: BillingManager

    init(authManager: AuthManager,
         environmentManager: EnvironmentManager,
         deviceManager: DeviceManager
    ) {

        self.authManager = authManager
        self.environmentManager = environmentManager
        self.deviceManager = deviceManager
        
        // 缓存基础头（仅创建一次，提升性能）
        do {
            let deviceInfo = try deviceManager.getDeviceInfo()
            self.baseHeaders = BaseHeader(deviceInfo: deviceInfo).toDictionary() ?? [:]
        } catch {
            self.baseHeaders = ["Content-Type": "application/json"]
            DLLog("⚠️ 设备信息获取失败：\(error)")
        }
        
        let apiProvider = Self.makeAuthorizedApiProvider(
            authManager: authManager,
            environmentConfig: environmentManager.currentConfig,
            commonHeaders: baseHeaders
        )
        self.apiProvider = apiProvider
        self.userManager = UserManager(
            service: UserService(apiProvider: apiProvider),
            environment: environmentManager.currentEnvironmentSnapshot
        )
//        self.billingManager = BillingManager(service: BillingService(apiProvider: apiProvider))
//        self.conversationWSClient = ConversationWSClient(wsClient: wsClient)
//        self.conversationStore.configure(
//            service: ConversationService(apiProvider: apiProvider)
//        )

//        if let secret = environmentManager.currentConfig.oneTapSecret {
//            OneTapLoginService.shared.configure(secret: secret)
//        }
        
//        CloudAssetStore.initialize(assetService: makeAssetService())
        
        // 创建 AgentKit AccountManager（默认指向本地 Gateway）
        self.agentManager = AgentManager(apiProvider: apiProvider)

        // ModelSettingsStore 管理本地模型偏好。
        // 模型列表由宿主 App 在启动时通过 setAvailableModels() 注入。
        self.modelSettings = ModelSettingsStore()

        self.toolRegistry = ToolRegistry()

        #if os(macOS)
        self.timelineExtensions = [DesktopControlEvidenceTimeline()]
        #else
        self.timelineExtensions = []
        #endif

        // 从旧 AgentSettings 迁移到新 CredentialStore（仅一次）
        CredentialSettings.migrateFromLegacyIfNeeded()

        // P1: 注册客户端工具（Go 服务端无法执行的本地工具）
        registerClientTools()

        // 从 Gateway 获取模型列表 → 注入 ModelSettingsStore。
        // 注意：fetchFromGateway() 已从 ModelSettingsStore 移除，
        // 改为由宿主 App 主动获取并调用 setAvailableModels()。
        Task {
            await refreshModelList()
        }

        // Dreamlog 业务层集成示例（需要 Alamofire 等依赖时取消注释）：
        // setupDreamlogServices()
    }

    /// 从 Gateway 获取模型列表并注入 ModelSettingsStore。
    private func refreshModelList() async {
        // 使用 authClient 直接获取模型列表
        guard let token = try? await KeychainCredentialStore().resolve(.gateway)?.secret else { return }
        do {
            let response = try await URLSessionAuthClient().getModels(accessToken: token)
            modelSettings.setAvailableModels(response.models, defaultModel: response.defaultModel)
        } catch {
            print("Failed to fetch models from Gateway: \(error)")
        }
    }

    /// Dreamlog 业务服务初始化（需要 Alamofire + OSS 等依赖）。
    /// 取消注释以下代码即可启用完整的用户/订阅功能。
    /*
    private func setupDreamlogServices() {
        // 1. 创建 ApiProvider（指向 Dreamlog API）
        let environment = AppEnvironment.prod
        let config = EnvironmentRegistry.live.config(for: environment)
        // let authInterceptor = DreamlogAuthInterceptor(authManager: dreamlogAuthManager)
        // self.apiProvider = ApiProvider(
        //     baseURL: config.apiBaseURL,
        //     interceptor: authInterceptor
        // )

        // 2. 创建 UserManager
        // let userService = UserService(apiProvider: apiProvider)
        // self.userManager = UserManager(service: userService, environment: environment)

        // 3. 创建 BillingManager
        // let billingService = BillingService(apiProvider: apiProvider)
        // self.billingManager = BillingManager(service: billingService)
    }
    */

    private func registerClientTools() {
        Task {
            await toolRegistry.register(DeviceInfoTool())
            await toolRegistry.register(CameraCaptureTool())
            await toolRegistry.register(DownloadFileTool())
#if os(macOS)
            await toolRegistry.register(ScreenshotTool())
#endif
        }
    }

    func makeAgentClient() -> RuntimeClient {
        #if os(iOS)
        // iOS: 内嵌 CodeAgent Runtime。
        injectCredentialsIntoRuntime()
        return DefaultAgentClient.fromRuntime()
        #else
        // macOS: 连接独立运行的 CodeAgent server（127.0.0.1:8797）。
        let env = RuntimeEnvironment(host: "127.0.0.1", port: 8797)
        let credentialStore = KeychainCredentialStore()
        return DefaultAgentClient(environment: env, credentialStore: credentialStore)
        #endif
    }

    func makeAgentDependencies() -> AgentDependencies {
        AgentDependencies(
            client: makeAgentClient(),
            toolRegistry: toolRegistry,
            timelineExtensions: timelineExtensions,
            onAuthExpired: { [agentManager] in
//                guard (try? await agentManager.refreshGatewayToken()) != nil else { return }
                #if os(iOS)
                try? await AgentRuntime.shared.reconfigure(with: KeychainCredentialStore())
                #endif
            }
        )
    }

    // MARK: - Credential Injection (iOS)

    private func injectCredentialsIntoRuntime() {
        #if os(iOS)
        Task {
            if case .anonymous = accountManager.state {
                await accountManager.restore()
            }
            if let _ = try? await accountManager.gatewayCredential() {
                try? await AgentRuntime.shared.launch(with: KeychainCredentialStore())
            } else {
                try? AgentRuntime.shared.ensureStarted()
            }
        }
        #endif
    }
    
    private static func makeAuthorizedApiProvider(
        authManager: AuthManager,
        environmentConfig: AppEnvironmentConfig,
        commonHeaders: [String: String]
    ) -> ApiProvider {
        let authInterceptor = AuthInterceptor(authManager: authManager)
        let mainConfig = NetworkConfig(
            interceptor: authInterceptor,
            baseURL: environmentConfig.apiBaseURL,
            commonHeaders: commonHeaders
        )
        return ApiProvider(config: mainConfig)
    }
    
    func makeAuthViewModel() -> AuthViewModel {
        AuthViewModel(
            service: makeAuthService(),
            manager: authManager,
            userManager: userManager,
            environment: environmentManager.currentEnvironmentSnapshot
        )
    }
    
    
    func makeAuthService() -> AuthService {
        AuthService(api: makeApiProvider())
    }
    
    // MARK: - ApiProvider 工厂方法（按需创建）
    func makeApiProvider() -> ApiProvider {
        if let apiProvider {
            return apiProvider
        }
        let apiProvider = Self.makeAuthorizedApiProvider(
            authManager: authManager,
            environmentConfig: environmentManager.currentConfig,
            commonHeaders: baseHeaders
        )
        self.apiProvider = apiProvider
        return apiProvider
    }
}
