import SwiftUI
import UniformTypeIdentifiers

/// 文档选择器
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .plainText, .commaSeparatedText, .image, UTType(filenameExtension: "xlsx")!, UTType(filenameExtension: "docx")!].compactMap { $0 }, asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.selectedURL = urls.first
        }
    }
}

/// 消息模型
struct UIChatMessage: Identifiable {
    let id = UUID()
    var text: String
    let type: MessageType
    let state: AgentState?
    var isStreaming: Bool = false
    var components: [MessageComponent] = []
}

/// 主聊天界面
struct ChatView: View {
    @Binding var showDrawer: Bool
    @State private var inputText = ""
    @ObservedObject private var connectionManager = AgentConnectionManager.shared
    @State private var isProcessExpanded = false
    @State private var isNewChatAnimating = false
    @State private var isShowingDocumentPicker = false
    @State private var attachedFileURL: URL? = nil
    @State private var uploadedFileURL: String? = nil
    @State private var isUploading = false
    
    private var currentState: AgentState {
        switch connectionManager.agentState.status {
        case "IDLE", "DISCONNECTED": return .idle
        case "THINKING": return .thinking
        case "WORKING": return .working
        case "SUCCESS": return .success
        default: return .idle
        }
    }
    
    var body: some View {
        mainContent
            .onAppear {
                connectionManager.fetchSessions()
                LocationManager.shared.requestPermissionAndLocation()
            }
    }
    
