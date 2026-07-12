//
//  LoginView.swift
//  FeatureAuth
//
//  Created by xiaoyuan on 2026/2/28.
//

import SwiftUI
import CoreKit
import DesignKit
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

// MARK: -  创意生成式 Logo (字符流生成动画)
struct BrandShufflingLogo: View {
    private let targetWords = ["DREAM", "LOG", "AI", "CORE", "IDEA", "MUSE"]
    @State private var currentChars: [String] = ["A", "I"]
    
    let timer = Timer.publish(every: 1.8, on: .main, in: .common).autoconnect()
    
    var body: some View {
        // 使用 HStack 容纳动态变化的字母
        HStack(spacing: 2) {
            ForEach(0..<currentChars.count, id: \.self) { index in
                Text(currentChars[index])
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .contentTransition(.interpolate) // 字母形变动画
            }
        }
        .padding(.horizontal, 20) // 左右留白，随字母增多自适应
        .frame(height: 54)        // 高度固定，保持视觉重心稳定
        .background(
            ZStack {
                // 动态背景：会自动跟随 HStack 的宽度
                Capsule(style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(hex: "FF6A3D"), Color(hex: "FF9F43")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                
                // 增加一层极细的内发光，增加高级感
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            }
        )
        // 关键：给整个组件加上 shadow 和动画
        .shadow(color: Color(hex: "FF6A3D").opacity(0.35), radius: 15, x: 0, y: 8)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentChars)
        .onReceive(timer) { _ in
            let nextWord = targetWords.randomElement() ?? "AI"
            morphTo(nextWord)
        }
        .onAppear { morphTo("DREAM") }
    }
    
    private func morphTo(_ word: String) {
        let chars = word.map { String($0) }
        // 这里的动画会同时作用于字母切换和背景宽度的变化
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            currentChars = chars
        }
    }
}
public struct AuthView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var viewModel: AuthViewModel
    @State private var isAgreementAccepted = true
    @State private var agreementURL: URL?
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case phone
        case captcha
    }
    
    public init(viewModel: AuthViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                backgroundView
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // 1. 品牌区层级弱化：作为顶部的轻量化标志
                        topBrandSection
                            .padding(.top, 60)
                            .padding(.bottom, 32)
                        
                        // 2. 核心卡片
                        loginCard
                        
                        // 3. 底部协议
                        agreementRow
                            .padding(.top, 24)
                            .padding(.horizontal, 10)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: contentMaxWidth)
                }
                .scrollDismissesKeyboard(.immediately)
                
                dismissButton
            }
            .onChange(of: viewModel.phoneNumber) { _, _ in
                viewModel.sanitizePhoneNumberInput()
            }
            .onChange(of: viewModel.captcha) { _, _ in
                viewModel.sanitizeCaptchaInput()
            }
            .onAppear {
                Task {
                    await viewModel.checkOneTapAvailability()
                }
            }
            .sheet(item: $agreementURL) { url in
                NavigationStack {
                    BrowserView(url: url)
                }
            }
        }
        .environment(\.openURL, OpenURLAction { url in
            agreementURL = url
            return .handled
        })
    }
}

private extension AuthView {
    var contentMaxWidth: CGFloat {
#if os(macOS)
        520
#else
            .infinity
#endif
    }
    
