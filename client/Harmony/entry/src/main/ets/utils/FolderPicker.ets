import { picker, fileUri } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { logger, LogTags } from './Logger';

/**
 * 目录选择器结果
 */
export interface FolderPickResult {
  /** 本地文件系统路径，供 FreeRDP /drive 参数使用 */
  path: string;
  /** 目录名称（路径最后一段），适合用作盘符名 */
  name: string;
}

/**
 * 目录选择器工具类，封装 DocumentViewPicker 的文件夹选择能力。
 *
 * 使用 selectMode = DocumentSelectMode.FOLDER 让用户通过系统文件管理器
 * 可视化地选择一个本地文件夹，相比手动输入路径更加友好。
 *
 * 注意：FOLDER 选择能力依赖 SystemCapability.FileManagement.UserFileService.FolderSelection，
 * 部分设备（如手机）可能不支持，此时返回 null，调用方应回退到手动输入路径。
 */
export class FolderPicker {
  /**
   * 拉起系统目录选择器，让用户选择一个本地文件夹。
   *
   * @param context UIAbilityContext，用于创建 DocumentViewPicker
   * @returns 选中目录的结果（path + name）；用户取消或不支持时返回 null
   */
  static async pickFolder(context: common.UIAbilityContext): Promise<FolderPickResult | null> {
    if (!canIUse('SystemCapability.FileManagement.UserFileService.FolderSelection')) {
      logger.warn(LogTags.CONNECTION_FORM, 'FolderPicker: FOLDER selection not supported on this device');
      return null;
    }
    try {
      const documentViewPicker = new picker.DocumentViewPicker(context);
      const documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 1;
      documentSelectOptions.selectMode = picker.DocumentSelectMode.FOLDER;

      const selectResult: string[] = await documentViewPicker.select(documentSelectOptions);
      if (selectResult.length === 0) {
        return null;
      }

      const uri: string = selectResult[0];
      const fileUriObj = new fileUri.FileUri(uri);
      const path: string = fileUriObj.path;

      if (path.length === 0) {
        logger.warn(LogTags.CONNECTION_FORM, 'FolderPicker: converted path is empty');
        return null;
      }

      const name: string = FolderPicker.extractFolderName(path);
      logger.info(LogTags.CONNECTION_FORM, 'FolderPicker: folder selected');
      const result: FolderPickResult = { path: path, name: name };
      return result;
    } catch (e) {
      const err = e as BusinessError;
      // 用户取消选择时会抛异常（code 13900042 / 14000011 等），不当作错误处理
      if (err.code !== 13900042 && err.code !== 14000011) {
        logger.error(LogTags.CONNECTION_FORM,
          `FolderPicker failed: code=${err.code}, message=${err.message}`);
      }
      return null;
    }
  }

  /**
   * 从文件路径中提取最后一段作为目录名称。
   * 例如 "/data/storage/el2/base/files/docs" -> "docs"
   */
  private static extractFolderName(path: string): string {
    if (path.length === 0) {
      return '';
    }
    // 去除末尾的斜杠
    let trimmed: string = path;
    while (trimmed.length > 1 && trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    const lastSlash: number = trimmed.lastIndexOf('/');
    if (lastSlash < 0) {
      return trimmed;
    }
    return trimmed.substring(lastSlash + 1);
  }
}
