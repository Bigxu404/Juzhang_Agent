/**
 * Explore Subagent (冲浪专属只读沙箱)
 *
 * 优化 2: 结合 CC 的思想进行重构。
 * 1. 移除沉重的主 Agent 人设 (omitClaudeMd 思想)，避免Token浪费。
 * 2. 只暴露 Read-only 的工具。
 * 3. 强调速度和效率，应该用最快的模型（如Haiku/Flash）。
 */

import OpenAI from 'openai';
import axios from 'axios';
import * as cheerio from 'cheerio';
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
      const toolCallMessage = { ...choice.message };
      if (!toolCallMessage.content) {
        toolCallMessage.content = "";
      }
      messages.push(toolCallMessage as any);

      // 遍历所有的 tool_calls，逐个执行并返回结果
      for (const tc of choice.message.tool_calls) {
        const args = JSON.parse((tc as any).function.arguments);
        console.log(`[Explore Agent] Calling WebSearch with query: ${args.query}`);
        
        let searchResult = "";
        const tavilyApiKey = process.env.TAVILY_API_KEY;
        
        if (tavilyApiKey && tavilyApiKey.trim() !== '') {
            try {
                console.log(`[Explore Agent] Using Tavily Search API for: ${args.query}`);
                const response = await axios.post('https://api.tavily.com/search', {
                    api_key: tavilyApiKey,
                    query: args.query,
                    search_depth: "advanced",
                    include_answer: false,
                    include_raw_content: false,
                    max_results: 5
                }, { timeout: 15000 });
                
                if (response.data && response.data.results) {
                    let extractedTexts: string[] = [];
                    for (const res of response.data.results) {
                        extractedTexts.push(`Title: ${res.title}\nContent: ${res.content}\nURL: ${res.url}`);
                    }
                    if (extractedTexts.length > 0) {
                        searchResult = `[Tavily Search Results] for "${args.query}":\n\n${extractedTexts.join('\n\n')}`;
                        console.log(`[Explore Agent] Successfully fetched from Tavily.`);
                    }
                }
            } catch (err: any) {
                console.error(`[Explore Agent] Tavily Search failed: ${err.message}`);
            }
        }
        
        // 兜底方案：如果没配置 Tavily Key 或者 Tavily 挂了，降级到国内免墙的必应抓取
        if (!searchResult) {
            console.log(`[Explore Agent] Using Bing fallback search...`);
            try {
                const bingUrl = `https://cn.bing.com/search?q=${encodeURIComponent(args.query)}`;
                const response = await axios.get(bingUrl, {
                   headers: {
                     'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
                   },
                   timeout: 8000 
                });
                
                if (response.data) {
                     const $ = cheerio.load(response.data);
                     let extractedTexts: string[] = [];
                     $('.b_algo').each((i, elem) => {
                         if (i >= 5) return;
                         const title = $(elem).find('h2').text().trim();
                         const snippet = $(elem).find('.b_caption p').text().trim() || $(elem).find('.b_algoSlug').text().trim() || $(elem).text().trim();
                         if (title && snippet) {
                             extractedTexts.push(`Title: ${title}\nSnippet: ${snippet}`);
                         }
                     });
                     
                     const textOnly = extractedTexts.join('\n\n');
                     if (textOnly) {
                         searchResult = `[Bing Search Results] for "${args.query}":\n\n${textOnly}`;
                     } else {
                         const bodyText = $('body').text().replace(/\s+/g, ' ').substring(0, 3000);
                         searchResult = `[Bing Search Results] for "${args.query}":\n\n${bodyText}`;
                     }
                }
            } catch (bingErr: any) {
                console.log(`[Explore Agent] Bing fallback failed: ${bingErr.message}`);
            }
        }
        
        if (!searchResult) {
            searchResult = `Search Results for "${args.query}":\nNo abstract found. Network timeout or all public instances failed.`;
        }

        messages.push({
          role: 'tool',
          tool_call_id: tc.id,
          content: searchResult
        } as any);
      }

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