    // 主界面内容抽取出来
    private var mainContent: some View {
        ZStack {
            // 全局背景 (奶油雾白)
            AppTheme.bgBase.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. 顶部导航栏
                ZStack {
                    HStack {
                        Button(action: {
                            connectionManager.fetchSessions()
                            withAnimation { showDrawer = true }
                        }) {
                            Image("more")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 44)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            isNewChatAnimating = true
                            connectionManager.clearSession()
                        }) {
                            ZStack(alignment: .bottomTrailing) {
                                if isNewChatAnimating {
                                    Image("newchat2")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 35) // 根据原始比例缩放，使得动画元素同级别大小
                                        .padding(.bottom, 2) // 底部微调对齐
                                } else {
                                    Image("newchat")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 44)
                                }
                            }
                            .frame(width: 80, height: 44, alignment: .bottomTrailing) // 固定包围盒宽度，防止跳动
                        }
                    }
                    
                    Text("对话")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .background(AppTheme.bgBase.ignoresSafeArea(.all, edges: .top))
                .zIndex(10)
                
                // 2. Message ListView (对话流)
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            
                            // 历史消息列表
                            ForEach(connectionManager.messages) { msg in
                                if msg.components.isEmpty {
                                    ChatBubble(text: msg.text, type: msg.type, state: msg.state, isStreaming: msg.isStreaming, showAvatar: true)
                                        .padding(.top, msg.id == connectionManager.messages.first?.id ? 24 : 0)
                                } else {
                                    VStack(spacing: 4) {
                                        ForEach(Array(msg.components.enumerated()), id: \.offset) { index, component in
                                            let showAv = (index == 0)
                                            let isLastMsg = (msg.id == connectionManager.messages.last?.id)
                                            let avState = (msg.type == .agent && isLastMsg) ? currentState : .idle

                                            switch component {
                                            case .text(_):
                                                MessageComponentWrapper(component: component, message: msg, index: index, avState: avState, showAv: showAv)
                                            case .thinking(_, _):
                                                MessageComponentWrapper(component: component, message: msg, index: index, avState: avState, showAv: showAv)
                                            case .toolCall(_, _, _):
                                                MessageComponentWrapper(component: component, message: msg, index: index, avState: avState, showAv: showAv)
                                            case .file(_, _):
                                                MessageComponentWrapper(component: component, message: msg, index: index, avState: avState, showAv: showAv)
                                            case .choice(let question, let options):
                                                MessageComponentWrapper(component: component, message: msg, index: index, avState: avState, showAv: showAv)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            /* 过程总览卡片 (模拟思考/工具调用) 已经被干掉，视觉更清爽 */
                            
                            // 底部留白给 BottomNav
                            Color.clear.frame(height: 20).id("bottom")
                        }
                    }
                    .onChange(of: connectionManager.messages.count) { oldValue, newValue in
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    .onChange(of: currentState) { oldValue, newValue in
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
                
                // 3. Input Bar (单行变双行展开设计)
                VStack(spacing: 0) {
                    if let fileURL = attachedFileURL {
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundColor(AppTheme.brandOrange)
                            Text(fileURL.lastPathComponent)
                                .font(.system(size: 14))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            if isUploading {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                            Spacer()
                            Button(action: {
                                attachedFileURL = nil
                                uploadedFileURL = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(8)
                        .background(AppTheme.inputBg)
                        .cornerRadius(8)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                    }

                    HStack(alignment: .bottom, spacing: 8) {
                        // 内部左侧功能图标 (加号)
                        Button(action: { isShowingDocumentPicker = true }) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .padding(.leading, 12)
                        .padding(.bottom, 8)
                        
                        // 中间文本输入：默认单行高度，按需增至两行（不预占大块空白）
                        TextField("给橘长递纸条...", text: $inputText, axis: .vertical)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(AppTheme.textPrimary)
                            .lineLimit(1...2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 10)
                        
                        // 内部右侧发送/停止（与输入区底部对齐，避免 Spacer 撑满整行高度）
                        Group {
                            if currentState == .thinking || currentState == .working {
                                Button(action: {
                                    connectionManager.stopGeneration()
                                }) {
                                    Image(systemName: "stop.fill")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 28, height: 28)
                                        .background(AppTheme.brandOrange)
                                        .clipShape(Circle())
                                }
                            } else {
                                Button(action: sendMessage) {
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 28, height: 28)
                                        .background((inputText.isEmpty && uploadedFileURL == nil) ? AppTheme.textTertiary.opacity(0.3) : AppTheme.brandOrange)
                                        .clipShape(Circle())
                                }
                                .disabled(inputText.isEmpty && uploadedFileURL == nil)
                                .animation(.easeInOut(duration: 0.2), value: inputText.isEmpty && uploadedFileURL == nil)
                            }
                        }
                        .padding(.trailing, 8)
                        .padding(.bottom, 8)
                    }
                    .frame(minHeight: 44)
                    .background(AppTheme.inputBg) // 整个 HStack 变成输入框
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8) // 在 TabBar 上方直接靠着
                }
                .background(AppTheme.bgBase) // 和页面背景融为一体
                .sheet(isPresented: $isShowingDocumentPicker) {
                    DocumentPicker(selectedURL: $attachedFileURL)
                }
                .onChange(of: attachedFileURL) { oldValue, newValue in
                    if let url = newValue {
                        uploadSelectedFile(url: url)
                    }
                }
            }
        }
    }
    
    private func uploadSelectedFile(url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        isUploading = true
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: tempURL)
        try? FileManager.default.copyItem(at: url, to: tempURL)
        
        connectionManager.uploadFile(fileURL: tempURL, sessionId: nil) { result in
            DispatchQueue.main.async {
                self.isUploading = false
                switch result {
                case .success(let uploadedUrl):
                    self.uploadedFileURL = "http://localhost:3000\(uploadedUrl)"
                case .failure(let error):
                    print("Upload failed: \(error)")
                    self.attachedFileURL = nil
                }
            }
        }
    }
    
    // 实际发送消息逻辑
    private func sendMessage() {
        let hasText = !inputText.isEmpty
        let hasFile = uploadedFileURL != nil
        guard hasText || hasFile else { return }
        
        var userText = inputText
        if userText.isEmpty && hasFile {
            userText = "[发送了文件]"
        }
        inputText = ""
        
        var attachments: [String] = []
        if let fileUrl = uploadedFileURL {
            attachments.append(fileUrl)
            uploadedFileURL = nil
            attachedFileURL = nil
        }
        
        // 如果当前是鱼骨头状态，用户发送消息时变回抓鱼状态
        if isNewChatAnimating {
            isNewChatAnimating = false
        }
        
        // 调用 AgentConnectionManager 实际发送请求到后端
        connectionManager.sendMessage(userText, attachments: attachments)
        
        withAnimation {
            isProcessExpanded = true
        }
    }
    
    // 辅助方法：根据状态返回文案
    private func statusText(for state: AgentState) -> String {
        return connectionManager.agentState.description
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView(showDrawer: .constant(false))
    }
}
