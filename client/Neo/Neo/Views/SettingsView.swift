import SwiftUI

struct SettingsView: View {
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
                                    Text("胖")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(AppTheme.textSecondary)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("小胖")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(AppTheme.textPrimary)
                                Text("相伴 128 天")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(AppTheme.textTertiary)
                        }
                        .padding(20)
                        .softCard()
                        
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
