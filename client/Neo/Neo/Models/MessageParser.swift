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
            
            if let tr = thinkRange, let toR = toolRange {
                if tr.lowerBound < toR.lowerBound {
                    nextTagStart = tr.lowerBound
                    isThink = true
                } else {
                    nextTagStart = toR.lowerBound
                    isThink = false
                }
            } else if let tr = thinkRange {
                nextTagStart = tr.lowerBound
                isThink = true
            } else if let toR = toolRange {
                nextTagStart = toR.lowerBound
                isThink = false
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
        
        return components
    }
}
