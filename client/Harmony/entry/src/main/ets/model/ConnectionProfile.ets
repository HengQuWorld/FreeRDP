export interface DriveRedirection {
  name: string;
  path: string;
}

/**
 * 从本地目录路径推导默认盘符名称，例如 "/storage/.../Documents" -> "Documents"。
 * 当用户只选择/输入了路径而没有填写盘符名时，用它兜底，避免条目因名称为空被丢弃。
 */
export function deriveDriveName(path: string): string {
  let trimmed: string = path.trim();
  while (trimmed.length > 1 && trimmed.endsWith('/')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  if (trimmed.length === 0) {
    return '';
  }
  const lastSlash: number = trimmed.lastIndexOf('/');
  const segment: string = lastSlash < 0 ? trimmed : trimmed.substring(lastSlash + 1);
  return segment.length > 0 ? segment : 'drive';
}

/**
 * 深拷贝重定向目录列表，并容忍旧数据中该字段缺失的情况。
 */
export function copyDriveRedirections(drives?: DriveRedirection[]): DriveRedirection[] {
  const result: DriveRedirection[] = [];
  if (drives === undefined || drives === null) {
    return result;
  }
  let index: number = 0;
  while (index < drives.length) {
    const item: DriveRedirection = drives[index];
    result.push({ name: item.name, path: item.path });
    index += 1;
  }
  return result;
}

/**
 * 规整重定向目录列表：去掉路径为空的条目，并为名称为空的条目按路径推导名称。
 * 持久化与下发原生层之前统一调用，保证"界面上看到的条目"都能被真正保存。
 */
export function normalizeDriveRedirections(drives?: DriveRedirection[]): DriveRedirection[] {
  const result: DriveRedirection[] = [];
  if (drives === undefined || drives === null) {
    return result;
  }
  let index: number = 0;
  while (index < drives.length) {
    const item: DriveRedirection = drives[index];
    const path: string = item.path.trim();
    if (path.length > 0) {
      const name: string = item.name.trim().length > 0 ? item.name.trim() : deriveDriveName(path);
      if (name.length > 0) {
        result.push({ name: name, path: path });
      }
    }
    index += 1;
  }
  return result;
}

export interface ConnectionProfile {
  id: string;
  name: string;
  host: string;
  port: number;
  clientHostname: string;
  username: string;
  password: string;
  rememberPassword: boolean;
  domain: string;
  gateway: string;
  gatewayUsername: string;
  gatewayPassword: string;
  gatewayDomain: string;
  securityMode: string;
  appDataDir: string;
  enableClipboard: boolean;
  enableAudio: boolean;
  enableDrive: boolean;
  enableGfx: boolean;
  desktopWidth: number;
  desktopHeight: number;
  driveRedirections: DriveRedirection[];
}

export const DEFAULT_DESKTOP_WIDTH: number = 1920;
export const DEFAULT_DESKTOP_HEIGHT: number = 1080;

export function createEmptyProfile(id: string): ConnectionProfile {
  return {
    id: id,
    name: '',
    host: '',
    port: 3389,
    clientHostname: '',
    username: '',
    password: '',
    rememberPassword: false,
    domain: '',
    gateway: '',
    gatewayUsername: '',
    gatewayPassword: '',
    gatewayDomain: '',
    securityMode: 'auto',
    appDataDir: '',
    enableClipboard: true,
    enableAudio: false,
    enableDrive: false,
    enableGfx: true,
    desktopWidth: DEFAULT_DESKTOP_WIDTH,
    desktopHeight: DEFAULT_DESKTOP_HEIGHT,
    driveRedirections: []
  };
}

export function cloneProfile(profile: ConnectionProfile): ConnectionProfile {
  return {
    id: profile.id,
    name: profile.name,
    host: profile.host,
    port: profile.port,
    clientHostname: profile.clientHostname,
    username: profile.username,
    password: profile.password,
    rememberPassword: profile.rememberPassword,
    domain: profile.domain,
    gateway: profile.gateway,
    gatewayUsername: profile.gatewayUsername,
    gatewayPassword: profile.gatewayPassword,
    gatewayDomain: profile.gatewayDomain,
    securityMode: profile.securityMode,
    appDataDir: profile.appDataDir,
    enableClipboard: profile.enableClipboard,
    enableAudio: profile.enableAudio,
    enableDrive: profile.enableDrive,
    enableGfx: profile.enableGfx,
    desktopWidth: profile.desktopWidth,
    desktopHeight: profile.desktopHeight,
    driveRedirections: copyDriveRedirections(profile.driveRedirections)
  };
}
