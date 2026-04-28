description: 剖析一个经典的Feature Gate工业级实现，涵盖从编译时到运行时的三层认证功能门控控制。

## 第十章：语音模式——完美的feature gate示例 ​

bash

```
cat voice/voiceModeEnabled.ts
```

55行代码展示了三层feature gate的工业级实现：

typescript

```
// 第1层：编译时——功能关闭则代码不存在
export function isVoiceGrowthBookEnabled(): boolean {
  return feature('VOICE_MODE')
    ? !getFeatureValue_CACHED_MAY_BE_STALE(
        'tengu_amber_quartz_disabled', false
      )
    : false
}

// 第2层：认证——必须是Anthropic OAuth（不是API Key）
export function hasVoiceAuth(): boolean {
  if (!isAnthropicAuthEnabled()) return false
  const tokens = getClaudeAIOAuthTokens()
  return Boolean(tokens?.accessToken)
}

// 第3层：完整运行时检查
export function isVoiceModeEnabled(): boolean {
  return hasVoiceAuth() && isVoiceGrowthBookEnabled()
}
```

注释中的设计考量（原文）：

> "Kill-switch check... Default `false` means a missing/stale disk cache reads as 'not killed' — so fresh installs get voice working immediately without waiting for GrowthBook init."

翻译：默认值设计为"不关闭"——新安装的用户不需要等GrowthBook初始化就能用语音。紧急情况才把开关翻为true来关闭功能。

---