    var backgroundView: some View {
        ZStack {
            Color.systemBackground.ignoresSafeArea()
            Group {
                Circle()
                    .fill(Color(hex: "1E88FF", alpha: 0.06))
                    .frame(width: 450)
                    .blur(radius: 80)
                    .offset(x: 180, y: -280)
                
                Circle()
                    .fill(Color(hex: "FF7A59", alpha: 0.06))
                    .frame(width: 400)
                    .blur(radius: 70)
                    .offset(x: -180, y: -120)
            }
        }
    }
    
    
    var topBrandSection: some View {
        VStack(spacing: 16) {
            BrandShufflingLogo()
            
            VStack(spacing: 4) {
                Text("DreamAI")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .tracking(1.5)
                //                Text("用 AI 捕捉每一个创意瞬间")
                Text("让创意在字符间跃动")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
    }
    
    var loginCard: some View {
        VStack(alignment: .leading, spacing: 28) {
            // 标题层级优化：这里是唯一的视觉重心
            VStack(alignment: .leading, spacing: 8) {
                Text("欢迎回来")
                    .font(.system(size: 28, weight: .bold))
                if !viewModel.useOneTapLogin {
                    // 将 lastLoginHint 转化为这种形式，更像引导语
                    Text(lastLoginHint)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                errorBanner(message: errorMessage)
            }
            
            if viewModel.useOneTapLogin {
                oneTapLoginSection
            } else {
                smsLoginFields
            }
            
#if canImport(AuthenticationServices)
            appleLoginSection
#endif
        }
        .padding(30)
        .background(
            ZStack {
                // 浅色模式下提高不透明度，并加入微弱的灰色调，深色模式保持通透
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(colorScheme == .dark ? Color.black.opacity(0.4) : Color.white.opacity(0.95))
                
                Rectangle()
                    .fill(.ultraThinMaterial)
            }
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(
                            colorScheme == .dark
                            ? LinearGradient(colors: [.white.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [.white, .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.5
                        )
                )
        )
        // 浅色模式增加投影对比度，解决重叠感
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 30, x: 0, y: 15)
    }
    
    
    // 自定义精致输入框
    func modernInputField<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 10))
                Text(title.uppercased()).font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.secondary.opacity(0.7))
            .padding(.leading, 4)
            
            content()
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                )
        }
    }
