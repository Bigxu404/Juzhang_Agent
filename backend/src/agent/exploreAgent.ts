/**
 * Explore Subagent (冲浪专属只读沙箱)
 *
 * 优化 2: 结合 CC 的思想进行重构。
 * 1. 移除沉重的主 Agent 人设 (omitClaudeMd 思想)，避免Token浪费。
 * 2. 只暴露 Read-only 的工具。
 * 3. 强调速度和效率，应该用最快的模型（如Haiku/Flash）。
 */

import OpenAI from 'openai';
import { search } from 'duck-duck-scrape';
import fs from 'fs';
import path from 'path';

import { AgentContext } from '../types';
import { normalizeModelName } from '../utils/modelName';

export async function runExploreAgent(task: string, ctx?: AgentContext): Promise<string> {
  const userApiKey = ctx?.apiKey;
  
  if (!userApiKey || userApiKey.trim() === '') {
    console.log("[Explore Agent] No API key found, aborting.");
    return `(系统提示：未配置 API Key，探索任务中止。请前往设置配置。)`;
  }

  const openai = new OpenAI({
    apiKey: userApiKey,
    baseURL: 'https://api.minimax.chat/v1'
  });
  // 读取系统级技能 (Information Distillation)
  let skillPrompt = "";
  try {
    const skillPath = path.join(__dirname, '../skills/system/Information_Distillation.md');
    skillPrompt = fs.readFileSync(skillPath, 'utf8');
  } catch (e) {
    console.warn('[Explore Agent] Could not load Information Distillation skill.');
  }

  const EXPLORE_SYSTEM_PROMPT = `
  CRITICAL: READ-ONLY MODE
  You are a fast explorer agent. You must search the web or fetch pages to gather info.
  You are strictly prohibited from writing or editing anything.
  Make efficient use of your tools and return a highly distilled summary.
  
  <Skill: Information Distillation>
  ${skillPrompt}
  </Skill>
  `.trim();
  
  console.log(`[Explore Agent] Started sandbox with task: ${task}`);
  
  // 移除 Mock 逻辑
  // if (!userApiKey || userApiKey === 'dummy') {
  //   console.log("[Explore Agent] No API key found, running mock.");
  //   await new Promise(r => setTimeout(r, 2000));
  //   return `(Explore Subagent 抓取摘要) 全网关于“${task}”的最新信息如下：内容翔实，适合消费或记录。`;
  // }

  // 模拟 WebSearch 工具
  const tools = [
    {
      type: 'function',
      function: {
        name: 'WebSearch',
        description: 'Search the web for information',
        parameters: {
          type: 'object',
          properties: {
            query: { type: 'string' }
          },
          required: ['query']
        }
      }
    }
  ];

  const messages = [
    { role: 'system', content: EXPLORE_SYSTEM_PROMPT },
    { role: 'user', content: `Task: ${task}` }
  ];

  try {
    const modelName = normalizeModelName(ctx?.modelName) || normalizeModelName(process.env.MODEL_NAME) || 'MiniMax-M2.7';
    const response = await openai.chat.completions.create({
        model: modelName,
        messages: messages as any,
        tools: tools as any,
    });

    const choice = response.choices[0];
    
    if (choice.message.tool_calls && choice.message.tool_calls.length > 0) {
      const tc = choice.message.tool_calls[0] as any;
      const args = JSON.parse(tc.function.arguments);
      console.log(`[Explore Agent] Calling WebSearch with query: ${args.query}`);
      
      // 真实调用 DuckDuckGo 搜索
      let searchResult = "";
      try {
        const searchResults = await search(args.query);
        const topResults = searchResults.results.slice(0, 4).map(r => `Title: ${r.title}\nSnippet: ${r.description}\nURL: ${r.url}`).join('\n\n');
        searchResult = `Search Results for "${args.query}":\n\n${topResults}`;
      } catch (err: any) {
        console.error(`[Explore Agent] WebSearch failed: ${err.message}`);
        searchResult = `Search failed: ${err.message}`;
      }
      
      messages.push(choice.message as any);
      messages.push({
        role: 'tool',
        tool_call_id: tc.id,
        content: searchResult
      } as any);

      const finalResponse = await openai.chat.completions.create({
          model: modelName,
          messages: messages as any,
      });

      return finalResponse.choices[0].message.content || "未获取到有效信息。";
    }

    return choice.message.content || "未获取到有效信息。";
  } catch (e: any) {
    console.error(`[Explore Agent] Error: ${e.message}`);
    return `(Explore Subagent 抓取失败) ${e.message}`;
  }
}
