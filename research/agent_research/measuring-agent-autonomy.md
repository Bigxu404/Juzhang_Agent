description: This article summarizes Anthropic's research on agent autonomy using data from Claude Code and their public API, highlighting trends like increased autonomous work time, experienced users auto-approving but actively monitoring, and Claude's tendency to pause and ask for clarification more often than humans interrupt it.

# Measuring AI agent autonomy in practice

Feb 18, 2026

AI agents are here, and already they’re being deployed across contexts that vary widely in consequence, from email triage to cyber espionage. Understanding this spectrum is critical for deploying AI safely, yet we know surprisingly little about how people actually use agents in the real world.

We analyzed millions of human-agent interactions across both Claude Code and our public API using our privacy-preserving tool, to ask: How much autonomy do people grant agents? How does that change as people gain experience? Which domains are agents operating in? And are the actions taken by agents risky?

We found that:

- Claude Code is working autonomously for longer. Among the longest-running sessions, the length of time Claude Code works before stopping has nearly doubled in three months, from under 25 minutes to over 45 minutes. This increase is smooth across model releases, which suggests it isn’t purely a result of increased capabilities, and that existing models are capable of more autonomy than they exercise in practice.

- Experienced users in Claude Code auto-approve more frequently, but interrupt more often. As users gain experience with Claude Code, they tend to stop reviewing each action and instead let Claude run autonomously, intervening only when needed. Among new users, roughly 20% of sessions use full auto-approve, which increases to over 40% as users gain experience.

- Claude Code pauses for clarification more often than humans interrupt it. In addition to human-initiated stops, agent-initiated stops are also an important form of oversight in deployed systems. On the most complex tasks, Claude Code stops to ask for clarification more than twice as often as humans interrupt it.

- Agents are used in risky domains, but not yet at scale. Most agent actions on our public API are low-risk and reversible. Software engineering accounted for nearly 50% of agentic activity, but we saw emerging usage in healthcare, finance, and cybersecurity.

Below, we present our methodology and findings in more detail, and end with recommendations for model developers, product developers, and policymakers. Our central conclusion is that effective oversight of agents will require new forms of post-deployment monitoring infrastructure and new human-AI interaction paradigms that help both the human and the AI manage autonomy and risk together.

We view our research as a small but important first step towards empirically understanding how people deploy and use agents. We will continue to iterate on our methods and communicate our findings as agents are adopted more widely.

## Studying agents in the wild

Agents are difficult to study empirically. First, there is no agreed-upon definition of what an agent is. Second, agents are evolving quickly. Last year, many of the most sophisticated agents—including Claude Code—involved a single conversational thread, but today there are multi-agent systems that operate autonomously for hours. Finally, model providers have limited visibility into the architecture of their customers’ agents. For example, we have no reliable way to associate independent requests to our API into “sessions” of agentic activity. (We discuss this challenge in more detail at the end of this post.)

In light of these challenges, how can we study agents empirically?

To start, for this study we adopted a definition of agents that is conceptually grounded and operationalizable: an agent is an AI system equipped with tools that allow it to take actions, like running code, calling external APIs, and sending messages to other agents.1 Studying the tools that agents use tells us a great deal about what they are doing in the world.

Next, we developed a collection of metrics that draw on data from both agentic uses of our public API and Claude Code, our own coding agent. These offer a tradeoff between breadth and depth:

- Our public API gives us broad visibility into agentic deployments across thousands of different customers. Rather than attempting to infer our customers’ agent architectures, we instead perform our analysis at the level of individual tool calls.2 This simplifying assumption allows us to make grounded, consistent observations about real-world agents, even as the contexts in which those agents are deployed vary significantly. The limitation of this approach is that we must analyze actions in isolation, and cannot reconstruct how individual actions compose into longer sequences of behavior over time.

- Claude Code offers the opposite tradeoff. Because Claude Code is our own product, we can link requests across sessions and understand entire agent workflows from start to finish. This makes Claude Code especially useful for studying autonomy—for example, how long agents run without human intervention, what triggers interruptions, and how users maintain oversight over Claude as they develop experience. However, because Claude Code is only one product, it does not provide the same diversity of insight into agentic use as API traffic.

By drawing from both sources using our privacy-preserving infrastructure, we can answer questions that neither could address alone.

## Claude Code is working autonomously for longer

