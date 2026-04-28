export class Mutex {
  private queue: Array<() => void> = [];
  private locked = false;

  async acquire(): Promise<() => void> {
    return new Promise((resolve) => {
      const lock = () => {
        this.locked = true;
        resolve(() => this.release());
      };

      if (!this.locked) {
        lock();
      } else {
        this.queue.push(lock);
      }
    });
  }

  private release() {
    this.locked = false;
    const next = this.queue.shift();
    if (next) {
      next();
    }
  }
}

export class MutexManager {
  private mutexes: Map<string, Mutex> = new Map();

  async runExclusive<T>(key: string, task: () => Promise<T>): Promise<T> {
    if (!this.mutexes.has(key)) {
      this.mutexes.set(key, new Mutex());
    }
    const mutex = this.mutexes.get(key)!;
    const release = await mutex.acquire();
    
    try {
      return await task();
    } finally {
      release();
      // Clean up empty mutexes to prevent memory leak
      // We check private 'queue' length by casting
      if ((mutex as any).queue.length === 0) {
        this.mutexes.delete(key);
      }
    }
  }
}

export const sessionMutex = new MutexManager();
