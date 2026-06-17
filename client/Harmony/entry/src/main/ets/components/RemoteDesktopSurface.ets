import { image } from '@kit.ImageKit';
import { inputMethod } from '@kit.IMEKit';
import { KeyCode } from '@ohos.multimodalInput.keyCode';
import { SessionSnapshot, SessionStage } from '../model/SessionModels';
import { KeyboardMapper } from '../utils/KeyboardMapper';
import { ThemeColors, LightColors, DarkColors } from '../utils/ThemeConstants';
import { i18n } from '../utils/I18n';

const PTR_FLAGS_BUTTON1: number = 0x1000;
const PTR_FLAGS_BUTTON2: number = 0x2000;
const PTR_FLAGS_BUTTON3: number = 0x4000;

interface RemotePoint {
  x: number;
  y: number;
}

interface RenderMetrics {
  width: number;
  height: number;
  offsetX: number;
  offsetY: number;
}

interface TextDelta {
  deletedCount: number;
  insertedText: string;
}

@Component
export struct RemoteDesktopSurface {
  @Prop sessionId: number;
  @Prop @Watch('onStageConnected') stage: SessionStage;
  @Prop snapshot: SessionSnapshot;
  @Prop statusMessage: string = '';
  @Prop keyboardRequestToken: number = 0;
  @Prop isFullscreen: boolean = false;
  @Prop @Watch('onThemeChanged') isDark: boolean = false;
  @State colors: ThemeColors = LightColors;
  @StorageLink('__app_language__') appLanguage: string = 'system';
  getFrameBuffer: () => ArrayBuffer = (): ArrayBuffer => new ArrayBuffer(0);
  setSurfaceId: (surfaceId: string) => Promise<void> = async (_surfaceId: string): Promise<void> => {};
  onMouseMove: (x: number, y: number) => void = (_x: number, _y: number): void => {};
  onMouseButton: (x: number, y: number, buttonFlags: number, down: boolean) => void =
    (_x: number, _y: number, _buttonFlags: number, _down: boolean): void => {};
  onMouseWheel: (x: number, y: number, delta: number) => void =
    (_x: number, _y: number, _delta: number): void => {};
  onKeyScancode: (scancode: number, down: boolean) => void =
    (_scancode: number, _down: boolean): void => {};
  onUnicodeKey: (codepoint: number, down: boolean) => void =
    (_codepoint: number, _down: boolean): void => {};
  onScaleChange: (scale: number) => void = (_scale: number): void => {};
  onSurfaceSizeChange: (width: number, height: number) => void = (_width: number, _height: number): void => {};
  @Prop @Watch('onZoomInTriggered') zoomInToken: number = 0;
  @Prop @Watch('onZoomOutTriggered') zoomOutToken: number = 0;
  @Prop @Watch('onZoomResetTriggered') zoomResetToken: number = 0;
  @Prop @Watch('onPanUpTriggered') panUpToken: number = 0;
  @Prop @Watch('onPanDownTriggered') panDownToken: number = 0;
  @Prop @Watch('onPanLeftTriggered') panLeftToken: number = 0;
  @Prop @Watch('onPanRightTriggered') panRightToken: number = 0;

  @State private surfaceWidth: number = 0;
  @State private surfaceHeight: number = 0;
  @State private framePixelMap: image.PixelMap | null = null;
  @State private softInputDraft: string = '';
  @State zoomScale: number = 1.0;
  @State panOffsetX: number = 0;
  @State panOffsetY: number = 0;
  private refreshTimer: number = -1;
  private renderedFrameSequence: number = 0;
  private handledKeyboardRequestToken: number = 0;
  private touchScrollStartY: number = 0;
  private touchScrollStartX: number = 0;
  private touchScrollActive: boolean = false;
  private touchScrollLastX: number = 0;
  private touchScrollLastY: number = 0;
  private touchMoved: boolean = false;
  private touchStartX: number = 0;
  private touchStartY: number = 0;
  private touchStartTs: number = 0;
  private touchDragging: boolean = false;
  private touchStartedOutside: boolean = false;
  private touchScrollResidualY: number = 0;
  private lastMouseMask: number = 0;
  private lastMouseX: number = -1;
  private lastMouseY: number = -1;
  private ctrlPressed: boolean = false;
  private shiftPressed: boolean = false;
  private altPressed: boolean = false;
  private metaPressed: boolean = false;
  private edgeClampEnabled: boolean = true;
  private imfAttached: boolean = false;
  private onInsertText: ((text: string) => void) | null = null;
  private onDeleteLeft: ((length: number) => void) | null = null;
  private onDeleteRight: ((length: number) => void) | null = null;
  private imeSuppressTextChange: boolean = false;
  private softInputFocused: boolean = false;
  private lastHandledKeySignature: string = '';
  private lastHandledKeyTs: number = 0;
  private lastSyntheticKeyTapCode: number = -1;
  private lastSyntheticKeyTapTs: number = 0;

  private surfaceController: XComponentController = new XComponentController();

  onThemeChanged(): void {
    this.colors = this.isDark ? DarkColors : LightColors;
  }

  private readonly rootStackKey: string = 'rdp_root_stack_' + this.sessionId;
  private readonly inputLayerKey: string = 'rdp_input_layer_' + this.sessionId;
  private getModifierState(event: KeyEvent, key: string): boolean {
    if (typeof event?.getModifierKeyState !== 'function') {
      return false;
    }
    try {
      return event.getModifierKeyState([key]);
    } catch (_error) {
      return false;
    }
  }

  private getSoftInputId(): string {
    return 'rdp_soft_input_' + this.sessionId;
  }

