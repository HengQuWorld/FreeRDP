import { inputMethod } from '@kit.IMEKit';

export function showKeyboardForField(uiContext: UIContext | null, fieldId: string): void {
  try {
    const fc = uiContext?.getFocusController?.();
    fc?.requestFocus?.(fieldId);
    inputMethod.getController().showTextInput();
  } catch (_) {
  }
}
