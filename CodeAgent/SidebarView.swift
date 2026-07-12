//
//  SidebarView.swift
//  AgentKit
//
//  Created by xiaoyuan on 2026/6/24.
//

import SwiftUI
import AgentKit
import CoreKit

/// 最左侧栏：顶部一级 Tab 切换分区，下方为当前分区的会话列表。
/// 列表点选通过 `store.selectedConversation` 驱动中间对话详情。
///
/// - macOS：标准侧栏布局，列表支持 selection 绑定。
/// - iOS：支持搜索过滤、滑动删除，列表点选后自动 push 到详情。
public struct SidebarView: View {

    @Environment(WorkspaceStore.self) private var store
    @Environment(AuthManager.self) private var authManager
    @Environment(AgentManager.self) private var agentManager
    @Environment(UserManager.self) private var userManager
    @State private var searchText = ""
    @State private var isAccountMenuPresented = false
    @Binding var showSettings: Bool

    public var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            newTaskButton
                .simultaneousGesture(TapGesture().onEnded { dismissAccountMenu() }, including: .subviews)

            ConversationListView(
                viewModel: store.listViewModel,
                selected: $store.selectedConversation,
                searchText: searchText
            )
            .simultaneousGesture(TapGesture().onEnded { dismissAccountMenu() }, including: .subviews)
            #if os(macOS)
            Divider()
            footer
            #endif
        }
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottomLeading) {
            if isAccountMenuPresented {
                accountMenu
                    .padding(.leading, 10)
                    .padding(.bottom, 62)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .zIndex(1)
            }
        }
        .navigationTitle(store.selectedTab.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("设置")
            }
        }
        #if os(iOS)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer,
            prompt: "搜索会话…"
        )
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    private var footer: some View {
        Button {
            withAnimation(.easeOut(duration: 0.16)) {
                isAccountMenuPresented.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Text(accountInitial)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.accentColor, in: Circle())

                Text(accountName)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

//                Image(systemName: "chevron.up")
//                    .font(.system(size: 10, weight: .bold))
//                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .accessibilityLabel("账户：\(accountName)")
        .task {
            guard authManager.isLoggedIn, authManager.isRegistered else { return }
            await userManager.refreshProfileIfNeeded()
        }
    }

    private func dismissAccountMenu() {
        guard isAccountMenuPresented else { return }
        withAnimation(.easeOut(duration: 0.16)) {
            isAccountMenuPresented = false
        }
    }

    private var accountMenu: some View {
        VStack(spacing: 3) {
            HStack(spacing: 10) {
                Text(accountInitial)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor, in: Circle())
                Text(accountName)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            Divider().padding(.horizontal, 8)

            accountMenuRow(title: usageTitle, systemImage: "gauge.with.dots.needle.50percent") {
                Task { try? await agentManager.fetchUsage() }
            }
            accountMenuRow(title: "设置", systemImage: "gearshape") {
                isAccountMenuPresented = false
                showSettings = true
            }
            accountMenuRow(
                title: "退出登录",
                systemImage: "rectangle.portrait.and.arrow.right",
                isDestructive: true
            ) {
                isAccountMenuPresented = false
                authManager.logout()
            }
        }
        .padding(6)
        .frame(width: 238)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 7)
    }

    private func accountMenuRow(
        title: String,
        systemImage: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 9)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isDestructive ? Color.red : Color.primary)
    }

    private var newTaskButton: some View {
        Button {
            // 仅建立本地草稿；首条消息发送时才会创建真正的会话。
            store.beginDraft()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 13, weight: .medium))
                Text("新建任务")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 15)
        .padding(.bottom, 10)
        .accessibilityHint("创建一个新的对话草稿")
    }

    private var accountName: String {
        guard authManager.isLoggedIn else { return "未登录" }

        let candidates = [
            userManager.profile?.nickname,
            authManager.displayNickname
        ]
        if let name = candidates.lazy.compactMap({ value -> String? in
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }).first {
            return name
        }

        if let username = userManager.profile?.username.trimmingCharacters(in: .whitespacesAndNewlines),
           !username.isEmpty,
           !username.allSatisfy(\.isNumber) {
            return username
        }
        if let userID = authManager.token?.userId {
            return "用户 \(userID)"
        }
        return "账户"
    }

    private var accountInitial: String {
        String(accountName.prefix(1)).uppercased()
    }

    private var usageTitle: String {
        guard let usage = agentManager.usage else { return "剩余用量" }
        guard let limit = usage.monthlyLimit else { return "剩余用量：不限额" }
        return "剩余用量：\(max(limit - usage.monthlyUnits, 0)) / \(limit)"
    }
}
