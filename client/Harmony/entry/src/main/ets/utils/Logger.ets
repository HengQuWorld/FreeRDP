export enum LogLevel {
  Debug = 0,
  Info = 1,
  Warn = 2,
  Error = 3
}

export interface LogTagsType {
  SESSION_MANAGER: string;
  SESSION_BACKEND: string;
  SESSION_BRIDGE: string;
  SESSION_VIEWMODEL: string;
  HOME_VIEWMODEL: string;
  CONNECTION_FORM: string;
  AUTH_DIALOG: string;
  CERT_DIALOG: string;
  ENTRY_ABILITY: string;
  SESSION_ABILITY: string;
  BOOKMARK_SERVICE: string;
  KEYBOARD_HELPER: string;
}

export class Logger {
  private static instance: Logger | null = null;
  private minLevel: LogLevel = LogLevel.Debug;
  private enableConsole: boolean = true;

  private constructor() {}

  static getInstance(): Logger {
    if (Logger.instance === null) {
      Logger.instance = new Logger();
    }
    return Logger.instance;
  }

  setMinLevel(level: LogLevel): void {
    this.minLevel = level;
  }

  setEnableConsole(enable: boolean): void {
    this.enableConsole = enable;
  }

  private formatMessage(level: string, tag: string, message: string): string {
    const timestamp: string = new Date().toISOString();
    return `[${timestamp}] [${level}] [${tag}] ${message}`;
  }

  private shouldLog(level: LogLevel): boolean {
    return level >= this.minLevel && this.enableConsole;
  }

  debug(tag: string, message: string, ...args: string[]): void {
    if (this.shouldLog(LogLevel.Debug)) {
      const formatted: string = this.formatMessage('DEBUG', tag, message);
      console.debug(formatted, ...args);
    }
  }

  info(tag: string, message: string, ...args: string[]): void {
    if (this.shouldLog(LogLevel.Info)) {
      const formatted: string = this.formatMessage('INFO', tag, message);
      console.info(formatted, ...args);
    }
  }

  warn(tag: string, message: string, ...args: string[]): void {
    if (this.shouldLog(LogLevel.Warn)) {
      const formatted: string = this.formatMessage('WARN', tag, message);
      console.warn(formatted, ...args);
    }
  }

  error(tag: string, message: string, error?: Error | string | Object): void {
    if (this.shouldLog(LogLevel.Error)) {
      const formatted: string = this.formatMessage('ERROR', tag, message);
      if (error !== undefined) {
        const errorMessage: string = error instanceof Error
          ? `${error.name}: ${error.message}\nStack: ${error.stack ?? 'N/A'}`
          : String(error);
        console.error(`${formatted} - ${errorMessage}`);
      } else {
        console.error(formatted);
      }
    }
  }

  logException(tag: string, operation: string, error: Error | string | Object): string {
    const errorMessage: string = error instanceof Error
      ? error.message
      : String(error);
    this.error(tag, `${operation} failed`, error);
    return errorMessage;
  }
}

export const logger: Logger = Logger.getInstance();

export const LogTags: LogTagsType = {
  SESSION_MANAGER: 'SessionManager',
  SESSION_BACKEND: 'SessionBackend',
  SESSION_BRIDGE: 'SessionBridge',
  SESSION_VIEWMODEL: 'SessionViewModel',
  HOME_VIEWMODEL: 'HomeViewModel',
  CONNECTION_FORM: 'ConnectionForm',
  AUTH_DIALOG: 'AuthDialog',
  CERT_DIALOG: 'CertDialog',
  ENTRY_ABILITY: 'EntryAbility',
  SESSION_ABILITY: 'SessionAbility',
  BOOKMARK_SERVICE: 'BookmarkService',
  KEYBOARD_HELPER: 'KeyboardHelper'
};
