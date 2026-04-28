description: This article discusses the risk of prompt injections in browser-based agents and Anthropic's defense mechanisms, noting that while defenses are improving, a residual risk remains due to the massive attack surface of the web.

# Mitigating the risk of prompt injections in browser use

Anthropic Research

Prompt injections represent a major security challenge for browser-based AI agents, where attackers embed malicious instructions in webpage content to hijack agent behavior. Browser use amplifies this risk due to the vast attack surface (webpages, documents, advertisements) and the range of actions agents can take.

Claude Opus 4.5 demonstrates improved robustness to prompt injections compared to previous models. With new safeguards implemented in the Claude for Chrome extension, attack success rates have been substantially reduced, though a 1% attack success rate still represents meaningful risk. Prompt injection remains far from solved, especially as agents take more real-world actions.