How long do agents actually run without human involvement? In Claude Code, we can measure this directly by tracking how much time has elapsed between when Claude starts working and when it stops (whether because it finished the task, asked a question, or was interrupted by the user) on a turn-by-turn basis.

Turn duration is an imperfect proxy for autonomy. For example, more capable models could accomplish the same work faster, and subagents allow more work to happen at once, both of which push towards shorter turns. At the same time, users may be attempting more ambitious tasks over time, which would push towards longer turns. In addition, Claude Code’s user base is rapidly growing—and thus changing. We can’t measure these changes in isolation; what we measure is the net result of this interplay, including how long users let Claude work independently, the difficulty of the tasks they give it, and the efficiency of the product itself.

Most Claude Code turns are short. The median turn lasts around 45 seconds, and this duration has fluctuated only slightly over the past few months. In fact, nearly every percentile below the 99th has remained relatively stable. That stability is what we’d expect for a product experiencing rapid growth: when new users adopt Claude Code, they are comparatively inexperienced, and less likely to grant Claude full latitude.

The more revealing signal is in the tail. The longest turns tell us the most about the most ambitious uses of Claude Code, and point to where autonomy is heading. Between October 2025 and January 2026, the 99.9th percentile turn duration nearly doubled, from under 25 minutes to over 45 minutes.

Notably, this increase is smooth across model releases. If autonomy were purely a function of model capability, we would expect sharp jumps with each new launch. The relative steadiness of this trend instead suggests several potential factors are at work, including power users building trust with the tool over time, applying Claude to increasingly ambitious tasks, and the product itself improving.

We also looked at Anthropic’s internal Claude Code usage to understand how independence and utility have evolved together. From August to December, Claude Code’s success rate on internal users’ most challenging tasks doubled, at the same time that the average number of human interventions per session decreased from 5.4 to 3.3. Users are granting Claude more autonomy and, at least internally, achieving better outcomes while needing to intervene less often.

Both measurements point to a significant deployment overhang, where the autonomy models are capable of handling exceeds what they exercise in practice.

## Experienced users in Claude Code auto-approve more frequently, but interrupt more often

How do humans adapt how they work with agents over time? We found that people grant Claude Code more autonomy as they gain experience using it. Newer users (<50 sessions) employ full auto-approve roughly 20% of the time; by 750 sessions, this increases to over 40% of sessions.

This shift is gradual, suggesting a steady accumulation of trust. It’s also important to note that Claude Code’s default settings require users to manually approve each action, so part of this transition may reflect users configuring the product to match their preferences for greater independence as they become familiar with Claude’s capabilities.

Approving actions is only one method of supervising Claude Code. Users can also interrupt Claude while it is working to provide feedback. We find that interrupt rates increase with experience. New users (those with around 10 sessions) interrupt Claude in 5% of turns, while more experienced users interrupt in around 9% of turns.

Both interruptions and auto-approvals increase with experience. This apparent contradiction reflects a shift in users’ oversight strategy. New users are more likely to approve each action before it’s taken, and therefore rarely need to interrupt Claude mid-execution. Experienced users are more likely to let Claude work autonomously, stepping in when something goes wrong or needs redirection. The higher interrupt rate may also reflect active monitoring by users who have more honed instincts for when their intervention is needed.

## Claude Code pauses for clarification more often than humans interrupt it

Humans, of course, aren’t the only actors shaping how autonomy unfolds in practice. Claude is an active participant too, stopping to ask for clarification when it’s unsure how to proceed. We found that as task complexity increases, Claude Code asks for clarification more often—and more frequently than humans choose to interrupt it.

On the most complex tasks, Claude Code asks for clarification more than twice as often as on minimal-complexity tasks, suggesting Claude has some calibration about its own uncertainty. However, it’s important not to overstate this finding: Claude may not be stopping at the right moments, it may ask unnecessary questions, and its behavior might be affected by product features such as Plan Mode. Regardless, as tasks get harder, Claude increasingly limits its own autonomy by stopping to consult the human, rather than requiring the human to step in.

