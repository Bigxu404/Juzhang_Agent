import Foundation

class MessageParser {
    static func parse(_ content: String) -> [MessageComponent] {
        var components: [MessageComponent] = []
        var remaining = content
        
        while !remaining.isEmpty {
            let thinkRange = remaining.range(of: "<think>")
            let toolRange = remaining.range(of: "<tool>")
            
            var nextTagStart: String.Index? = nil
            var isThink = false
            var isFile = false
            
            let fileRange = remaining.range(of: "<file ")
            
            // 找出最先出现的标签
            let tags: [(range: Range<String.Index>, type: String)] = [
                (thinkRange, "think"),
                (toolRange, "tool"),
                (fileRange, "file")
            ].compactMap { $0.0 != nil ? ($0.0!, $0.1) : nil }
            
            if let firstTag = tags.min(by: { $0.range.lowerBound < $1.range.lowerBound }) {
                nextTagStart = firstTag.range.lowerBound
                isThink = firstTag.type == "think"
                isFile = firstTag.type == "file"
            }
            
            if let startIdx = nextTagStart {
                let beforeText = String(remaining[..<startIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !beforeText.isEmpty {
                    components.append(.text(beforeText))
                }
                
                if isThink {
                    let afterStart = remaining[thinkRange!.upperBound...]
                    if let endRange = afterStart.range(of: "</think>") {
                        let thinkingText = String(afterStart[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                        components.append(.thinking(content: thinkingText, isFinished: true))
                        remaining = String(afterStart[endRange.upperBound...])
                    } else {
                        let thinkingText = String(afterStart).trimmingCharacters(in: .whitespacesAndNewlines)
                        components.append(.thinking(content: thinkingText, isFinished: false))
                        remaining = ""
                    }
                } else if isFile {
                    let afterStart = remaining[startIdx...]
                    if let endRange = afterStart.range(of: "/>") {
                        let fileTag = String(afterStart[..<endRange.upperBound])
                        
                        var url = ""
                        var name = "附件"
                        
                        if let urlRange = fileTag.range(of: "url=\"") {
                            let urlStart = fileTag[urlRange.upperBound...]
                            if let urlEndRange = urlStart.range(of: "\"") {
                                url = String(urlStart[..<urlEndRange.lowerBound])
                            }
                        }
                        if let nameRange = fileTag.range(of: "name=\"") {
                            let nameStart = fileTag[nameRange.upperBound...]
                            if let nameEndRange = nameStart.range(of: "\"") {
                                name = String(nameStart[..<nameEndRange.lowerBound])
                            }
                        }
                        
                        components.append(.file(url: url, name: name))
                        remaining = String(afterStart[endRange.upperBound...])
                    } else {
                        // Tag not closed yet, treat as text
                        remaining = String(afterStart)
                        components.append(.text(remaining))
                        remaining = ""
                    }
                } else {
                    let afterStart = remaining[toolRange!.upperBound...]
                    if let endRange = afterStart.range(of: "</tool>") {
                        let toolDesc = String(afterStart[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                        let isSubagent = toolDesc.contains("ExploreAgent") || toolDesc.contains("探索代理") || toolDesc.contains("子代理")
                        components.append(.toolCall(name: isSubagent ? "Subagent" : "Tool", status: .success, description: toolDesc))
                        remaining = String(afterStart[endRange.upperBound...])
                    } else {
                        let toolDesc = String(afterStart).trimmingCharacters(in: .whitespacesAndNewlines)
                        let isSubagent = toolDesc.contains("ExploreAgent") || toolDesc.contains("探索代理") || toolDesc.contains("子代理")
                        components.append(.toolCall(name: isSubagent ? "Subagent" : "Tool", status: .running, description: toolDesc))
                        remaining = ""
                    }
                }
            } else {
                let text = remaining.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    components.append(.text(text))
                }
                remaining = ""
            }
        }
        
        if components.isEmpty {
            // 如果所有的内容都是空白的，默认仍然返回一个空的文本组件以保证气泡至少有一个可渲染的基础(例如展示 loading)
            components.append(.text(""))
        }
        
        // 合并连续的 toolCall 组件
        var coalesced: [MessageComponent] = []
        for comp in components {
            if case .toolCall(let name, let status, let desc) = comp {
                if let last = coalesced.last, case .toolCall(let lastName, let lastStatus, let lastDesc) = last {
                    let newName = lastName == name ? name : "多步执行"
                    let newStatus: ToolStatus = (status == .running || lastStatus == .running) ? .running : .success
                    let newDesc = lastDesc + "\n\n" + desc
                    coalesced[coalesced.count - 1] = .toolCall(name: newName, status: newStatus, description: newDesc)
                } else {
                    coalesced.append(comp)
                }
            } else {
                coalesced.append(comp)
            }
        }
        
        return coalesced
    }
}