  private getBaseFitMetrics(): RenderMetrics {
    const vw = this.surfaceWidth > 0 ? this.surfaceWidth : this.snapshot.width;
    const vh = this.surfaceHeight > 0 ? this.surfaceHeight : this.snapshot.height;
    if (vw <= 0 || vh <= 0 || this.snapshot.width <= 0 || this.snapshot.height <= 0) {
      return { width: Math.max(1, vw), height: Math.max(1, vh), offsetX: 0, offsetY: 0 };
    }
    const vr = vw / vh;
    const sr = this.snapshot.width / this.snapshot.height;
    if (vr > sr) {
      const h = vh;
      const w = h * sr;
      return { width: w, height: h, offsetX: (vw - w) / 2, offsetY: 0 };
    }
    const w = vw;
    const h = w / sr;
    return { width: w, height: h, offsetX: 0, offsetY: (vh - h) / 2 };
  }

  private getTransformedRect(): RenderMetrics {
    const base = this.getBaseFitMetrics();
    const cx = this.surfaceWidth / 2;
    const cy = this.surfaceHeight / 2;
    const s = Math.max(0.01, this.zoomScale);
    return {
      width: base.width * s,
      height: base.height * s,
      offsetX: cx + (base.offsetX - cx) * s + this.panOffsetX,
      offsetY: cy + (base.offsetY - cy) * s + this.panOffsetY
    };
  }

  private getRenderMetrics(): RenderMetrics {
    return this.getTransformedRect();
  }

  private toBaseViewerPoint(x: number, y: number): RemotePoint {
    if (this.zoomScale <= 1.0) {
      return {
        x: x - this.panOffsetX,
        y: y - this.panOffsetY
      };
    }
    const cx = this.surfaceWidth / 2;
    const cy = this.surfaceHeight / 2;
    const s = Math.max(0.01, this.zoomScale);
    return {
      x: cx + (x - cx - this.panOffsetX) / s,
      y: cy + (y - cy - this.panOffsetY) / s
    };
  }

  private toRemotePoint(localX: number, localY: number): RemotePoint {
    const vw = this.surfaceWidth > 0 ? this.surfaceWidth : this.snapshot.width;
    const vh = this.surfaceHeight > 0 ? this.surfaceHeight : this.snapshot.height;

    if (vw <= 0 || vh <= 0 || this.snapshot.width <= 0 || this.snapshot.height <= 0) {
      return { x: 0, y: 0 };
    }

    const base = this.toBaseViewerPoint(localX, localY);
    const x = base.x;
    const y = base.y;

    const frameW = vw;
    const frameH = vh;
    const sourceW = this.snapshot.width;
    const sourceH = this.snapshot.height;

    const scale = Math.min(frameW / sourceW, frameH / sourceH);
    const contentW = sourceW * scale;
    const contentH = sourceH * scale;
    const offsetX = (frameW - contentW) / 2;
    const offsetY = (frameH - contentH) / 2;

    const rx = Math.max(0, Math.min(sourceW - 1, Math.floor((x - offsetX) / scale)));
    const ry = Math.max(0, Math.min(sourceH - 1, Math.floor((y - offsetY) / scale)));

    return { x: rx, y: ry };
  }

  private isLocalWithinContent(localX: number, localY: number): boolean {
    if (this.snapshot.width <= 0 || this.snapshot.height <= 0) return true;
    if (this.surfaceWidth <= 0 || this.surfaceHeight <= 0) return true;

    const base = this.toBaseViewerPoint(localX, localY);
    const x = base.x;
    const y = base.y;

    const frameW = this.surfaceWidth;
    const frameH = this.surfaceHeight;
    const sourceW = this.snapshot.width;
    const sourceH = this.snapshot.height;

    const scale = Math.min(frameW / sourceW, frameH / sourceH);
    const contentW = sourceW * scale;
    const contentH = sourceH * scale;
    const offsetX = (frameW - contentW) / 2;
    const offsetY = (frameH - contentH) / 2;

    const rawX = (x - offsetX) / scale;
    const rawY = (y - offsetY) / scale;
    return rawX >= 0 && rawX < sourceW && rawY >= 0 && rawY < sourceH;
  }

  private mapMouseButton(button: number): number {
    if (button === MouseButton.Right) {
      return PTR_FLAGS_BUTTON2;
    }
    if (button === MouseButton.Middle) {
      return PTR_FLAGS_BUTTON3;
    }
    return PTR_FLAGS_BUTTON1;
  }

  private requestInputFocus(): void {
    try {
      const fc = this.getUIContext()?.getFocusController?.();
      fc?.requestFocus?.(this.rootStackKey);
      fc?.requestFocus?.(this.inputLayerKey);
    } catch (_error) {
    }
  }

  private focusSoftInputLater(): void {
    setTimeout(() => {
      try {
        const fc = this.getUIContext()?.getFocusController?.();
        fc?.requestFocus?.(this.getSoftInputId());
        this.softInputFocused = true;
      } catch (_error) {
      }
    }, 0);
  }

  private showSoftKeyboard(): void {
    if (this.stage !== SessionStage.Connected) {
      return;
    }
    if (!this.imfAttached) {
      this.attachInputMethod();
    }
    this.focusSoftInputLater();
    setTimeout(() => {
      try {
        const controller = inputMethod.getController();
        controller.showTextInput();
      } catch (e) {
        console.warn(`Failed to show soft keyboard: ${e}`);
      }
    }, 50);
  }

