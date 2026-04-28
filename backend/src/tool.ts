export enum PermissionLevel {
  AUTO_ALLOW = 1,      // 静默放行 (e.g. WebSearch, Fetch)
  NOTIFY_AFTER = 2,    // 事后通知
  REQUIRE_APPROVAL = 3 // 强制拦截，必须经由客户端确认 (e.g. AppendNotion)
}

export interface ToolContext {
  sessionId: string;
  requestPermission?: (toolName: string, desc: string) => Promise<boolean>;
  log?: (msg: string) => void;
}

export interface Tool {
  name: string;
  description: string;
  inputSchema: any; // JSON schema
  permissionLevel: PermissionLevel;
  execute: (input: any, ctx: ToolContext) => Promise<string>;
}

export class ToolDispatcher {
  private tools: Map<string, Tool> = new Map();

  register(tool: Tool) {
    this.tools.set(tool.name, tool);
  }

  getTools(): Tool[] {
    return Array.from(this.tools.values());
  }

  async dispatch(name: string, input: any, ctx: ToolContext): Promise<string> {
    const tool = this.tools.get(name);
    if (!tool) {
      throw new Error(`Tool ${name} not found`);
    }

    ctx.log?.(`[ToolDispatcher] Attempting to execute ${name} (Level: ${tool.permissionLevel})`);

    // Level 3 Harness: 拦截审批
    if (tool.permissionLevel === PermissionLevel.REQUIRE_APPROVAL) {
      if (!ctx.requestPermission) {
        throw new Error(`Permission request handler not provided for level 3 tool: ${name}`);
      }
      ctx.log?.(`[Harness] Tool ${name} requires user approval. Suspending agent loop...`);
      const approved = await ctx.requestPermission(name, `Agent requested to execute ${name} with input: ${JSON.stringify(input)}`);
      
      if (!approved) {
        ctx.log?.(`[Harness] User denied execution of ${name}.`);
        return `Error: User denied permission to execute ${name}.`;
      }
      ctx.log?.(`[Harness] User approved execution of ${name}. Resuming...`);
    }

    try {
      const result = await tool.execute(input, ctx);
      
      // Level 2 Harness: 事后通知可以加在这里，或由 LLM 自己在回答中说明
      if (tool.permissionLevel === PermissionLevel.NOTIFY_AFTER) {
        ctx.log?.(`[Harness] Tool ${name} executed. (Notify After)`);
      }
      
      return result;
    } catch (e: any) {
      ctx.log?.(`[ToolDispatcher] Error executing ${name}: ${e.message}`);
      return `Error executing ${name}: ${e.message}`;
    }
  }
}
