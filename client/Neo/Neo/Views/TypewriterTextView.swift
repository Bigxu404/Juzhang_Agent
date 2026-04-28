import SwiftUI

/// 流式打字机效果的文本视图
struct TypewriterTextView: View {
    let fullText: String
    let speed: Double // 每个字符的延迟时间 (秒)
    let isUser: Bool
    
    @State private var displayedText: String = ""
    @State private var timer: Timer?
    
    var body: some View {
        Text(displayedText)
            .font(.system(size: 16, weight: .regular))
            .foregroundColor(isUser ? .white : AppTheme.textPrimary)
            .lineSpacing(4)
            .onAppear {
                startTyping()
            }
            .onChange(of: fullText) { oldText, newText in
                // 如果外部文本更新 (例如流式接收新数据)，继续打字
                if newText.count > displayedText.count {
                    startTyping()
                } else if newText.isEmpty {
                    displayedText = ""
                }
            }
            .onDisappear {
                timer?.invalidate()
            }
    }
    
    private func startTyping() {
        timer?.invalidate()
        
        // 如果是用户消息，直接显示全部，不需要打字机效果
        if isUser {
            displayedText = fullText
            return
        }
        
        var currentIndex = displayedText.count
        
        timer = Timer.scheduledTimer(withTimeInterval: speed, repeats: true) { t in
            if currentIndex < fullText.count {
                let index = fullText.index(fullText.startIndex, offsetBy: currentIndex)
                displayedText.append(fullText[index])
                currentIndex += 1
            } else {
                t.invalidate()
            }
        }
    }
}
