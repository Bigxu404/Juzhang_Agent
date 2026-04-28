import SwiftUI

struct AuthView: View {
    @StateObject private var authManager = AuthManager.shared
    
    @State private var username = ""
    @State private var password = ""
    @State private var isRegistering = false
    @State private var errorMessage: String? = nil
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            AppTheme.pageGradient
                .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.heroGradient)
                            .frame(width: 72, height: 72)
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 28, weight: .semibold))
                    }
                    Text(isRegistering ? "创建数字老友账号" : "欢迎回来")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("连接你的专属数字老友")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 14) {
                    TextField("用户名", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppTheme.strokeLighter, lineWidth: 1)
                        )

                    SecureField("密码", text: $password)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppTheme.strokeLighter, lineWidth: 1)
                        )

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(action: handleAuth) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(isRegistering ? "注册" : "登录")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(isLoading || username.isEmpty || password.isEmpty)
                    .opacity((isLoading || username.isEmpty || password.isEmpty) ? 0.6 : 1)

                    Button(action: {
                        isRegistering.toggle()
                        errorMessage = nil
                    }) {
                        Text(isRegistering ? "已有账号？去登录" : "没有账号？去注册")
                            .font(.footnote)
                            .foregroundColor(AppTheme.brandOrange)
                            .fontWeight(.medium)
                    }
                    .padding(.top, 4)
                }
                .padding(20)
                .softCard()

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 22)
            .padding(.top, 48)
            .padding(.bottom, 28)
        }
    }
    
    private func handleAuth() {
        isLoading = true
        errorMessage = nil
        
        let completion: (Result<Void, Error>) -> Void = { result in
            self.isLoading = false
            switch result {
            case .success():
                // AuthManager handles the state change
                break
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
        
        if isRegistering {
            authManager.register(username: username, password: password, completion: completion)
        } else {
            authManager.login(username: username, password: password, completion: completion)
        }
    }
}

#Preview {
    AuthView()
}