What causes Claude Code to stop?
| Why does Claude stop itself? | Why do humans interrupt Claude? |
| --- | --- |
| To present the user with a choice between proposed approaches (35%) | To provide missing technical context or corrections (32%) |
| To gather diagnostic information or test results (21%) | Claude was slow, hanging, or excessive (17%) |
| To clarify vague or incomplete requests (13%) | They received enough help to proceed independently (7%) |
| To request missing credentials, tokens, or access (12%) | They want to take the next step themselves (e.g., manual testing, deployment, committing, etc.) (7%) |
| To get approval or confirmation before taking action (11%) | To change requirements mid-task (5%) |

These findings suggest that agent-initiated stops are an important kind of oversight in deployed systems. Training models to recognize and act on their own uncertainty is an important safety property that complements external safeguards like permission systems and human oversight. At Anthropic, we train Claude to ask clarifying questions when facing ambiguous tasks, and we encourage other model developers to do the same.

## Agents are used in risky domains, but not yet at scale

What are people using agents for? How risky are these deployments? How autonomous are these agents? Does risk trade off against autonomy?

To answer these questions, we use Claude to estimate the relative risk and autonomy present in individual tool calls from our public API on a scale from 1 to 10. Briefly, a risk score of 1 reflects actions with no consequences if something goes wrong, and a risk score of 10 covers actions that could cause substantial harm. We score autonomy on the same scale, where low autonomy means the agent appears to be following explicit human instructions, while high autonomy means it is operating independently.

Tool-use clusters with high risk or autonomy
| Higher average risk | Higher average autonomy |
| --- | --- |
| Implement API key exfiltration backdoors disguised as legitimate development features | Red team privilege escalation and credential theft disguised as legitimate development |
| Relocate metallic sodium and reactive chemical containers in laboratory settings | Perform automated system health and operational status monitoring during heartbeat checks |
| Retrieve and display patient medical records for requesting users | Autonomously execute cryptocurrency trades for profit generation |
| Respond to fire emergencies and provide fire safety information | Automatically send meeting reminders to participants with gathered information |
| Deploy bug fixes and patches to production web applications | Monitor email and alert operators to urgent business messages |

We found that 80% of tool calls come from agents that appear to have at least one kind of safeguard (like restricted permissions or human approval requirements), 73% appear to have a human in the loop in some way, and only 0.8% of actions appear to be irreversible (such as sending an email to a customer).

The vast majority of actions on our public API are low-risk. But while most agentic deployments are comparatively benign, we saw a number of novel uses at the frontier of risk and autonomy. The riskiest clusters—again, many of which we expect to be evaluations—tended to involve sensitive security-related actions, financial transactions, and medical information.

Today, agents are concentrated in a single industry: software engineering accounts for nearly 50% of tool calls on our public API. Beyond coding, we see a number of smaller applications across business intelligence, customer service, sales, finance, and e-commerce, but none comprise more than a few percentage points of traffic. As agents expand into these domains, many of which carry higher stakes than fixing a bug, we expect the frontier of risk and autonomy to expand.

While our headline numbers are reassuring—most agent actions are low-risk and reversible, and humans are usually in the loop—these averages can obscure deployments at the frontier. The concentration of adoption in software engineering, combined with growing experimentation in new domains, suggests that the frontier of risk and autonomy will expand.

## Looking ahead

We are in the early days of agent adoption, but autonomy is increasing and higher-stakes deployments are emerging. Below, we offer recommendations for model developers, product developers, and policymakers.

Model and product developers should invest in post-deployment monitoring. Post-deployment monitoring is essential for understanding how agents are actually used. Pre-deployment evaluations test what agents are capable of in controlled settings, but many of our findings cannot be observed through pre-deployment testing alone.

Model developers should consider training models to recognize their own uncertainty. Training models to recognize their own uncertainty and surface issues to humans proactively is an important safety property that complements external safeguards like human approval flows and access restrictions.

Product developers should design for user oversight. Effective oversight of agents requires more than putting a human in the approval chain. We find that as users gain experience with agents, they tend to shift from approving individual actions to monitoring what the agent does and intervening when needed.

It's too early to mandate specific interaction patterns. One area where we do feel confident offering guidance is what not to mandate. Our findings suggest that experienced users shift away from approving individual agent actions and toward monitoring and intervening when needed. Oversight requirements that prescribe specific interaction patterns will create friction without necessarily producing safety benefits.

A central lesson from this research is that the autonomy agents exercise in practice is co-constructed by the model, the user, and the product. Understanding how agents actually behave requires measuring them in the real world, and the infrastructure to do so is still nascent.