#if canImport(AuthenticationServices)
    // MARK: - 3. Apple 登录适配优化
    var appleLoginSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Rectangle().fill(Color.secondary.opacity(0.1)).frame(height: 1)
                Text("快速登录").font(.system(size: 12)).foregroundColor(.secondary.opacity(0.4))
                Rectangle().fill(Color.secondary.opacity(0.1)).frame(height: 1)
            }
            
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in handleAppleLogin(result) }
            // 确保 style 直接响应 colorScheme 环境
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
#endif
    
    var smsLoginFields: some View {
        VStack(spacing: 20) {
            phoneField
            codeField
            loginSubmitButton
        }
    }
    
    var oneTapLoginSection: some View {
        VStack(spacing: 20) {
            //            HStack(spacing: 4) {
            //                Image(systemName: "iphone.gen1")
            //                    .font(.system(size: 13))
            //                Text("本机号码")
            //                    .font(.system(size: 13, weight: .medium))
            //            }
            //            .foregroundColor(.secondary)
            //            .padding(.vertical, 24)
            //            .frame(maxWidth: .infinity)
            
            Button(action: { Task { await viewModel.performOneTapLogin(colorScheme: colorScheme) } }) {
                Text("本机号码一键登录")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color(hex: "FF6A3D"), Color(hex: "FF9F43")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isOneTapLogging)
            
            Button("其他手机号登录") {
                viewModel.showSmsLogin = true
            }
            .font(.system(size: 14))
            .foregroundColor(.secondary)
        }
    }
    
    var loginSubmitButton: some View {
        Button(action: loginWithPhoneCode) {
            HStack(spacing: 6) {
                if viewModel.isLogging {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                Text(viewModel.isLogging ? "登录中" : "立即登录")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(viewModel.canSubmitPhoneLogin ? Color(hex: "1E88FF") : Color.secondary.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canSubmitPhoneLogin)
    }
    
    var phoneField: some View {
        inputBlock(title: "手机号") {
            HStack(spacing: 12) {
                Text("+86")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Divider()
                    .frame(height: 20)
                
                TextField("请输入手机号", text: $viewModel.phoneNumber)
                    .font(.system(size: 18, weight: .medium))
#if os(iOS)
                    .keyboardType(.numberPad)
                    .textContentType(.telephoneNumber)
#endif
                    .focused($focusedField, equals: .phone)
            }
        }
    }
    
    var codeField: some View {
        inputBlock(title: "验证码") {
            HStack(spacing: 12) {
                TextField("请输入验证码", text: $viewModel.captcha)
                    .font(.system(size: 18, weight: .medium))
#if os(iOS)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
#endif
                    .focused($focusedField, equals: .captcha)
                
                Button(action: sendPhoneCode) {
                    Text(viewModel.isCountingDown ? "\(viewModel.timerCount)s" : (viewModel.isSendingCode ? "发送中" : "获取验证码"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(viewModel.canSendCode ? .white : .secondary)
                        .frame(minWidth: 92)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(viewModel.canSendCode ? Color(hex: "1E88FF") : Color.controlBackground)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canSendCode || viewModel.isCountingDown)
            }
        }
    }
    
    func inputBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            content()
                .padding(.horizontal, 14)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.controlBackground)
                )
        }
    }
    
    func dividerTitle(_ text: String) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.secondary.opacity(0.16))
                .frame(height: 1)
            
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Rectangle()
                .fill(Color.secondary.opacity(0.16))
                .frame(height: 1)
        }
    }
    
    func errorBanner(message: String) -> some View {
        Text(message)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(Color(hex: "E0563A"))
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "E0563A").opacity(0.1))
            .cornerRadius(10)
    }
    
    
    // MARK: - Helper Views & Logic
    var agreementRow: some View {
        // firstTextBaseline: non-text views (Button/Image) center on the first text baseline,
        // so the checkbox is visually centered with the first line even when text wraps.
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Toggle("", isOn: $isAgreementAccepted)
                .toggleStyle(CheckmarkToggleStyle())
            Text(agreementAttributedText)
                .font(.system(size: 12))
                .lineSpacing(2)
            Spacer()
        }
    }
    
    var agreementAttributedText: AttributedString {
        let linkColor = Color(hex: "FF7A45")
        let textColor = Color.secondary.opacity(0.8)
        
        var base = AttributedString("登录即表示你已阅读并同意")
        base.foregroundColor = textColor
        
        var terms = AttributedString("《用户协议》")
        terms.foregroundColor = linkColor
        terms.link = AgreementURLs.terms
        
        var connector = AttributedString("与")
        connector.foregroundColor = textColor
        
        var privacy = AttributedString("《隐私政策》")
        privacy.foregroundColor = linkColor
        privacy.link = AgreementURLs.privacy
        
        return base + terms + connector + privacy
    }
    
    var dismissButton: some View {
        Button(action: {
            viewModel.manager.showLoginSheet = false }
        ) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.secondary)
                .padding(10)
                .background(Circle().fill(.ultraThinMaterial))
        }
        .padding(20)
    }
    
    var lastLoginHint: String {
        switch viewModel.selectedLoginMethod {
        case .phoneCode:
            return viewModel.phoneNumber.isEmpty ? "输入手机号以开启灵感" : "已自动填充上次使用的号码"
        case .phoneOneTap: return "本机号码一键登录"
        case .apple: return "建议使用 Apple 快速登录"
        }
    }
    
    func sendPhoneCode() {
        guard viewModel.requireAgreement(accepted: isAgreementAccepted) else { return }
        viewModel.sendPhoneCode()
        if viewModel.validatePhoneForFocusAdvance {
            focusedField = .captcha
        }
    }
    
    func loginWithPhoneCode() {
        guard viewModel.requireAgreement(accepted: isAgreementAccepted) else { return }
        Task {
            await viewModel.login()
        }
    }
    
#if canImport(AuthenticationServices)
    func handleAppleLogin(_ result: Result<ASAuthorization, any Error>) {
        guard viewModel.requireAgreement(accepted: isAgreementAccepted) else { return }
        
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = credential.identityToken,
                  let authorizationCodeData = credential.authorizationCode,
                  let identityToken = String(data: identityTokenData, encoding: .utf8),
                  let authorizationCode = String(data: authorizationCodeData, encoding: .utf8) else {
                viewModel.errorMessage = "Apple 登录凭证解析失败"
                return
            }
            
            Task {
                await viewModel.loginByApple(
                    identityToken: identityToken,
                    authorizationCode: authorizationCode,
                    email: credential.email,
                    givenName: credential.fullName?.givenName,
                    familyName: credential.fullName?.familyName
                )
            }
        case .failure(let error):
            viewModel.errorMessage = error.localizedDescription
        }
    }
#endif
}

private extension AuthViewModel {
    var validatePhoneForFocusAdvance: Bool {
        phoneNumber.count == 11
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// 自定义 Checkmark 样式
struct CheckmarkToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                .foregroundColor(configuration.isOn ? Color(hex: "FF7A45") : .secondary.opacity(0.3))
                .font(.system(size: 18))
        }
    }
}
