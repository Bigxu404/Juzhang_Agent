import SwiftUI

struct SettingsView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var apiKey: String = ""
    
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
                                HStack(spacing: 16) {
                                    Image(systemName: "cpu")
                                        .font(.system(size: 20))
                                        .foregroundColor(AppTheme.textTertiary)
                                        .frame(width: 24)
                                    Text("默认推理模型")
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Spacer()
                                    Text(AuthManager.shared.modelName)
                                        .font(.system(size: 14))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                
                                Divider().background(AppTheme.strokeLighter).padding(.leading, 44)
                                
                                HStack(spacing: 16) {
                                    Image(systemName: "cpu")
                                        .font(.system(size: 20))
                                        .foregroundColor(AppTheme.textTertiary)
                                        .frame(width: 24)
                                    Text("后台冲浪子模型")
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Spacer()
                                    Text("Claude 3 Haiku")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                
                                Divider().background(AppTheme.strokeLighter).padding(.leading, 44)
                                
                                HStack(spacing: 16) {
                                    Image(systemName: "key")
                                        .font(.system(size: 20))
                                        .foregroundColor(AppTheme.textTertiary)
                                        .frame(width: 24)
                                    SecureField("点击配置 API Key", text: $apiKey)
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundColor(AppTheme.textPrimary)
                                        .onChange(of: apiKey) { _, newValue in
                                            // TODO: Save to backend via API
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
