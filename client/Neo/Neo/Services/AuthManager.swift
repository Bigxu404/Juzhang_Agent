import Foundation
import Combine

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated: Bool = false
    @Published var token: String? = nil
    @Published var username: String? = nil
    
    private let baseURL = "http://localhost:3000/api/auth"
    
    private init() {
        // Load token from UserDefaults if exists
        if let savedToken = UserDefaults.standard.string(forKey: "authToken"),
           let savedUsername = UserDefaults.standard.string(forKey: "authUsername") {
            self.token = savedToken
            self.username = savedUsername
            self.isAuthenticated = true
        }
    }
    
    func login(username: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        performAuthRequest(endpoint: "/login", username: username, password: password, completion: completion)
    }
    
    func register(username: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        performAuthRequest(endpoint: "/register", username: username, password: password, completion: completion)
    }
    
    func logout() {
        self.token = nil
        self.username = nil
        self.isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "authUsername")
        
        AgentConnectionManager.shared.disconnect()
    }
    
    private func performAuthRequest(endpoint: String, username: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let actionText = endpoint == "/register" ? "注册失败，请稍后再试。" : "登录失败，请稍后再试。"
        guard let url = URL(string: baseURL + endpoint) else {
            completion(.failure(AppDisplayError(message: "服务地址无效，请检查客户端配置。")))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["username": username, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                let message = ErrorLocalizer.message(from: error, fallback: actionText)
                DispatchQueue.main.async { completion(.failure(AppDisplayError(message: message))) }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(AppDisplayError(message: "服务器返回为空，请稍后重试。"))) }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let serverMessage = ErrorLocalizer.extractServerMessage(from: data)
                let message = ErrorLocalizer.message(statusCode: httpResponse.statusCode, serverMessage: serverMessage, fallback: actionText)
                DispatchQueue.main.async { completion(.failure(AppDisplayError(message: message))) }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let token = json["token"] as? String,
                   let userDict = json["user"] as? [String: Any],
                   let username = userDict["username"] as? String {
                    
                    DispatchQueue.main.async {
                        self.token = token
                        self.username = username
                        self.isAuthenticated = true
                        UserDefaults.standard.set(token, forKey: "authToken")
                        UserDefaults.standard.set(username, forKey: "authUsername")
                        completion(.success(()))
                    }
                } else {
                    DispatchQueue.main.async { completion(.failure(AppDisplayError(message: "登录响应格式异常，请稍后再试。"))) }
                }
            } catch {
                let message = ErrorLocalizer.message(from: error, fallback: actionText)
                DispatchQueue.main.async { completion(.failure(AppDisplayError(message: message))) }
            }
        }.resume()
    }
}