  private async attachInputMethod(): Promise<void> {
    if (this.imfAttached || this.stage !== SessionStage.Connected) {
      return;
    }

    try {
      const config: inputMethod.TextConfig = {
        inputAttribute: {
          textInputType: inputMethod.TextInputType.TEXT,
          enterKeyType: inputMethod.EnterKeyType.UNSPECIFIED
        }
      };
      const controller = inputMethod.getController();
      this.focusSoftInputLater();
      await new Promise<void>((resolve) => setTimeout(resolve, 60));
      await controller.attach(false, config);
      this.imfAttached = true;
      console.info('FreeRDP: IMF attached via attach(false)');
    } catch (_attachErr) {
      console.warn(`FreeRDP: attach(false) failed: ${_attachErr}`);
    }
  }

  onStageConnected(): void {
    if (this.stage === SessionStage.Connected) {
      this.requestInputFocus();
    }
  }

  private buildTextDelta(previous: string, next: string): TextDelta {
    const prevChars: string[] = Array.from(previous ?? '');
    const nextChars: string[] = Array.from(next ?? '');

    let prefix: number = 0;
    while (prefix < prevChars.length && prefix < nextChars.length && prevChars[prefix] === nextChars[prefix]) {
      prefix += 1;
    }

    let suffix: number = 0;
    while (suffix < prevChars.length - prefix &&
      suffix < nextChars.length - prefix &&
      prevChars[prevChars.length - 1 - suffix] === nextChars[nextChars.length - 1 - suffix]) {
      suffix += 1;
    }

    return {
      deletedCount: prevChars.length - prefix - suffix,
      insertedText: nextChars.slice(prefix, nextChars.length - suffix).join('')
    };
  }

  private resetSoftInputDraft(): void {
    this.softInputDraft = '';
  }

  private clearSoftInputDraftSoon(): void {
    this.imeSuppressTextChange = true;
    this.softInputDraft = '';
    setTimeout(() => {
      this.imeSuppressTextChange = false;
    }, 50);
  }

  private suppressSoftInputChangeBriefly(): void {
    this.imeSuppressTextChange = true;
    setTimeout(() => {
      this.imeSuppressTextChange = false;
    }, 120);
  }

  private shouldSkipDuplicateKeyEvent(event: KeyEvent): boolean {
    const signature: string =
      `${event.type}|${event.keyCode ?? -1}|${typeof event.keyText === 'string' ? event.keyText : ''}|` +
      `${this.getModifierState(event, 'Shift')}|${this.getModifierState(event, 'Ctrl')}|` +
      `${this.getModifierState(event, 'Alt')}|${this.getModifierState(event, 'Meta')}`;
    const now: number = Date.now();
    if (signature === this.lastHandledKeySignature && now - this.lastHandledKeyTs <= 16) {
      return true;
    }
    this.lastHandledKeySignature = signature;
    this.lastHandledKeyTs = now;
    return false;
  }

  private sendRemoteBackspace(count: number): void {
    const total: number = Math.max(0, Math.floor(count));
    const backspace: number = KeyboardMapper.mapKeyScancode('Backspace', 0);
    if (total <= 0 || backspace <= 0) {
      return;
    }
    let index: number = 0;
    while (index < total) {
      this.onKeyScancode(backspace, true);
      this.onKeyScancode(backspace, false);
      index += 1;
    }
  }

  private sendRemoteCommittedText(text: string): void {
    if (text.length === 0) {
      return;
    }

    for (const ch of text) {
      const codepoint: number = ch.codePointAt(0) ?? 0;

      if (codepoint === 10 || codepoint === 13) {
        const enter: number = KeyboardMapper.mapKeyScancode('Enter', 0);
        if (enter > 0) {
          this.onKeyScancode(enter, true);
          this.onKeyScancode(enter, false);
        }
        continue;
      }

      if (codepoint === 9) {
        const tab: number = KeyboardMapper.mapKeyScancode('Tab', 0);
        if (tab > 0) {
          this.onKeyScancode(tab, true);
          this.onKeyScancode(tab, false);
        }
        continue;
      }

      // Use Unicode key events for all printable characters from IME input.
      // Scancodes represent physical key positions and do not carry case information;
      // sending an uppercase letter as a scancode without Shift produces a lowercase
      // letter on the remote desktop.  Unicode key events carry the actual codepoint,
      // so 'A' (U+0041) is correctly interpreted as uppercase.
      if (codepoint >= 0x20) {
        this.onUnicodeKey(codepoint, true);
        this.onUnicodeKey(codepoint, false);
      }
    }
  }

  private handleSoftInputChange(next: string): void {
    const previous: string = this.softInputDraft ?? '';
    this.softInputDraft = next;
    if (this.stage !== SessionStage.Connected) {
      return;
    }

    if (this.imeSuppressTextChange) {
      return;
    }

    if (this.imfAttached) {
      return;
    }

    const delta: TextDelta = this.buildTextDelta(previous, next);
    if (delta.deletedCount > 0) {
      this.sendRemoteBackspace(delta.deletedCount);
    }
    if (delta.insertedText.length > 0) {
      this.sendRemoteCommittedText(delta.insertedText);
    }
    if (delta.deletedCount > 0 || delta.insertedText.length > 0) {
      this.clearSoftInputDraftSoon();
    }
  }

  private isShiftKeyCode(keyCode: number): boolean {
    return keyCode === KeyCode.KEYCODE_SHIFT_LEFT || keyCode === KeyCode.KEYCODE_SHIFT_RIGHT;
  }

  private isCtrlKeyCode(keyCode: number): boolean {
    return keyCode === KeyCode.KEYCODE_CTRL_LEFT ||
      keyCode === KeyCode.KEYCODE_CTRL_RIGHT ||
      keyCode === 2072 ||
      keyCode === 2073;
  }

