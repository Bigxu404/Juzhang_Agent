import SwiftUI

struct McpAuthorizationView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var providers: [McpProvider] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    @State private var pendingProvider: McpProvider? = nil
    @State private var showResultAlert = false
    @State private var resultMessage = ""

    var body: some View {
        List {
            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Section(header: Text("外部授权"), footer: Text("授权后，Agent 可在你的允许范围内调用对应外部能力。")) {
                if isLoading && providers.isEmpty {
                    ProgressView("加载授权状态...")
                } else if providers.isEmpty {
                    Text("暂无可用的 MCP Provider")
                        .foregroundColor(.gray)
                } else {
                    ForEach(providers) { provider in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(provider.name)
                                        .font(.headline)
                                    Text(provider.description)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                statusBadge(connected: provider.connected)
                            }

                            if !provider.connected {
                                Button("发起授权") {
                                    pendingProvider = provider
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("MCP 外部授权")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isLoading {
                    ProgressView()
                } else {
                    Button("刷新", action: loadProviders)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let provider = pendingProvider {
                ActionApprovalCard(
                    title: "⚠️ 外部授权确认",
                    subtitle: "是否授权 Agent 访问 \(provider.name)？",
                    detail: provider.description,
                    rejectText: "取消",
                    approveText: "确认授权",
                    onReject: {
                        pendingProvider = nil
                    },
                    onApprove: {
                        authorize(provider: provider)
                    }
                )
                .transition(.move(edge: .bottom))
                .animation(.spring(), value: pendingProvider != nil)
            }
        }
        .alert("授权结果", isPresented: $showResultAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(resultMessage)
        }
        .refreshable {
            loadProviders()
        }
        .onAppear(perform: loadProviders)
    }

    @ViewBuilder
    private func statusBadge(connected: Bool) -> some View {
        Text(connected ? "已连接" : "未连接")
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background((connected ? Color.green : Color.orange).opacity(0.15))
            .foregroundColor(connected ? .green : .orange)
            .cornerRadius(10)
    }

    private func loadProviders() {
        guard let token = authManager.token else { return }
        guard let url = URL(string: "http://localhost:3000/api/user/mcp/providers") else { return }

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
                    self.errorMessage = ErrorLocalizer.message(from: error, fallback: "获取授权状态失败，请稍后重试。")
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode),
                  let data = data else {
                DispatchQueue.main.async {
                    self.errorMessage = ErrorLocalizer.message(
                        statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1,
                        serverMessage: ErrorLocalizer.extractServerMessage(from: data),
                        fallback: "获取授权状态失败，请稍后重试。"
                    )
                }
                return
            }

            do {
                let decoded = try parseProvidersResponse(data)
                DispatchQueue.main.async {
                    self.providers = decoded.providers
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "解析授权状态失败，请稍后重试。"
                }
            }
        }.resume()
    }

    private func authorize(provider: McpProvider) {
        guard let token = authManager.token else { return }
        guard let url = URL(string: "http://localhost:3000/api/user/mcp/authorize") else { return }

        isLoading = true
        errorMessage = nil

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["providerId": provider.id])

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                self.pendingProvider = nil
            }

            if let error = error {
                DispatchQueue.main.async {
                    self.resultMessage = ErrorLocalizer.message(from: error, fallback: "授权请求失败，请稍后重试。")
                    self.showResultAlert = true
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode),
                  let data = data else {
                DispatchQueue.main.async {
                    self.resultMessage = ErrorLocalizer.message(
                        statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1,
                        serverMessage: ErrorLocalizer.extractServerMessage(from: data),
                        fallback: "授权请求失败，请稍后重试。"
                    )
                    self.showResultAlert = true
                }
                return
            }

            if let decoded = try? parseAuthorizeResponse(data) {
                DispatchQueue.main.async {
                    self.resultMessage = decoded.message
                    self.showResultAlert = true
                    self.loadProviders()
                }
            } else {
                DispatchQueue.main.async {
                    self.resultMessage = "授权结果解析失败，请稍后重试。"
                    self.showResultAlert = true
                }
            }
        }.resume()
    }

    private func parseProvidersResponse(_ data: Data) throws -> McpProvidersResponse {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let rawProviders = (json?["providers"] as? [[String: Any]]) ?? []
        let providers = rawProviders.compactMap { raw -> McpProvider? in
            guard
                let id = raw["id"] as? String,
                let name = raw["name"] as? String,
                let description = raw["description"] as? String,
                let connected = raw["connected"] as? Bool
            else {
                return nil
            }
            return McpProvider(id: id, name: name, description: description, connected: connected)
        }
        return McpProvidersResponse(providers: providers)
    }

    private func parseAuthorizeResponse(_ data: Data) throws -> McpAuthorizeResponse {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return McpAuthorizeResponse(
            success: (json?["success"] as? Bool) ?? false,
            connected: (json?["connected"] as? Bool) ?? false,
            message: (json?["message"] as? String) ?? "授权完成"
        )
    }
}

#Preview {
    NavigationView {
        McpAuthorizationView()
    }
}
