import SwiftUI

struct ActionApprovalCard: View {
    let title: String
    let subtitle: String
    let detail: String
    let rejectText: String
    let approveText: String
    let onReject: () -> Void
    let onApprove: () -> Void

    var body: some View {
        VStack(spacing: 15) {
            Text(title)
                .font(.headline)
                .foregroundColor(.red)

            Text(subtitle)
                .font(.body)

            Text(detail)
                .font(.caption)
                .foregroundColor(.gray)

            HStack {
                Button(action: onReject) {
                    Text(rejectText)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                }

                Button(action: onApprove) {
                    Text(approveText)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.heroGradient)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .cardSurface()
        .padding()
    }
}

#Preview {
    ActionApprovalCard(
        title: "⚠️ 操作确认",
        subtitle: "是否允许执行该操作？",
        detail: "该操作可能修改外部系统数据。",
        rejectText: "拒绝",
        approveText: "允许",
        onReject: {},
        onApprove: {}
    )
}
