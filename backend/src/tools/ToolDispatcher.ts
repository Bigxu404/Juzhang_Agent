import { Tool, AgentContext, PermissionLevel } from '../types';
import { AgentState } from '../websocket/AgentState';

export class ToolDispatcher {
  private tools: Map<string, Tool> = new Map();
  private consecutiveDenials = 0;
  private maxDenials = 3;

  register(tool: Tool) {
    this.tools.set(tool.name, tool);
  }

  getAvailableTools() {
    return Array.from(this.tools.values()).map(t => ({
      name: t.name,
      description: t.description,
      input_schema: t.schema
    }));
  }

  async dispatch(name: string, input: any, ctx: AgentContext): Promise<string> {
    const tool = this.tools.get(name);
    if (!tool) {
      return JSON.stringify({ error: `Tool ${name} not found.` });
    }

    const toolSpan = ctx.trace?.startSpan('tool_execution', { name, input });

    ctx.sendEvent({ type: 'tool_start', toolName: name, input });
    ctx.sendState(AgentState.WORKING, `准备调用工具 ${name}...`);

    // Level 3 Harness: Permission Interceptor
    if (tool.permissionLevel === PermissionLevel.REQUIRE_APPROVAL) {
      ctx.sendState(AgentState.WAITING_PERMISSION, `等待授权执行 ${name}...`);
      const approved = await ctx.requestPermission(name, tool.description);
      if (!approved) {
        this.consecutiveDenials++;
        if (this.consecutiveDenials >= this.maxDenials) {
          throw new Error('DENIAL_LIMIT_REACHED');
        }
        return JSON.stringify({ error: "用户拒绝了该操作。" });
      }
      // Reset denial counter on success
      this.consecutiveDenials = 0;
    }

    try {
      ctx.sendState(AgentState.WORKING, `正在执行工具 ${name}...`);
      const result = await tool.execute(input, ctx);
      
      // Level 2 Harness: Notify after
      if (tool.permissionLevel === PermissionLevel.NOTIFY_AFTER) {
        ctx.sendChunk(`\n(系统通知: 已经执行了 ${name} 操作)\n`);
      }
      
      toolSpan?.end({ success: true, resultLength: JSON.stringify(result).length });
      ctx.sendEvent({ type: 'tool_end', toolName: name, result });
      return JSON.stringify(result);
    } catch (err: any) {
      toolSpan?.end({ success: false, error: err.message });
      ctx.sendEvent({ type: 'error', message: err.message });
      
      // 添加 Hint 侧通道
      let hint = "";
      const errMsg = err.message.toLowerCase();
      if (errMsg.includes('enoent') || errMsg.includes('no such file') || errMsg.includes('not found')) {
        hint = "Hint: 文件或目录不存在。请先调用 mcp_list_directory 或 mcp_search_files 工具确认真实的路径和文件名，不要凭空猜测。";
      } else if (errMsg.includes('timeout') || errMsg.includes('timed out')) {
        hint = "Hint: 网络请求超时。可能是目标服务不稳定或由于网络环境限制。你可以尝试重试，或者换一种方式完成任务。";
      } else if (errMsg.includes('permission denied') || errMsg.includes('eacces')) {
        hint = "Hint: 权限被拒绝。你可能没有权限操作该文件或目录。";
      } else if (errMsg.includes('is a directory') || errMsg.includes('eisdir')) {
        hint = "Hint: 目标是一个目录，但你尝试像操作文件一样操作它。";
      } else if (errMsg.includes('invalid') || errMsg.includes('parse error')) {
        hint = "Hint: 参数格式错误或无效。请仔细检查你传递给工具的参数是否符合 schema 要求。";
      }

      const errorResult: any = { error: err.message };
      if (hint) {
        errorResult.hint = hint;
      }
      
      return JSON.stringify(errorResult);
    }
  }
}
