import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { ToolDispatcher } from '../ToolDispatcher';
import { PermissionLevel, Tool } from '../../types';

/**
 * Task 2.2.1: MCP Client 初始化
 * Task 2.2.2: 原子工具提取与注册
 */
export class McpClientManager {
    private client: Client | null = null;
    private transport: StdioClientTransport | null = null;

    constructor(private dispatcher: ToolDispatcher) {}

    public async connect(serverCommand: string, serverArgs: string[]) {
        try {
            console.log(`[MCP] Connecting to server: ${serverCommand} ${serverArgs.join(' ')}`);
            this.transport = new StdioClientTransport({
                command: serverCommand,
                args: serverArgs,
                env: process.env as any // 传递环境变量，如 NOTION_API_KEY
            });

            this.client = new Client({
                name: 'mobile-agent-client',
                version: '1.0.0'
            }, {
                capabilities: {}
            });

            await this.client.connect(this.transport);
            console.log('[MCP] Connected successfully.');

            await this.registerServerTools();
        } catch (error) {
            console.error('[MCP] Connection failed:', error);
            console.log('[MCP] Fallback: Using mock Notion tools instead.');
        }
    }

    private async registerServerTools() {
        if (!this.client) return;

        const toolsList = await this.client.listTools();
        console.log(`[MCP] Found ${toolsList.tools.length} tools from server.`);

        for (const mcpTool of toolsList.tools) {
            // Task 2.2.2: 将 MCP 暴露的工具过滤并注册到我们自己的 ToolDispatcher 中
            // 通过名字动态赋予安全级别：写入/追加类的给 LEVEL 3，读取类的给 LEVEL 1
            let permLevel = PermissionLevel.AUTO_ALLOW;
            const toolNameLower = mcpTool.name.toLowerCase();
            
            if (toolNameLower.includes('append') || toolNameLower.includes('write') || toolNameLower.includes('create') || toolNameLower.includes('update') || toolNameLower.includes('delete')) {
                permLevel = PermissionLevel.REQUIRE_APPROVAL; // 危险操作，强制拦截
            }

            const wrappedTool: Tool = {
                name: `mcp_${mcpTool.name}`, // 加前缀避免冲突
                description: `(MCP Tool) ${mcpTool.description || ''}`,
                schema: mcpTool.inputSchema,
                permissionLevel: permLevel,
                execute: async (input: any) => {
                    console.log(`[MCP] Executing tool ${mcpTool.name}...`);
                    const result = await this.client!.callTool({
                        name: mcpTool.name,
                        arguments: input
                    });
                    return JSON.stringify(result);
                }
            };

            this.dispatcher.register(wrappedTool);
            console.log(`[MCP] Registered wrapped tool: ${wrappedTool.name} (Level: ${permLevel})`);
        }
    }
    
    public async disconnect() {
        if (this.transport) {
            await this.transport.close();
            console.log('[MCP] Disconnected.');
        }
    }
}