  private isAltKeyCode(keyCode: number): boolean {
    return keyCode === KeyCode.KEYCODE_ALT_LEFT || keyCode === KeyCode.KEYCODE_ALT_RIGHT;
  }

  private isMetaKeyCode(keyCode: number): boolean {
    return keyCode === KeyCode.KEYCODE_META_LEFT || keyCode === KeyCode.KEYCODE_META_RIGHT;
  }

  private shouldSynthesizeTapOnKeyUp(keyCode: number, isDown: boolean, isUp: boolean): boolean {
    if (isDown || !isUp) {
      return false;
    }
    if (keyCode !== KeyCode.KEYCODE_DEL && keyCode !== KeyCode.KEYCODE_FORWARD_DEL) {
      return false;
    }
    const now: number = Date.now();
    if (this.lastSyntheticKeyTapCode === keyCode && now - this.lastSyntheticKeyTapTs <= 120) {
      return false;
    }
    this.lastSyntheticKeyTapCode = keyCode;
    this.lastSyntheticKeyTapTs = now;
    return true;
  }

  private syncRemoteModifiers(event: KeyEvent): void {
    const shiftState: boolean = this.getModifierState(event, 'Shift');
    const ctrlState: boolean = this.getModifierState(event, 'Ctrl');
    const altState: boolean = this.getModifierState(event, 'Alt');
    const metaState: boolean = this.getModifierState(event, 'Meta');
    const shiftScancode: number = KeyboardMapper.mapKeyScancode('Shift', 0);
    const ctrlScancode: number = KeyboardMapper.mapKeyScancode('Control', 0);
    const altScancode: number = KeyboardMapper.mapKeyScancode('Alt', 0);
    const metaScancode: number = KeyboardMapper.mapKeyScancode('Meta', 0);

    if (shiftScancode > 0 && shiftState !== this.shiftPressed) {
      this.onKeyScancode(shiftScancode, shiftState);
      this.shiftPressed = shiftState;
    }
    if (ctrlScancode > 0 && ctrlState !== this.ctrlPressed) {
      this.onKeyScancode(ctrlScancode, ctrlState);
      this.ctrlPressed = ctrlState;
    }
    if (altScancode > 0 && altState !== this.altPressed) {
      this.onKeyScancode(altScancode, altState);
      this.altPressed = altState;
    }
    if (metaScancode > 0 && metaState !== this.metaPressed) {
      this.onKeyScancode(metaScancode, metaState);
      this.metaPressed = metaState;
    }
  }

  private handleKey(event: KeyEvent): void {
    const keyCode: number = event.keyCode ?? 0;
    const text: string = typeof event.keyText === 'string' ? event.keyText : '';
    const isDown: boolean = event.type === KeyType.Down;
    const isUp: boolean = event.type === KeyType.Up;
    const isShiftKey: boolean = this.isShiftKeyCode(keyCode);
    const isCtrlKey: boolean = this.isCtrlKeyCode(keyCode);
    const isAltKey: boolean = this.isAltKeyCode(keyCode);
    const isMetaKey: boolean = this.isMetaKeyCode(keyCode);
    const isModifierKey: boolean = isShiftKey || isCtrlKey || isAltKey || isMetaKey;
    if (this.stage !== SessionStage.Connected) {
      return;
    }

    if (!isDown && !isUp) {
      return;
    }

    if (this.shouldSkipDuplicateKeyEvent(event)) {
      return;
    }

    if (!isModifierKey) {
      this.syncRemoteModifiers(event);
    } else {
      if (isShiftKey) {
        this.shiftPressed = isDown;
      }
      if (isCtrlKey) {
        this.ctrlPressed = isDown;
      }
      if (isAltKey) {
        this.altPressed = isDown;
      }
      if (isMetaKey) {
        this.metaPressed = isDown;
      }
    }

    // Route IME / committed text (anything above printable ASCII) through
    // Unicode key events.  Scancodes represent physical key positions and do
    // not carry case or locale information, so a scancode-based 'A' would
    // produce 'a' on the remote, and Chinese characters would be lost.
    if (text.length > 0) {
      let isTextEvent: boolean = event.keyCode === 0;
      if (!isTextEvent) {
        for (const ch of text) {
          if ((ch.codePointAt(0) ?? 0) > 0x7f) {
            isTextEvent = true;
            break;
          }
        }
      }
      if (isTextEvent) {
        if (isDown) {
          this.sendRemoteCommittedText(text);
        }
        return;
      }
    }

    const scancode: number = KeyboardMapper.mapKeyScancode(event.keyText, event.keyCode);
    if (scancode > 0) {
      if (this.shouldSynthesizeTapOnKeyUp(keyCode, isDown, isUp)) {
        this.onKeyScancode(scancode, true);
        this.onKeyScancode(scancode, false);
        return;
      }
      // For hardware keyboard, an uppercase letter arriving without Shift
      // pressed implies local CapsLock.  Inject a synthetic Shift press
      // around the letter scancode so the remote also emits uppercase.
      const code: number = text.length === 1 ? text.charCodeAt(0) : 0;
      const needsShift: boolean = isDown && code >= 65 && code <= 90 && !this.getModifierState(event, 'Shift') &&
        !isShiftKey;
      if (needsShift) {
        const shift: number = KeyboardMapper.mapKeyScancode('Shift', 0);
        this.onKeyScancode(shift, true);
        this.onKeyScancode(scancode, isDown);
        this.onKeyScancode(shift, false);
      } else {
        this.onKeyScancode(scancode, isDown);
      }
      return;
    }

    if (event.keyText.length === 1) {
      this.onUnicodeKey(event.keyText.charCodeAt(0), isDown);
    }
  }

