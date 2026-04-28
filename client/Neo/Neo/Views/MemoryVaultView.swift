import SwiftUI

struct UIMemoryItem: Identifiable {
    let id = UUID()
    let title: String
    let content: String
    let date: String
    let tag: String
}

struct MemoryVaultView: View {
    @State private var memories: [UIMemoryItem] = [
        UIMemoryItem(title: "冰岛游记攻略", content: "你计划在 10 月份去冰岛，我帮你整理了环岛路线和极光观测点...", date: "昨天", tag: "旅行"),
        UIMemoryItem(title: "工作日报模板", content: "每天下午 6 点提醒你填写日报，格式包含：今日进度、明日计划、风险点...", date: "3天前", tag: "工作"),
        UIMemoryItem(title: "咖啡偏好", content: "你喜欢喝燕麦拿铁，半糖，少冰。下次帮你点单时我会记住的。", date: "上周", tag: "生活")
    ]
    
    var body: some View {
        ZStack {
            AppTheme.bgBase.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("沙发下的藏宝库")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.textTertiary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // List
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(memories) { memory in
                            MemoryCard(item: memory)
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

struct MemoryCard: View {
    let item: UIMemoryItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(item.tag)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.brandOrange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.brandOrangeSoft)
                    .clipShape(Capsule())
                
                Spacer()
                
                Text(item.date)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textTertiary)
            }
            
            Text(item.title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppTheme.textPrimary)
            
            Text(item.content)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textSecondary)
                .lineSpacing(4)
                .lineLimit(2)
        }
        .padding(20)
        .softCard() // 使用 AppTheme 中定义的统一卡片样式
    }
}

struct MemoryVaultView_Previews: PreviewProvider {
    static var previews: some View {
        MemoryVaultView()
    }
}
