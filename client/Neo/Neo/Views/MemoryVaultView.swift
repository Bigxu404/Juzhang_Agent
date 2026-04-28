import SwiftUI

struct MemoryVaultView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var memories: [MemoryItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showClearAllConfirm = false

    var body: some View {
        Group {
            if isLoading && memories.isEmpty {
                ProgressView("正在读取记忆...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = errorMessage, memories.isEmpty {
                VStack(spacing: 12) {
                    Text("加载失败")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    Button("重试", action: loadMemories)
                        .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if memories.isEmpty {
                ContentUnavailableView(
                    "暂无长期记忆",
                    systemImage: "brain.head.profile",
                    description: Text("你和 Agent 的有效对话会逐步沉淀在这里。")
                )
            } else {
                List {
                    if let errorMessage = errorMessage {
                        Section {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    Section {
                        ForEach(memories) { memory in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(memory.content)
                                    .font(.body)
                                    .lineLimit(4)
                                Text(formatDate(memory.createdAt))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 6)
                        }
                        .onDelete(perform: deleteMemories)
                    } header: {
                        Text("记忆片段")
                    } footer: {
                        Text("左滑可删除单条记忆。")
                    }

                    Section {
                        Button(role: .destructive) {
                            showClearAllConfirm = true
                        } label: {
                            Text("清空全部记忆")
                        }
                    }
                }
                .refreshable {
                    loadMemories()
                }
            }
        }
        .navigationTitle("记忆保险库")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isLoading {
                    ProgressView()
                } else {
                    Button("刷新", action: loadMemories)
                }
            }
        }
        .confirmationDialog("确认清空全部长期记忆？", isPresented: $showClearAllConfirm, titleVisibility: .visible) {
            Button("确认清空", role: .destructive, action: clearAllMemories)
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作不可撤销。")
        }
        .onAppear(perform: loadMemories)
    }

    private func loadMemories() {
        guard let token = authManager.token else { return }
        guard let url = URL(string: "http://localhost:3000/api/user/memories?limit=100") else { return }

        isLoading = true
        errorMessage = nil

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
            }

            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = ErrorLocalizer.message(from: error, fallback: "读取记忆失败，请稍后重试。")
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.errorMessage = "服务返回为空，请稍后重试。"
                }
                return
            }
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let message = ErrorLocalizer.message(
                    statusCode: httpResponse.statusCode,
                    serverMessage: ErrorLocalizer.extractServerMessage(from: data),
                    fallback: "读取记忆失败，请稍后重试。"
                )
                DispatchQueue.main.async {
                    self.errorMessage = message
                }
                return
            }

            do {
                let decoded = try JSONDecoder().decode([MemoryItem].self, from: data)
                DispatchQueue.main.async {
                    self.memories = decoded
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "解析数据失败：\(error.localizedDescription)"
                }
            }
        }.resume()
    }

    private func deleteMemories(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        let memory = memories[index]

        deleteMemory(id: memory.id) { success in
            if success {
                DispatchQueue.main.async {
                    self.memories.remove(atOffsets: offsets)
                }
            }
        }
    }

    private func deleteMemory(id: String, completion: @escaping (Bool) -> Void) {
        guard let token = authManager.token else {
            completion(false)
            return
        }
        guard let url = URL(string: "http://localhost:3000/api/user/memories/\(id)") else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = ErrorLocalizer.message(from: error, fallback: "删除记忆失败，请稍后重试。")
                }
                completion(false)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                DispatchQueue.main.async {
                    self.errorMessage = ErrorLocalizer.message(
                        statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1,
                        serverMessage: ErrorLocalizer.extractServerMessage(from: data),
                        fallback: "删除记忆失败，请稍后重试。"
                    )
                }
                completion(false)
                return
            }

            completion(true)
        }.resume()
    }

    private func clearAllMemories() {
        guard let token = authManager.token else { return }
        guard let url = URL(string: "http://localhost:3000/api/user/memories") else { return }

        isLoading = true
        errorMessage = nil

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
            }

            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = ErrorLocalizer.message(from: error, fallback: "清空记忆失败，请稍后重试。")
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                DispatchQueue.main.async {
                    self.errorMessage = ErrorLocalizer.message(
                        statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1,
                        serverMessage: ErrorLocalizer.extractServerMessage(from: data),
                        fallback: "清空记忆失败，请稍后重试。"
                    )
                }
                return
            }

            DispatchQueue.main.async {
                self.memories = []
            }
        }.resume()
    }

    private func formatDate(_ isoString: String) -> String {
        let parser = ISO8601DateFormatter()
        if let date = parser.date(from: isoString) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            return formatter.string(from: date)
        }
        return isoString
    }
}

#Preview {
    NavigationView {
        MemoryVaultView()
    }
}
