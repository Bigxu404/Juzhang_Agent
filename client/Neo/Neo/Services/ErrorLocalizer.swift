import Foundation

struct AppDisplayError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum ErrorLocalizer {
    static func message(from error: Error, fallback: String = "操作失败，请稍后再试。") -> String {
        if let displayError = error as? AppDisplayError {
            return displayError.message
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "网络不可用，请检查网络连接。"
            case .timedOut:
                return "请求超时，请稍后重试。"
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return "无法连接服务器，请确认后端服务已启动。"
            case .networkConnectionLost:
                return "网络连接中断，请重试。"
            default:
                return "网络请求失败，请稍后重试。"
            }
        }

        let raw = (error as NSError).localizedDescription
        return mappedServerMessage(raw) ?? fallback
    }

    static func message(statusCode: Int, serverMessage: String?, fallback: String) -> String {
        if let mapped = mappedServerMessage(serverMessage) {
            return mapped
        }

        switch statusCode {
        case 400:
            return "请求参数有误，请检查后重试。"
        case 401:
            return "登录已失效，请重新登录。"
        case 403:
            return "没有权限执行该操作。"
        case 404:
            return "目标资源不存在或已被删除。"
        case 409:
            return "数据冲突，请刷新后重试。"
        case 422:
            return "输入内容不符合要求，请检查后重试。"
        case 429:
            return "请求过于频繁，请稍后再试。"
        case 500...599:
            return "服务器开小差了，请稍后再试。"
        default:
            return fallback
        }
    }

    static func extractServerMessage(from data: Data?) -> String? {
        guard let data else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return (json["error"] as? String) ?? (json["message"] as? String)
    }

    private static func mappedServerMessage(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let lower = text.lowercased()
        if lower.contains("could not connect to the server") {
            return "无法连接服务器，请确认后端服务已启动。"
        }
        if lower.contains("unauthorized") {
            return "未登录或登录状态已过期，请重新登录。"
        }
        if lower.contains("invalid token") {
            return "登录令牌无效，请重新登录。"
        }
        if lower.contains("invalid username or password") {
            return "用户名或密码错误，请重试。"
        }
        if lower.contains("user already exists") {
            return "该用户名已被注册，请更换后重试。"
        }
        if lower.contains("no data received") {
            return "服务器返回为空，请稍后重试。"
        }
        if lower.contains("invalid response format") {
            return "服务器响应格式异常，请稍后再试。"
        }
        if lower.contains("memory not found") {
            return "该记忆不存在或已被删除。"
        }
        if lower.contains("skill not found") {
            return "该技能不存在或已被删除。"
        }
        if lower.contains("name, description and content are required") {
            return "请填写完整的技能名称、描述和内容。"
        }
        if lower.contains("providerid is required") {
            return "缺少授权目标，请重试。"
        }

        // 已经是中文就直接返回
        if text.range(of: "[\\u4e00-\\u9fa5]", options: .regularExpression) != nil {
            return text
        }
        return nil
    }
}
