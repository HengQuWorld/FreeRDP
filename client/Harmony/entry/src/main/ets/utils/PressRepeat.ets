const NO_TIMER: number = -1;

/**
 * Turns one press into an immediate step plus a steady repeat for as long as
 * the press is held. Call start() on touch down and stop() on up or cancel.
 *
 * The first step happens before any timer, so a press never waits for the
 * repeat delay to have an effect.
 */
export class PressRepeat {
  private delayMs: number;
  private intervalMs: number;
  private delayTimer: number = NO_TIMER;
  private repeatTimer: number = NO_TIMER;

  constructor(delayMs: number, intervalMs: number) {
    this.delayMs = delayMs;
    this.intervalMs = intervalMs;
  }

  isRunning(): boolean {
    return this.delayTimer !== NO_TIMER || this.repeatTimer !== NO_TIMER;
  }

  start(step: () => void): void {
    this.stop();
    step();
    this.delayTimer = setTimeout(() => {
      this.delayTimer = NO_TIMER;
      this.repeatTimer = setInterval(() => {
        step();
      }, this.intervalMs);
    }, this.delayMs);
  }

  stop(): void {
    if (this.delayTimer !== NO_TIMER) {
      clearTimeout(this.delayTimer);
      this.delayTimer = NO_TIMER;
    }
    if (this.repeatTimer !== NO_TIMER) {
      clearInterval(this.repeatTimer);
      this.repeatTimer = NO_TIMER;
    }
  }
}