  private getTouchCenter(event: TouchEvent): RemotePoint | null {
    const touches = event.touches;
    if (!touches || touches.length < 2) {
      return null;
    }
    const t0 = touches[0];
    const t1 = touches[1];
    return {
      x: (t0.x + t1.x) / 2,
      y: (t0.y + t1.y) / 2
    };
  }

  private beginTouchScroll(localX: number, localY: number): void {
    if (this.touchDragging) {
      const p = this.toRemotePoint(this.touchStartX, this.touchStartY);
      this.touchDragging = false;
      this.onMouseButton(p.x, p.y, PTR_FLAGS_BUTTON1, false);
    }
    this.touchMoved = true;
    this.touchScrollActive = true;
    this.touchScrollStartX = localX;
    this.touchScrollStartY = localY;
    this.touchScrollLastX = localX;
    this.touchScrollLastY = localY;
    this.touchScrollResidualY = 0;
    this.requestInputFocus();
  }

  private endTouchScroll(): void {
    this.touchScrollActive = false;
    this.touchScrollResidualY = 0;
  }

  private emitTouchScroll(localX: number, localY: number, deltaY: number): void {
    if (deltaY === 0) return;
    const stepPx = 40;
    this.touchScrollResidualY += deltaY;
    let clicks = 0;
    while (Math.abs(this.touchScrollResidualY) >= stepPx && clicks < 20) {
      if (this.touchScrollResidualY > 0) {
        this.touchScrollResidualY -= stepPx;
      } else {
        this.touchScrollResidualY += stepPx;
      }
      clicks++;
    }
    if (clicks <= 0) return;
    const p = this.toRemotePoint(localX, localY);
    const delta = deltaY > 0 ? -120 : 120;
    for (let i = 0; i < clicks; i++) {
      this.onMouseWheel(p.x, p.y, delta);
    }
  }

  private handleTouch(event: TouchEvent): void {
    if (this.stage !== SessionStage.Connected || event.changedTouches.length < 1) {
      return;
    }

    if (event.source === SourceType.Mouse) {
      return;
    }

    const touch = event.changedTouches[0];
    const localX = touch.x;
    const localY = touch.y;
    const type = touch.type;

    const withinContent = this.isLocalWithinContent(localX, localY);
    if (!withinContent && !this.edgeClampEnabled) {
      if (this.touchDragging) {
        const p = this.toRemotePoint(this.touchStartX, this.touchStartY);
        this.touchDragging = false;
        this.onMouseButton(p.x, p.y, PTR_FLAGS_BUTTON1, false);
      }
      this.touchDragging = false;
      this.touchMoved = false;
      this.touchStartedOutside = false;
      this.endTouchScroll();
      return;
    }

    if (type === TouchType.Down) this.requestInputFocus();

    const center = this.getTouchCenter(event);
    if (center) {
      if (!this.touchScrollActive || type === TouchType.Down) {
        this.beginTouchScroll(center.x, center.y);
      }
      if (type === TouchType.Move) {
        const dy = center.y - this.touchScrollLastY;
        this.emitTouchScroll(center.x, center.y, dy);
        this.touchScrollLastX = center.x;
        this.touchScrollLastY = center.y;
      }
      return;
    }

    if (this.touchScrollActive) {
      if (type === TouchType.Move || type === TouchType.Up || type === TouchType.Cancel) {
        this.endTouchScroll();
      }
      if (type !== TouchType.Down) return;
    }

    const p = this.toRemotePoint(localX, localY);
    const now = Date.now();

    if (type === TouchType.Down) {
      this.touchStartX = localX;
      this.touchStartY = localY;
      this.touchStartTs = now;
      this.touchMoved = false;
      this.touchDragging = false;
      this.touchStartedOutside = !withinContent;
      this.onMouseMove(p.x, p.y);
      return;
    }

    if (type === TouchType.Move) {
      if (this.touchStartedOutside) {
        this.onMouseMove(p.x, p.y);
        return;
      }
      const dx = Math.abs(localX - this.touchStartX);
      const dy = Math.abs(localY - this.touchStartY);
      if (dx + dy >= 10) this.touchMoved = true;
      if (this.touchMoved && !this.touchDragging) {
        this.touchDragging = true;
        const startP = this.toRemotePoint(this.touchStartX, this.touchStartY);
        this.onMouseMove(startP.x, startP.y);
        this.onMouseButton(startP.x, startP.y, PTR_FLAGS_BUTTON1, true);
      }
      this.onMouseMove(p.x, p.y);
      return;
    }

    if (type === TouchType.Up) {
      const dt = now - this.touchStartTs;
      if (this.touchStartedOutside) {
        this.onMouseMove(p.x, p.y);
      } else if (this.touchDragging) {
        this.touchDragging = false;
        this.onMouseButton(p.x, p.y, PTR_FLAGS_BUTTON1, false);
      } else if (!this.touchMoved && dt <= 350) {
        this.onMouseButton(p.x, p.y, PTR_FLAGS_BUTTON1, true);
        this.onMouseButton(p.x, p.y, PTR_FLAGS_BUTTON1, false);
      } else if (!this.touchMoved && dt > 500) {
        this.onMouseButton(p.x, p.y, PTR_FLAGS_BUTTON2, true);
        this.onMouseButton(p.x, p.y, PTR_FLAGS_BUTTON2, false);
      } else {
        this.onMouseMove(p.x, p.y);
      }
      this.touchDragging = false;
      this.touchStartedOutside = false;
      return;
    }

    if (type === TouchType.Cancel) {
      if (this.touchDragging) {
        this.touchDragging = false;
        this.onMouseButton(p.x, p.y, PTR_FLAGS_BUTTON1, false);
      }
      this.touchStartedOutside = false;
      this.endTouchScroll();
    }
  }

