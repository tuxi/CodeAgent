import Foundation
import Observation
/*
 │          用途          │                     推荐 URL                     │
 ├────────────────────────┼──────────────────────────────────────────────────┤
 │ App Store 隐私政策 URL │ https://dreamlog.com/privacy?standalone=1        │
 ├────────────────────────┼──────────────────────────────────────────────────┤
 │ App Store 用户协议 URL │ https://dreamlog.com/terms?standalone=1          │
 ├────────────────────────┼──────────────────────────────────────────────────┤
 │ 内容政策（合规公示）   │ https://dreamlog.com/content-policy?standalone=1 │
 ├────────────────────────┼──────────────────────────────────────────────────┤
 │ 英文版隐私政策         │ https://dreamlog.com/en/privacy?standalone=1     │
 ├────────────────────────┼──────────────────────────────────────────────────┤
 │ 英文版用户协议         │ https://dreamlog.com/en/terms?standalone=1       │
 └────────────────────────┴────────────────────────────────────────────
 */

public struct AgreementURLs {
    //  App Store 隐私政策 URL
    public static let privacy = URL(string: "https://dreamlog.com/privacy?standalone=1")!
    public static let terms = URL(string: "https://dreamlog.com/terms?standalone=1")!
    public static let content = URL(string: "https://dreamlog.com/content-policy?standalone=1")!
    public static let algorithmDisclosure = URL(string: "https://dreamlog.com/algorithm-disclosure?standalone=1")!
    public static let paid = URL(string: "https://dreamlog.com/pricing-terms?standalone=1")!
    public static let AIData = URL(string: "https://dreamlog.com/ai-data-processing?standalone=1")!
}

public enum AppEnvironment: String, CaseIterable, Codable, Sendable, Identifiable {
    case local
//    case dev
//    case staging
    case prod

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .local:
            return "Local"
//        case .dev:
//            return "Dev"
//        case .staging:
//            return "Staging"
        case .prod:
            return "Prod"
        }
    }
}

public struct AppEnvironmentConfig: Codable, Sendable, Equatable {
    public let environment: AppEnvironment
    public let apiBaseURL: URL
    public let wsURL: URL
    public let ossBucket: String
    public let isPlaceholder: Bool
    public let oneTapSecret: String?

    public init(
        environment: AppEnvironment,
        apiBaseURL: URL,
        wsURL: URL,
        ossBucket: String,
        isPlaceholder: Bool = false,
        oneTapSecret: String? = nil
    ) {
        self.environment = environment
        self.apiBaseURL = apiBaseURL
        self.wsURL = wsURL
        self.ossBucket = ossBucket
        self.isPlaceholder = isPlaceholder
        self.oneTapSecret = oneTapSecret
    }
}

public struct EnvironmentRegistry: Sendable {
    private let configs: [AppEnvironment: AppEnvironmentConfig]
    public let defaultEnvironment: AppEnvironment

    public init(
        configs: [AppEnvironment: AppEnvironmentConfig],
        defaultEnvironment: AppEnvironment = .prod
    ) {
        self.configs = configs
        self.defaultEnvironment = defaultEnvironment
    }

    public func config(for environment: AppEnvironment) -> AppEnvironmentConfig {
        if let config = configs[environment] {
            return config
        }
        return configs[defaultEnvironment] ?? Self.live.config(for: .prod)
    }

    public var allConfigs: [AppEnvironmentConfig] {
        AppEnvironment.allCases.map { config(for: $0) }
    }
}

public extension EnvironmentRegistry {
    static let live = EnvironmentRegistry(
        configs: [
            .local: AppEnvironmentConfig(
                environment: .local,
                apiBaseURL: URL(string: "http://192.168.1.4:12210/api/v1")!,
                wsURL: URL(string: "ws://192.168.1.4:12210/api/v1/ai/ws")!,
                ossBucket: "dreamlog",
                oneTapSecret: "qfEtjJdsdsDxZx4EzM4o4pmkt6j4eD/BBFtWZP/hFGHcDgaZK36EtlLXeyDPcGI2sS47viWjB87/KcTK0X0sri9AIDKFcQNZh8g1RzQM4eDesTHp5eVjBcfH7f5RRKJdPUaEwhK8Tmc27uBkEwEca+2PC9koWbksYqZoKMY0WMzE2VAUP+03MAWxdw43H7fNGq/UzVz/Kt35v2ZoMYlSvM7+vnzz002Nwlgw0EJSPEImaLsbsbIBqX+yz5e6Ceg5etyatJMt2g0="
            ),
//            .dev: AppEnvironmentConfig(
//                environment: .dev,
//                apiBaseURL: URL(string: "https://dev-api.dreamlog.com/api/v1")!,
//                wsURL: URL(string: "wss://dev-api.dreamlog.com/api/v1/ai/ws")!,
//                ossBucket: "dreamlog",
//                isPlaceholder: true
//            ),
//            .staging: AppEnvironmentConfig(
//                environment: .staging,
//                apiBaseURL: URL(string: "https://staging-api.dreamlog.com/api/v1")!,
//                wsURL: URL(string: "wss://staging-api.dreamlog.com/api/v1/ai/ws")!,
//                ossBucket: "dreamlog",
//                isPlaceholder: true
//            ),
            .prod: AppEnvironmentConfig(
                environment: .prod,
                apiBaseURL: URL(string: "https://api.dreamlog.com/api/v1")!,
                wsURL: URL(string: "wss://api.dreamlog.com/api/v1/ai/ws")!,
                ossBucket: "dreamlog",
                oneTapSecret: "qfEtjJdsdsDxZx4EzM4o4pmkt6j4eD/BBFtWZP/hFGHcDgaZK36EtlLXeyDPcGI2sS47viWjB87/KcTK0X0sri9AIDKFcQNZh8g1RzQM4eDesTHp5eVjBcfH7f5RRKJdPUaEwhK8Tmc27uBkEwEca+2PC9koWbksYqZoKMY0WMzE2VAUP+03MAWxdw43H7fNGq/UzVz/Kt35v2ZoMYlSvM7+vnzz002Nwlgw0EJSPEImaLsbsbIBqX+yz5e6Ceg5etyatJMt2g0="
            )
        ],
        defaultEnvironment: .prod
    )
}

@Observable
public final class EnvironmentManager: @unchecked Sendable {
    public private(set) var currentEnvironment: AppEnvironment

    private let registry: EnvironmentRegistry
    private let store: UserDefaults
    private let storeKey: String
    private let lock = NSLock()

    public init(
        registry: EnvironmentRegistry = .live,
        store: UserDefaults = .standard,
        storeKey: String = "com.objc.dreamlog.currentEnvironment"
    ) {
        self.registry = registry
        self.store = store
        self.storeKey = storeKey

        if let rawValue = store.string(forKey: storeKey),
           let environment = AppEnvironment(rawValue: rawValue) {
            self.currentEnvironment = environment
        } else {
            self.currentEnvironment = registry.defaultEnvironment
        }
    }

    public var currentEnvironmentSnapshot: AppEnvironment {
        lock.withLock { currentEnvironment }
    }

    public var currentConfig: AppEnvironmentConfig {
        registry.config(for: currentEnvironmentSnapshot)
    }

    public var availableConfigs: [AppEnvironmentConfig] {
        registry.allConfigs
    }

    public func saveCurrentEnvironment(_ environment: AppEnvironment) {
        lock.withLock {
            currentEnvironment = environment
            store.set(environment.rawValue, forKey: storeKey)
        }
    }

    public func config(for environment: AppEnvironment) -> AppEnvironmentConfig {
        registry.config(for: environment)
    }
}
