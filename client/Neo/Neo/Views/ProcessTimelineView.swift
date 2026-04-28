import SwiftUI

/// 过程总览卡片 (工具调用 / subagent / 思考)
struct ProcessTimelineView: View {
    let title: String
    let subtitle: String
    let isExpanded: Bool
    let state: AgentState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 一级：过程总览条 (默认常驻)
            HStack(spacing: 12) {
                // 左侧状态 Icon
                Group {
                    if state == .working || state == .thinking {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(AppTheme.brandOrange)
                    } else if state == .success {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(red: 55/255, green: 178/255, blue: 108/255)) // Success
                    } else {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(Color(red: 78/255, green: 124/255, blue: 243/255)) // Info
                    }
                }
                .frame(width: 20, height: 20)
                
                // 标题与进度
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                Spacer()
                
                // 展开/收起箭头
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? -180 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // 二级：详情列表 (展开时显示)
            if isExpanded {
                Divider()
                    .background(AppTheme.strokeLighter)
                    .padding(.horizontal, 16)
                
                VStack(alignment: .leading, spacing: 12) {
                    // 这里可以传入一个列表，目前用假数据占位
                    ProcessItemRow(icon: "magnifyingglass", text: "搜索：北京明日天气", status: "完成")
                    ProcessItemRow(icon: "doc.text", text: "读取：客户会议模板", status: "完成")
                    ProcessItemRow(icon: "pencil.and.outline", text: "起草：会议邀请邮件", status: "进行中...")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(AppTheme.surface2) // 展开区域使用更暖的底色
            }
        }
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.rM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.rM, style: .continuous)
                .stroke(AppTheme.strokeSoft, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
    }
}

struct ProcessItemRow: View {
    let icon: String
    let text: String
    let status: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textTertiary)
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(AppTheme.textSecondary)
            
            Spacer()
            
            Text(status)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(status == "完成" ? Color(red: 55/255, green: 178/255, blue: 108/255) : AppTheme.brandOrange)
        }
    }
}

struct ProcessTimelineView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ProcessTimelineView(title: "正在处理", subtitle: "工具调用 3 项", isExpanded: true, state: .working)
            
            ProcessTimelineView(title: "我刚刚做了这些", subtitle: "耗时 2.4s", isExpanded: false, state: .success)
        }
        .padding(.vertical, 40)
        .background(AppTheme.bgBase)
    }
}