  private resetZoom(): void {
    this.zoomScale = 1.0;
    this.panOffsetX = 0;
    this.panOffsetY = 0;
    this.onScaleChange(1.0);
  }

  private applyZoomStep(step: number, centerX: number, centerY: number): void {
    const newScale: number = Math.max(0.5, Math.min(3.0, this.zoomScale + step));
    if (Math.abs(newScale - this.zoomScale) > 0.001) {
      const cx = this.surfaceWidth / 2;
      const cy = this.surfaceHeight / 2;
      const scaleRatio: number = newScale / Math.max(0.01, this.zoomScale);
      this.panOffsetX = centerX - cx - scaleRatio * (centerX - cx - this.panOffsetX);
      this.panOffsetY = centerY - cy - scaleRatio * (centerY - cy - this.panOffsetY);
      this.zoomScale = newScale;
      this.onScaleChange(newScale);
    }
  }

  onZoomInTriggered(): void {
    if (this.zoomInToken > 0) {
      this.applyZoomStep(0.12, this.surfaceWidth / 2, this.surfaceHeight / 2);
    }
  }

  onZoomOutTriggered(): void {
    if (this.zoomOutToken > 0) {
      this.applyZoomStep(-0.12, this.surfaceWidth / 2, this.surfaceHeight / 2);
    }
  }

  onZoomResetTriggered(): void {
    if (this.zoomResetToken > 0) {
      this.resetZoom();
    }
  }

  onPanUpTriggered(): void {
    if (this.panUpToken > 0) {
      const panStep = 100;
      this.panOffsetY += panStep;
      this.clampPanOffset();
    }
  }

  onPanDownTriggered(): void {
    if (this.panDownToken > 0) {
      const panStep = 100;
      this.panOffsetY -= panStep;
      this.clampPanOffset();
    }
  }

  onPanLeftTriggered(): void {
    if (this.panLeftToken > 0) {
      const panStep = 100;
      this.panOffsetX += panStep;
      this.clampPanOffset();
    }
  }

  onPanRightTriggered(): void {
    if (this.panRightToken > 0) {
      const panStep = 100;
      this.panOffsetX -= panStep;
      this.clampPanOffset();
    }
  }

  private clampPanOffset(): void {
    const tr = this.getTransformedRect();
    const maxPanX = Math.max(0, (tr.width - this.surfaceWidth) / 2);
    const maxPanY = Math.max(0, (tr.height - this.surfaceHeight) / 2);
    this.panOffsetX = Math.max(-maxPanX, Math.min(maxPanX, this.panOffsetX));
    this.panOffsetY = Math.max(-maxPanY, Math.min(maxPanY, this.panOffsetY));
  }

  private handleMouse(event?: MouseEvent): void {
    if (this.stage !== SessionStage.Connected || event === undefined) {
      return;
    }

    const localX = event.x;
    const localY = event.y;
    this.lastMouseX = localX;
    this.lastMouseY = localY;

    const action = event.action;
    const button = event.button;

    const left = 1;
    const middle = 2;
    const right = 4;
    let bit = 0;
    if (button === MouseButton.Left) bit = left;
    else if (button === MouseButton.Middle) bit = middle;
    else if (button === MouseButton.Right) bit = right;

    if (!this.isLocalWithinContent(localX, localY) && !this.edgeClampEnabled) {
      if (this.lastMouseMask !== 0) {
        this.lastMouseMask = 0;
        const p = this.toRemotePoint(localX, localY);
        this.onMouseMove(p.x, p.y);
        this.onMouseButton(p.x, p.y, PTR_FLAGS_BUTTON1, false);
        this.onMouseButton(p.x, p.y, PTR_FLAGS_BUTTON2, false);
        this.onMouseButton(p.x, p.y, PTR_FLAGS_BUTTON3, false);
      }
      return;
    }

    const mouseOutside = this.edgeClampEnabled && !this.isLocalWithinContent(localX, localY);

    if (!mouseOutside) {
      if (action === MouseAction.Press) {
        this.lastMouseMask |= bit;
      }
      if (action === MouseAction.Release) {
        this.lastMouseMask &= ~bit;
      }
    }

    if (action === MouseAction.Press) {
      this.requestInputFocus();
    }

    const point: RemotePoint = this.toRemotePoint(localX, localY);
    this.onMouseMove(point.x, point.y);

    if (!mouseOutside) {
      if (action === MouseAction.Press) {
        this.onMouseButton(point.x, point.y, this.mapMouseButton(button), true);
      } else if (action === MouseAction.Release) {
        this.onMouseButton(point.x, point.y, this.mapMouseButton(button), false);
      }
    } else if (this.lastMouseMask !== 0) {
      this.lastMouseMask = 0;
      this.onMouseButton(point.x, point.y, PTR_FLAGS_BUTTON1, false);
      this.onMouseButton(point.x, point.y, PTR_FLAGS_BUTTON2, false);
      this.onMouseButton(point.x, point.y, PTR_FLAGS_BUTTON3, false);
    }
  }

  private handleAxis(event: AxisEvent): void {
    if (this.stage !== SessionStage.Connected) {
      return;
    }

    const axisX = event.x ?? this.lastMouseX;
    const axisY = event.y ?? this.lastMouseY;

    if (!this.isLocalWithinContent(axisX, axisY)) {
      return;
    }

    let dy: number = 0;
    if (typeof event.getVerticalAxisValue === 'function') {
      dy = event.getVerticalAxisValue();
    } else if (event.scrollStep !== undefined) {
      dy = event.scrollStep;
    }

    if (dy === 0) {
      return;
    }

    if (this.ctrlPressed) {
      this.applyZoomStep(dy < 0 ? -0.12 : 0.12, axisX, axisY);
      return;
    }

    const point: RemotePoint = this.toRemotePoint(axisX, axisY);
    this.onMouseWheel(point.x, point.y, dy < 0 ? -120 : 120);
  }

