import SwiftUI

struct SettingsView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var apiKeyInput: String = ""
    
    var body: some View {
        ZStack {
            AppTheme.bgBase.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("设置")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 账号信息卡片
                        HStack(spacing: 16) {
                            Circle()
                                .fill(AppTheme.surface2)
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Text(String(authManager.username?.prefix(1) ?? "胖"))
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(AppTheme.textSecondary)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(authManager.username ?? "小胖")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(AppTheme.textPrimary)
                                Text("相伴 128 天")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                            
                            Spacer()
                        }
                        .padding(20)
                        .softCard()
                        
                        // 大模型设置
                        VStack(alignment: .leading, spacing: 16) {
                            Text("模型设置")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)
                                .padding(.leading, 4)
                            
                            VStack(spacing: 0) {
                                Menu {
                                    Button("MiniMax-M2.7") { authManager.updateConfig(apiKey: nil, modelName: "MiniMax-M2.7") }
                                    Button("Claude 3 Haiku") { authManager.updateConfig(apiKey: nil, modelName: "Claude 3 Haiku") }
                                    Button("GPT-4o") { authManager.updateConfig(apiKey: nil, modelName: "GPT-4o") }
                                    Button("DeepSeek-R1") { authManager.updateConfig(apiKey: nil, modelName: "DeepSeek-R1") }
                                } label: {
                                    HStack(spacing: 16) {
                                        Image(systemName: "cpu")
                                            .font(.system(size: 20))
                                            .foregroundColor(AppTheme.textTertiary)
                                            .frame(width: 24)
                                        Text("默认推理模型")
                                            .font(.system(size: 16, weight: .regular))
                                            .foregroundColor(AppTheme.textPrimary)
                                        Spacer()
                                        HStack(spacing: 4) {
                                            Text(authManager.modelName)
                                                .font(.system(size: 14))
                                            Image(systemName: "chevron.up.chevron.down")
                                                .font(.system(size: 12))
                                        }
                                        .foregroundColor(AppTheme.textSecondary)
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Divider().background(AppTheme.strokeLighter).padding(.leading, 44)
                                
                                Menu {
                                    Button("Claude 3 Haiku") { authManager.updateConfig(apiKey: nil, modelName: nil, subModelName: "Claude 3 Haiku") }
                                    Button("MiniMax-M2.7") { authManager.updateConfig(apiKey: nil, modelName: nil, subModelName: "MiniMax-M2.7") }
                                    Button("GPT-4o-mini") { authManager.updateConfig(apiKey: nil, modelName: nil, subModelName: "GPT-4o-mini") }
                                } label: {
                                    HStack(spacing: 16) {
                                        Image(systemName: "cpu")
                                            .font(.system(size: 20))
                                            .foregroundColor(AppTheme.textTertiary)
                                            .frame(width: 24)
                                        Text("后台冲浪子模型")
                                            .font(.system(size: 16, weight: .regular))
                                            .foregroundColor(AppTheme.textPrimary)
                                        Spacer()
                                        HStack(spacing: 4) {
                                            Text(authManager.subModelName)
                                                .font(.system(size: 14))
                                            Image(systemName: "chevron.up.chevron.down")
                                                .font(.system(size: 12))
                                        }
                                        .foregroundColor(AppTheme.textSecondary)
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Divider().background(AppTheme.strokeLighter).padding(.leading, 44)
                                
                                HStack(spacing: 16) {
                                    Image(systemName: "key")
                                        .font(.system(size: 20))
                                        .foregroundColor(AppTheme.textTertiary)
                                        .frame(width: 24)
                                    SecureField("点击配置 API Key", text: $apiKeyInput)
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundColor(AppTheme.textPrimary)
                                        .onSubmit {
                                            authManager.updateConfig(apiKey: apiKeyInput, modelName: nil)
                                        }
                                        
                                    if !apiKeyInput.isEmpty && apiKeyInput != authManager.apiKey {
                                        Button(action: {
                                            authManager.updateConfig(apiKey: apiKeyInput, modelName: nil)
                                        }) {
                                            Text("保存")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(AppTheme.brandOrange)
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                            }
                            .softCard()
                        }
                        
                        // 记忆架构配置
                        VStack(alignment: .leading, spacing: 16) {
                            Text("记忆与上下文")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)
                                .padding(.leading, 4)
                            
                            VStack(spacing: 0) {
                                SettingRow(icon: "brain.head.profile", title: "长期记忆", isEnabled: true)
                                Divider().background(AppTheme.strokeLighter).padding(.leading, 44)
                                SettingRow(icon: "clock.arrow.circlepath", title: "上下文自动压缩", isEnabled: true)
                                Divider().background(AppTheme.strokeLighter).padding(.leading, 44)
                                
                                Button(action: {
                                    authManager.clearMemories { _ in
                                        print("Memories cleared")
                                        // TODO: Show toast or alert
                                    }
                                }) {
                                    HStack(spacing: 16) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 20))
                                            .foregroundColor(.red)
                                            .frame(width: 24)
                                        Text("清空所有长期记忆")
                                            .font(.system(size: 16, weight: .regular))
                                            .foregroundColor(.red)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .softCard()
                        }
                        
                        // 技能与工具 (MCP)
                        VStack(alignment: .leading, spacing: 16) {
                            Text("橘长的技能 (MCP)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)
                                .padding(.leading, 4)
                            
                            VStack(spacing: 0) {
                                SettingRow(icon: "calendar", title: "日历访问", isEnabled: true)
                                Divider().background(AppTheme.strokeLighter).padding(.leading, 44)
                                SettingRow(icon: "doc.text", title: "本地文件读取", isEnabled: true)
                                Divider().background(AppTheme.strokeLighter).padding(.leading, 44)
                                SettingRow(icon: "globe", title: "联网搜索", isEnabled: false)
                            }
                            .softCard()
                        }
                        
                        // 退出登录
                        Button(action: {
                            AuthManager.shared.logout()
                        }) {
                            Text("退出登录")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.surface1)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.rM))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.rM)
                                        .stroke(AppTheme.strokeLighter, lineWidth: 1)
                                )
                        }
                        .padding(.top, 16)
                        
                        // 底部留白给 BottomNav
                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
        }
        .onAppear {
            authManager.fetchUserConfig()
            apiKeyInput = authManager.apiKey
        }
        .onReceive(authManager.$apiKey) { newKey in
            if !newKey.isEmpty && apiKeyInput.isEmpty {
                apiKeyInput = newKey
            }
        }
    }
}

struct SettingRow: View {
    let icon: String
    let title: String
    @State var isEnabled: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AppTheme.textTertiary)
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(AppTheme.textPrimary)
            
            Spacer()
            
            Toggle("", isOn: $isEnabled)
                .tint(AppTheme.brandOrange)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
