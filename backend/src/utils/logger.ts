import { randomUUID } from 'crypto';

export interface LogPayload {
  [key: string]: any;
}

export class Logger {
  private static instance: Logger;

  private constructor() {}

  static getInstance(): Logger {
    if (!Logger.instance) {
      Logger.instance = new Logger();
    }
    return Logger.instance;
  }

  createTrace(sessionId: string, userId: string, query: string): Trace {
    const traceId = randomUUID();
    this.info('TRACE_START', { traceId, sessionId, userId, query });
    return new Trace(traceId, sessionId);
  }

  log(level: 'INFO' | 'WARN' | 'ERROR', event: string, payload?: LogPayload) {
    const entry = {
      timestamp: new Date().toISOString(),
      level,
      event,
      ...payload
    };
    console.log(JSON.stringify(entry));
  }

  info(event: string, payload?: LogPayload) {
    this.log('INFO', event, payload);
  }

  warn(event: string, payload?: LogPayload) {
    this.log('WARN', event, payload);
  }

  error(event: string, payload?: LogPayload) {
    this.log('ERROR', event, payload);
  }
}

export class Trace {
  constructor(public readonly traceId: string, public readonly sessionId: string) {}

  startSpan(name: string, payload?: LogPayload): Span {
    return new Span(this.traceId, this.sessionId, name, payload);
  }

  end(payload?: LogPayload) {
    Logger.getInstance().info('TRACE_END', { traceId: this.traceId, sessionId: this.sessionId, ...payload });
  }
}

export class Span {
  public readonly spanId: string;
  private startTime: number;

  constructor(
    public readonly traceId: string,
    public readonly sessionId: string,
    public readonly name: string,
    payload?: LogPayload
  ) {
    this.spanId = randomUUID();
    this.startTime = Date.now();
    Logger.getInstance().info('SPAN_START', { traceId, spanId: this.spanId, name, ...payload });
  }

  end(payload?: LogPayload) {
    const durationMs = Date.now() - this.startTime;
    Logger.getInstance().info('SPAN_END', { traceId: this.traceId, spanId: this.spanId, name: this.name, durationMs, ...payload });
  }
}

export const logger = Logger.getInstance();