  private releasePixelMap(): void {
    if (this.framePixelMap !== null) {
      try {
        this.framePixelMap.release();
      } catch (_error) {
      }
      this.framePixelMap = null;
    }
  }

  private normalizeFrameBuffer(frame: ArrayBuffer): ArrayBuffer {
    const expectedStride: number = this.snapshot.width * 4;
    if (this.snapshot.width <= 0 || this.snapshot.height <= 0 || expectedStride <= 0) {
      return new ArrayBuffer(0);
    }
    if (this.snapshot.frameStride <= 0 || this.snapshot.frameStride === expectedStride) {
      return frame;
    }

    const src: Uint8Array = new Uint8Array(frame);
    const tight: Uint8Array = new Uint8Array(expectedStride * this.snapshot.height);
    const rowBytes: number = Math.min(expectedStride, this.snapshot.frameStride);
    let y: number = 0;
    while (y < this.snapshot.height) {
      const srcOffset: number = y * this.snapshot.frameStride;
      const dstOffset: number = y * expectedStride;
      let x: number = 0;
      while (x < rowBytes && srcOffset + x < src.length && dstOffset + x < tight.length) {
        tight[dstOffset + x] = src[srcOffset + x];
        x += 1;
      }
      y += 1;
    }
    return tight.buffer;
  }

  private refreshPixelMap(): void {
    if (this.keyboardRequestToken > this.handledKeyboardRequestToken) {
      this.handledKeyboardRequestToken = this.keyboardRequestToken;
      this.showSoftKeyboard();
    }

    if (this.stage !== SessionStage.Connected) {
      return;
    }
    if (this.snapshot.frameSequence <= this.renderedFrameSequence ||
      this.snapshot.width <= 0 ||
      this.snapshot.height <= 0) {
      return;
    }

    const rawFrame: ArrayBuffer = this.getFrameBuffer();
    if (rawFrame.byteLength === 0) {
      return;
    }

    const frame: ArrayBuffer = this.normalizeFrameBuffer(rawFrame);
    const expectedSize: number = this.snapshot.width * this.snapshot.height * 4;
    if (frame.byteLength < expectedSize) {
      return;
    }

    try {
      const nextPixelMap: image.PixelMap = image.createPixelMapSync(frame, {
        size: { width: this.snapshot.width, height: this.snapshot.height },
        srcPixelFormat: image.PixelMapFormat.BGRA_8888,
        pixelFormat: image.PixelMapFormat.BGRA_8888,
        editable: false
      });
      this.releasePixelMap();
      this.framePixelMap = nextPixelMap;
      this.renderedFrameSequence = this.snapshot.frameSequence;
    } catch (error) {
      console.error(`RemoteDesktopSurface refreshPixelMap failed: ${JSON.stringify(error)}`);
    }
  }

  aboutToAppear(): void {
    this.colors = this.isDark ? DarkColors : LightColors;
    this.setSurfaceId('');

    this.onInsertText = (text: string): void => {
      if (this.stage !== SessionStage.Connected || text.length === 0) {
        return;
      }
      this.imeSuppressTextChange = true;
      console.info(`FreeRDP: IME insertText '${text}'`);
      this.sendRemoteCommittedText(text);
      this.resetSoftInputDraft();
      setTimeout(() => {
        this.imeSuppressTextChange = false;
      }, 50);
    };
    this.onDeleteLeft = (length: number): void => {
      if (this.stage !== SessionStage.Connected || length <= 0) {
        return;
      }
      this.imeSuppressTextChange = true;
      console.info(`FreeRDP: IME deleteLeft ${length}`);
      this.sendRemoteBackspace(length);
      this.resetSoftInputDraft();
      setTimeout(() => {
        this.imeSuppressTextChange = false;
      }, 50);
    };
    this.onDeleteRight = (_length: number): void => {
    };
    try {
      inputMethod.getController().on('insertText', this.onInsertText);
      inputMethod.getController().on('deleteLeft', this.onDeleteLeft);
      inputMethod.getController().on('deleteRight', this.onDeleteRight);
    } catch (e) {
      console.warn(`FreeRDP: IME listeners registration failed: ${e}`);
    }

    this.refreshTimer = setInterval(() => {
      this.refreshPixelMap();
    }, 120);
  }

