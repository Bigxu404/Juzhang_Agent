const modelAliasMap: Record<string, string> = {
  'minimax-2.7': 'MiniMax-M2.7',
  'MiniMax-2.7': 'MiniMax-M2.7',
  'minimax-m2.7': 'MiniMax-M2.7',
  'minimax-2.7-highspeed': 'MiniMax-M2.7-highspeed',
  'MiniMax-2.7-highspeed': 'MiniMax-M2.7-highspeed',
  'minimax-2.5': 'MiniMax-M2.5',
  'MiniMax-2.5': 'MiniMax-M2.5',
  'minimax-2.5-highspeed': 'MiniMax-M2.5-highspeed',
  'MiniMax-2.5-highspeed': 'MiniMax-M2.5-highspeed',
  'minimax-2.1': 'MiniMax-M2.1',
  'MiniMax-2.1': 'MiniMax-M2.1',
  'minimax-2.1-highspeed': 'MiniMax-M2.1-highspeed',
  'MiniMax-2.1-highspeed': 'MiniMax-M2.1-highspeed',
  'minimax-m2': 'MiniMax-M2'
};

export function normalizeModelName(raw?: string | null): string | undefined {
  if (!raw) return undefined;
  const trimmed = raw.trim();
  if (!trimmed) return undefined;
  return modelAliasMap[trimmed] || trimmed;
}
