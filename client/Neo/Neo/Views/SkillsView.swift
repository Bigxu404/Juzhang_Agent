import SwiftUI

struct SkillsView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var skills: [SkillItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    @State private var newName = ""
    @State private var newDescription = ""
    @State private var newContent = ""
    @State private var isCreating = false

    var body: some View {
        List {
            Section(header: Text("新建技能"), footer: Text("建议使用结构化 SOP 内容（目标、输入、步骤、输出格式）。")) {
                TextField("技能名称", text: $newName)
                TextField("技能描述（告诉 Agent 何时使用）", text: $newDescription)
                TextEditor(text: $newContent)
                    .frame(minHeight: 100)

                Button(action: createSkill) {
                    HStack {
                        if isCreating {
                            ProgressView()
                        }
                        Text("保存技能")
                    }
                }
                .disabled(isCreating || newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            Section(header: Text("我的技能"), footer: Text("左滑可删除技能。开关控制是否允许 Agent 使用该技能。")) {
                if isLoading && skills.isEmpty {
                    ProgressView("加载中...")
                } else if skills.isEmpty {
                    Text("还没有技能，先创建一个。")
                        .foregroundColor(.gray)
                } else {
                    ForEach(skills) { skill in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(skill.name)
                                    .font(.headline)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { skill.isActive },
                                    set: { newValue in
                                        updateSkillStatus(skillId: skill.id, isActive: newValue)
                                    }
                                ))
                                .labelsHidden()
                            }

                            Text(skill.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)

                            Text(skill.content)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(4)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteSkills)
                }
            }
        }
        .navigationTitle("我的技能")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isLoading {
                    ProgressView()
                } else {
                    Button("刷新", action: loadSkills)
                }
            }
        }
        .refreshable {
            loadSkills()
        }
        .onAppear(perform: loadSkills)
    }

    private func loadSkills() {
        guard let token = authManager.token else { return }
        guard let url = URL(string: "http://localhost:3000/api/user/skills") else { return }

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
                    self.errorMessage = ErrorLocalizer.message(from: error, fallback: "加载技能失败，请稍后重试。")
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
                DispatchQueue.main.async {
                    self.errorMessage = ErrorLocalizer.message(
                        statusCode: httpResponse.statusCode,
                        serverMessage: ErrorLocalizer.extractServerMessage(from: data),
                        fallback: "加载技能失败，请稍后重试。"
                    )
                }
                return
            }

            do {
                let decoded = try JSONDecoder().decode([SkillItem].self, from: data)
                DispatchQueue.main.async {
                    self.skills = decoded
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "解析技能列表失败：\(error.localizedDescription)"
                }
            }
        }.resume()
    }

    private func createSkill() {
        guard let token = authManager.token else { return }
        guard let url = URL(string: "http://localhost:3000/api/user/skills") else { return }

        isCreating = true
        errorMessage = nil

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "name": newName,
            "description": newDescription,
            "content": newContent
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isCreating = false
            }

            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = ErrorLocalizer.message(from: error, fallback: "保存技能失败，请稍后重试。")
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                DispatchQueue.main.async {
                    self.errorMessage = ErrorLocalizer.message(
                        statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1,
                        serverMessage: ErrorLocalizer.extractServerMessage(from: data),
                        fallback: "保存技能失败，请检查输入。"
                    )
                }
                return
            }

            DispatchQueue.main.async {
                self.newName = ""
                self.newDescription = ""
                self.newContent = ""
                self.loadSkills()
            }
        }.resume()
    }

    private func updateSkillStatus(skillId: String, isActive: Bool) {
        guard let token = authManager.token else { return }
        guard let url = URL(string: "http://localhost:3000/api/user/skills/\(skillId)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["isActive": isActive])

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = ErrorLocalizer.message(from: error, fallback: "更新技能状态失败，请稍后重试。")
                    self.loadSkills()
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                DispatchQueue.main.async {
                    self.errorMessage = ErrorLocalizer.message(
                        statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1,
                        serverMessage: ErrorLocalizer.extractServerMessage(from: data),
                        fallback: "更新技能状态失败，请稍后重试。"
                    )
                    self.loadSkills()
                }
                return
            }

            DispatchQueue.main.async {
                if let index = self.skills.firstIndex(where: { $0.id == skillId }) {
                    let old = self.skills[index]
                    self.skills[index] = SkillItem(
                        id: old.id,
                        name: old.name,
                        description: old.description,
                        content: old.content,
                        isActive: isActive,
                        updatedAt: old.updatedAt
                    )
                }
            }
        }.resume()
    }

    private func deleteSkills(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        let skill = skills[index]
        deleteSkill(id: skill.id) { success in
            if success {
                DispatchQueue.main.async {
                    self.skills.remove(atOffsets: offsets)
                }
            }
        }
    }

    private func deleteSkill(id: String, completion: @escaping (Bool) -> Void) {
        guard let token = authManager.token else {
            completion(false)
            return
        }
        guard let url = URL(string: "http://localhost:3000/api/user/skills/\(id)") else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = ErrorLocalizer.message(from: error, fallback: "删除技能失败，请稍后重试。")
                }
                completion(false)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                DispatchQueue.main.async {
                    self.errorMessage = ErrorLocalizer.message(
                        statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1,
                        serverMessage: ErrorLocalizer.extractServerMessage(from: data),
                        fallback: "删除技能失败，请稍后重试。"
                    )
                }
                completion(false)
                return
            }

            completion(true)
        }.resume()
    }
}

#Preview {
    NavigationView {
        SkillsView()
    }
}
