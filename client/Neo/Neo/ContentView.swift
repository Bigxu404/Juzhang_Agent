import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                TabView(selection: $selectedTab) {
                    ChatView()
                        .tabItem {
                            Image(systemName: "message.fill")
                            Text("聊天")
                        }
                        .tag(0)
                        .onAppear {
                            if let token = authManager.token {
                                AgentConnectionManager.shared.connect(token: token)
                            }
                        }
                    
                    SettingsView()
                        .tabItem {
                            Image(systemName: "gearshape.fill")
                            Text("设置")
                        }
                        .tag(1)
                }
                .tint(AppTheme.brand)
            } else {
                AuthView()
            }
        }
    }
}

#Preview {
    ContentView()
}
