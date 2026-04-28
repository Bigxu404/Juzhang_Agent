import SwiftUI

struct SettingsView: View {
    @StateObject private var authManager = AuthManager.shared
    
    @State private var apiKey: String = ""
    @State private var modelName: String = "MiniMax-M2.7"
    @State private var exploreModelName: String = "MiniMax-M2.7"
    
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var successMessage = "操作成功"
    @State private var showError = false
    @State private var errorMessage = "操作失败"
    @State private var showMemoryResetConfirm = false
    
    // Preferences
    @AppStorage("pref_enable_haptics") private var enableHaptics: Bool = true
    @AppStorage("pref_enable_typing_delay") private var enableTypingDelay: Bool = true
    
    let availableModels = [
        "MiniMax-M2.7",
        "MiniMax-M2.7-highspeed",
        "MiniMax-M2.5",
        "MiniMax-M2.5-highspeed",
        "MiniMax-M2.1",
        "MiniMax-M2.1-highspeed",
        "MiniMax-M2",
        "MiniMax-Text-01"
    ]
    
    var body: some View {
        NavigationView {
            List {
                // 1. 账号与基础档案
                Section {
                    HStack(spacing: 15) {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text(authManager.username ?? "未知用户")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("数字老友通行证")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 5)
                }
                
                // 2. 大脑与模型配置
                Section(header: Text("大脑配置 (AI Core)"), footer: Text("配置您的专属 API Key 以唤醒 Agent。")) {
                    SecureField("输入您的 API Key (必填)", text: $apiKey)
                    
                    Picker("主模型 (日常对话)", selection: $modelName) {
                        ForEach(availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    
                    Picker("探索模型 (后台冲浪)", selection: $exploreModelName) {
                        ForEach(availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    
                    Button(action: saveConfig) {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("保存配置")
                                    .fontWeight(.semibold)
                                    .foregroundColor(apiKey.isEmpty ? .gray : .blue)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isLoading || apiKey.isEmpty)
                }
                
                // 3. 记忆与人设管理 (Phase 2 Placeholders)
                Section(header: Text("记忆与人设 (Memory & Persona)")) {
                    NavigationLink(destination: Text("当前人设看板开发中...")) {
                        Label("当前人设看板", systemImage: "person.text.rectangle")
                    }
                    NavigationLink(destination: MemoryVaultView()) {
                        Label("记忆保险库", systemImage: "brain.head.profile")
                    }
                    Button(action: {
                        showMemoryResetConfirm = true
                    }) {
                        Label("重置所有记忆", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
                
                // 4. 技能与工具库 (Phase 3 Placeholders)
                Section(header: Text("技能与工具 (Skills & Tools)")) {
                    NavigationLink(destination: SkillsView()) {
                        Label("我的技能 (Skills)", systemImage: "wand.and.stars")
                    }
                    NavigationLink(destination: McpAuthorizationView()) {
                        Label("外部授权 (MCP)", systemImage: "link")
                    }
                }
                
                // 5. 交互与偏好设置
                Section(header: Text("偏好设置 (Preferences)")) {
                    Toggle("触觉震动反馈 (Haptics)", isOn: $enableHaptics)
                    Toggle("打字机拟真延迟", isOn: $enableTypingDelay)
                }
                
                // 危险区
                Section {
                    Button(action: {
                        authManager.logout()
                    }) {
                        HStack {
                            Spacer()
                            Text("退出登录")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.pageGradient)
            .navigationTitle("个人中心")
            .onAppear(perform: loadConfig)
            .alert(isPresented: $showSuccess) {
                Alert(title: Text("成功"), message: Text(successMessage), dismissButton: .default(Text("确定")))
            }
            .alert("提示", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .confirmationDialog("确认重置所有记忆？", isPresented: $showMemoryResetConfirm, titleVisibility: .visible) {
                Button("确认重置", role: .destructive, action: resetAllMemories)
                Button("取消", role: .cancel) {}
            } message: {
                Text("此操作不可撤销。")
            }
        }
    }
    
    private func loadConfig() {
        guard let token = authManager.token else { return }
        
        guard let url = URL(string: "http://localhost:3000/api/user/me") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                DispatchQueue.main.async {
                    self.errorMessage = ErrorLocalizer.message(from: error, fallback: "读取用户配置失败。")
                    self.showError = true
                }
                return
            }
            guard let data = data else { return }
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let message = ErrorLocalizer.message(
                    statusCode: httpResponse.statusCode,
                    serverMessage: ErrorLocalizer.extractServerMessage(from: data),
                    fallback: "读取用户配置失败。"
                )
                DispatchQueue.main.async {
                    self.errorMessage = message
                    self.showError = true
                }
                return
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                DispatchQueue.main.async {
                    if let savedKey = json["apiKey"] as? String {
                        self.apiKey = savedKey
                    }
                    if let savedModel = json["modelName"] as? String {
                        self.modelName = normalizeModelName(savedModel)
                        self.exploreModelName = normalizeModelName(savedModel)
                    }
                }
            }
        }.resume()
    }
    
    private func saveConfig() {
        guard let token = authManager.token else { return }
        isLoading = true
        
        guard let url = URL(string: "http://localhost:3000/api/user/config") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "apiKey": apiKey.isEmpty ? NSNull() : apiKey,
            "modelName": normalizeModelName(modelName)
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error {
                    self.errorMessage = ErrorLocalizer.message(from: error, fallback: "保存配置失败，请稍后重试。")
                    self.showError = true
                } else if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    self.errorMessage = ErrorLocalizer.message(
                        statusCode: httpResponse.statusCode,
                        serverMessage: ErrorLocalizer.extractServerMessage(from: data),
                        fallback: "保存配置失败，请稍后重试。"
                    )
                    self.showError = true
                } else {
                    self.successMessage = "大脑配置已保存"
                    self.showSuccess = true
                }
            }
        }.resume()
    }

    private func resetAllMemories() {
        guard let token = authManager.token else { return }
        guard let url = URL(string: "http://localhost:3000/api/user/memories") else { return }

        isLoading = true

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error {
                    self.errorMessage = ErrorLocalizer.message(from: error, fallback: "重置记忆失败，请稍后重试。")
                    self.showError = true
                } else if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    self.errorMessage = ErrorLocalizer.message(
                        statusCode: httpResponse.statusCode,
                        serverMessage: ErrorLocalizer.extractServerMessage(from: data),
                        fallback: "重置记忆失败，请稍后重试。"
                    )
                    self.showError = true
                } else {
                    self.successMessage = "记忆已重置"
                    self.showSuccess = true
                }
            }
        }.resume()
    }

    private func normalizeModelName(_ raw: String) -> String {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "MiniMax-2.7", "minimax-2.7", "minimax-m2.7":
            return "MiniMax-M2.7"
        case "MiniMax-2.7-highspeed", "minimax-2.7-highspeed":
            return "MiniMax-M2.7-highspeed"
        case "MiniMax-2.5", "minimax-2.5":
            return "MiniMax-M2.5"
        case "MiniMax-2.5-highspeed", "minimax-2.5-highspeed":
            return "MiniMax-M2.5-highspeed"
        case "MiniMax-2.1", "minimax-2.1":
            return "MiniMax-M2.1"
        case "MiniMax-2.1-highspeed", "minimax-2.1-highspeed":
            return "MiniMax-M2.1-highspeed"
        case "minimax-m2":
            return "MiniMax-M2"
        default:
            return raw
        }
    }
}

#Preview {
    SettingsView()
}
