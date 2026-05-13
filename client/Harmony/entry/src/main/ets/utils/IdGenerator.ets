export class IdGenerator {
  private static nextValue: number = 1;
  private static readonly sessionId: string = Date.now().toString(36);

  static next(prefix: string): string {
    const value: number = IdGenerator.nextValue;
    IdGenerator.nextValue = IdGenerator.nextValue + 1;
    return `${prefix}-${IdGenerator.sessionId}-${value}`;
  }
}