  aboutToDisappear(): void {
    this.imfAttached = false;
    this.softInputFocused = false;
    this.setSurfaceId('');
    if (this.onInsertText !== null) {
      try { inputMethod.getController().off('insertText', this.onInsertText); } catch (_) {}
    }
    if (this.onDeleteLeft !== null) {
      try { inputMethod.getController().off('deleteLeft', this.onDeleteLeft); } catch (_) {}
    }
    if (this.onDeleteRight !== null) {
      try { inputMethod.getController().off('deleteRight', this.onDeleteRight); } catch (_) {}
    }
    if (this.refreshTimer >= 0) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = -1;
    }
    this.releasePixelMap();
  }

  build() {
    Stack() {
      if (this.framePixelMap !== null) {
        Image(this.framePixelMap)
          .width(this.getTransformedRect().width)
          .height(this.getTransformedRect().height)
          .position({
            x: this.getTransformedRect().offsetX,
            y: this.getTransformedRect().offsetY
          })
          .interpolation(ImageInterpolation.High)
          .objectFit(ImageFit.Fill)
      } else if (this.stage === SessionStage.Connecting) {
        Column({ space: 12 }) {
          LoadingProgress()
            .color(this.colors.primary)
          Text(i18n.get(this.appLanguage, 'connecting_first_frame'))
            .fontColor(this.colors.mutedForeground)
            .fontSize(14)
        }
      } else if (this.stage === SessionStage.Connected) {
        Text(i18n.get(this.appLanguage, 'waiting_first_frame'))
          .fontColor(this.colors.mutedForeground)
          .fontSize(14)
      } else {
        Text(i18n.get(this.appLanguage, 'connect_to_show_desktop'))
          .fontColor(this.colors.mutedForeground)
          .fontSize(14)
      }

      if (this.stage === SessionStage.Connected) {
        Column()
          .id(this.inputLayerKey)
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.001)')
          .focusable(true)
          .focusOnTouch(true)
          .defaultFocus(true)
          .onAppear(() => {
            if (this.stage !== SessionStage.Connected) return;
            this.requestInputFocus();
          })
          .onAreaChange((oldValue: Area, newValue: Area) => {
            const newWidth = Number(newValue.width);
            const newHeight = Number(newValue.height);
            if (newWidth > 0 && newHeight > 0) {
              this.surfaceWidth = newWidth;
              this.surfaceHeight = newHeight;
              this.onSurfaceSizeChange(newWidth, newHeight);
            }
          })
          .onTouch((event: TouchEvent) => {
            this.handleTouch(event);
          })
          .onMouse((event?: MouseEvent) => {
            this.handleMouse(event);
          })
          .onHover((isHover: boolean) => {
            if (!isHover && this.lastMouseMask !== 0) {
              const p = this.toRemotePoint(this.lastMouseX, this.lastMouseY);
              this.onMouseButton(p.x, p.y, PTR_FLAGS_BUTTON1, false);
              this.onMouseButton(p.x, p.y, PTR_FLAGS_BUTTON2, false);
              this.onMouseButton(p.x, p.y, PTR_FLAGS_BUTTON3, false);
              this.lastMouseMask = 0;
            }
          })
          .onAxisEvent((event: AxisEvent) => {
            this.handleAxis(event);
          })
      }

      if (this.stage === SessionStage.Disconnected || this.stage === SessionStage.Error) {
        Column({ space: 12 }) {
          Text(this.stage === SessionStage.Error
            ? i18n.get(this.appLanguage, 'error_overlay_title')
            : i18n.get(this.appLanguage, 'disconnected_overlay_title'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#ffffff')

          Text(i18n.get(this.appLanguage, 'disconnected_overlay_hint'))
            .fontSize(14)
            .fontColor('rgba(255,255,255,0.7)')
          if (this.stage === SessionStage.Error) {
            Text(this.statusMessage)
              .fontSize(12)
              .fontColor('rgba(255,255,255,0.55)')
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('80%')
              .textAlign(TextAlign.Center)
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('rgba(30,30,30,0.72)')
        .backdropBlur(8)
        .zIndex(10)
      }

      if (this.stage === SessionStage.Connected) {
        TextArea({ text: this.softInputDraft, placeholder: '' })
          .id(this.getSoftInputId())
          .width(1)
          .height(1)
          .opacity(0.01)
          .caretColor(Color.Transparent)
          .fontSize(1)
          .fontColor(Color.Transparent)
          .backgroundColor(Color.Transparent)
          .position({ x: -100, y: -100 })
          .focusOnTouch(false)
          .onFocus(() => {
            this.softInputFocused = true;
          })
          .onBlur(() => {
            this.softInputFocused = false;
          })
          .onChange((value: string) => {
            this.handleSoftInputChange(value);
          })
          .onKeyEvent((event: KeyEvent) => {
            const ctrlLike: boolean = this.getModifierState(event, 'Ctrl') ||
              this.getModifierState(event, 'Alt') ||
              this.getModifierState(event, 'Meta');
            const keyText: string = typeof event.keyText === 'string' ? event.keyText : '';
            const normalizedKey: string = keyText.toUpperCase();
            if (ctrlLike && event.type === KeyType.Down &&
              (normalizedKey === 'KEYCODE_V' || normalizedKey === 'KEYCODE_C' || normalizedKey === 'KEYCODE_X' ||
                normalizedKey === 'KEYCODE_A' || normalizedKey === 'KEYCODE_Z')) {
              this.suppressSoftInputChangeBriefly();
              this.resetSoftInputDraft();
            }
            if (!ctrlLike && !KeyboardMapper.shouldCaptureInTextInput(event.keyText, event.keyCode ?? 0)) {
              return false;
            }
            this.handleKey(event);
            return true;
          })
      }
    }
    .id(this.rootStackKey)
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors.background)
    .borderRadius(this.isFullscreen ? 0 : 18)
    .clip(true)
    .focusable(true)
    .focusOnTouch(false)
    .defaultFocus(true)
    .onKeyEvent((event: KeyEvent) => {
      const ctrlLike: boolean = this.getModifierState(event, 'Ctrl') ||
        this.getModifierState(event, 'Alt') ||
        this.getModifierState(event, 'Meta');
      if (this.softInputFocused &&
        (ctrlLike || KeyboardMapper.shouldCaptureInTextInput(event.keyText, event.keyCode ?? 0))) {
        return false;
      }
      this.handleKey(event);
      return true;
    })
    .onAreaChange((_, newValue) => {
      this.surfaceWidth = Number(newValue.width);
      this.surfaceHeight = Number(newValue.height);
    })
  }
}
