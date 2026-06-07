export class KeyboardMapper {
  // Defines key states for modifier keys
  public static readonly KEYSTATE_ON = 1;
  public static readonly KEYSTATE_LOCKED = 2;
  public static readonly KEYSTATE_OFF = 3;

  // Basic RDP Scancodes mapping based on FreeRDP / USB HID usage tables
  private static readonly RDP_SCANCODE_ESCAPE = 0x0001;
  private static readonly RDP_SCANCODE_KEY_1 = 0x0002;
  private static readonly RDP_SCANCODE_KEY_2 = 0x0003;
  private static readonly RDP_SCANCODE_KEY_3 = 0x0004;
  private static readonly RDP_SCANCODE_KEY_4 = 0x0005;
  private static readonly RDP_SCANCODE_KEY_5 = 0x0006;
  private static readonly RDP_SCANCODE_KEY_6 = 0x0007;
  private static readonly RDP_SCANCODE_KEY_7 = 0x0008;
  private static readonly RDP_SCANCODE_KEY_8 = 0x0009;
  private static readonly RDP_SCANCODE_KEY_9 = 0x000A;
  private static readonly RDP_SCANCODE_KEY_0 = 0x000B;
  private static readonly RDP_SCANCODE_OEM_MINUS = 0x000C;
  private static readonly RDP_SCANCODE_OEM_PLUS = 0x000D;
  private static readonly RDP_SCANCODE_BACKSPACE = 0x000E;
  private static readonly RDP_SCANCODE_TAB = 0x000F;
  private static readonly RDP_SCANCODE_KEY_Q = 0x0010;
  private static readonly RDP_SCANCODE_KEY_W = 0x0011;
  private static readonly RDP_SCANCODE_KEY_E = 0x0012;
  private static readonly RDP_SCANCODE_KEY_R = 0x0013;
  private static readonly RDP_SCANCODE_KEY_T = 0x0014;
  private static readonly RDP_SCANCODE_KEY_Y = 0x0015;
  private static readonly RDP_SCANCODE_KEY_U = 0x0016;
  private static readonly RDP_SCANCODE_KEY_I = 0x0017;
  private static readonly RDP_SCANCODE_KEY_O = 0x0018;
  private static readonly RDP_SCANCODE_KEY_P = 0x0019;
  private static readonly RDP_SCANCODE_OEM_4 = 0x001A;  // [ {
  private static readonly RDP_SCANCODE_OEM_6 = 0x001B;  // ] }
  private static readonly RDP_SCANCODE_RETURN = 0x001C;
  private static readonly RDP_SCANCODE_LCONTROL = 0x001D;
  private static readonly RDP_SCANCODE_KEY_A = 0x001E;
  private static readonly RDP_SCANCODE_KEY_S = 0x001F;
  private static readonly RDP_SCANCODE_KEY_D = 0x0020;
  private static readonly RDP_SCANCODE_KEY_F = 0x0021;
  private static readonly RDP_SCANCODE_KEY_G = 0x0022;
  private static readonly RDP_SCANCODE_KEY_H = 0x0023;
  private static readonly RDP_SCANCODE_KEY_J = 0x0024;
  private static readonly RDP_SCANCODE_KEY_K = 0x0025;
  private static readonly RDP_SCANCODE_KEY_L = 0x0026;
  private static readonly RDP_SCANCODE_OEM_1 = 0x0027;  // ; :
  private static readonly RDP_SCANCODE_OEM_7 = 0x0028;  // ' "
  private static readonly RDP_SCANCODE_OEM_3 = 0x0029;  // ` ~
  private static readonly RDP_SCANCODE_LSHIFT = 0x002A;
  private static readonly RDP_SCANCODE_OEM_5 = 0x002B;  // \ |
  private static readonly RDP_SCANCODE_KEY_Z = 0x002C;
  private static readonly RDP_SCANCODE_KEY_X = 0x002D;
  private static readonly RDP_SCANCODE_KEY_C = 0x002E;
  private static readonly RDP_SCANCODE_KEY_V = 0x002F;
  private static readonly RDP_SCANCODE_KEY_B = 0x0030;
  private static readonly RDP_SCANCODE_KEY_N = 0x0031;
  private static readonly RDP_SCANCODE_KEY_M = 0x0032;
  private static readonly RDP_SCANCODE_OEM_COMMA = 0x0033;  // , <
  private static readonly RDP_SCANCODE_OEM_PERIOD = 0x0034;  // . >
  private static readonly RDP_SCANCODE_OEM_2 = 0x0035;  // / ?
  private static readonly RDP_SCANCODE_RSHIFT = 0x0036;
  private static readonly RDP_SCANCODE_LALT = 0x0038;
  private static readonly RDP_SCANCODE_CAPSLOCK = 0x003A;
  private static readonly RDP_SCANCODE_F1 = 0x003B;
  private static readonly RDP_SCANCODE_F2 = 0x003C;
  private static readonly RDP_SCANCODE_F3 = 0x003D;
  private static readonly RDP_SCANCODE_F4 = 0x003E;
  private static readonly RDP_SCANCODE_F5 = 0x003F;
  private static readonly RDP_SCANCODE_F6 = 0x0040;
  private static readonly RDP_SCANCODE_F7 = 0x0041;
  private static readonly RDP_SCANCODE_F8 = 0x0042;
  private static readonly RDP_SCANCODE_F9 = 0x0043;
  private static readonly RDP_SCANCODE_F10 = 0x0044;
  private static readonly RDP_SCANCODE_NUMLOCK = 0x0045;
  private static readonly RDP_SCANCODE_SCROLLLOCK = 0x0046;
  private static readonly RDP_SCANCODE_F11 = 0x0057;
  private static readonly RDP_SCANCODE_F12 = 0x0058;
  private static readonly RDP_SCANCODE_SPACE = 0x0039;

  // Extended scancodes (0x01XX prefix = KBDEXT flag)
  private static readonly RDP_SCANCODE_INSERT = 0x0152;
  private static readonly RDP_SCANCODE_HOME = 0x0147;
  private static readonly RDP_SCANCODE_PAGEUP = 0x0149;
  private static readonly RDP_SCANCODE_DELETE = 0x0153;
  private static readonly RDP_SCANCODE_END = 0x014F;
  private static readonly RDP_SCANCODE_PAGEDOWN = 0x0151;
  private static readonly RDP_SCANCODE_UP = 0x0148;
  private static readonly RDP_SCANCODE_LEFT = 0x014B;
  private static readonly RDP_SCANCODE_RIGHT = 0x014D;
  private static readonly RDP_SCANCODE_DOWN = 0x0150;
  private static readonly RDP_SCANCODE_RCONTROL = 0x011D;
  private static readonly RDP_SCANCODE_RALT = 0x0138;
  private static readonly RDP_SCANCODE_LWIN = 0x015B;
  private static readonly RDP_SCANCODE_RWIN = 0x015C;
  private static readonly RDP_SCANCODE_APPS = 0x015D;  // Context menu
  private static readonly RDP_SCANCODE_PRINTSCREEN = 0x0137;
  private static readonly RDP_SCANCODE_PAUSE = 0x0045;

  public static mapKeyScancode(keyText: string, keyCode: number): number {
    switch (keyText) {
      case 'Enter': return KeyboardMapper.RDP_SCANCODE_RETURN;
      case 'Backspace': return KeyboardMapper.RDP_SCANCODE_BACKSPACE;
      case 'Tab': return KeyboardMapper.RDP_SCANCODE_TAB;
      case 'Escape': return KeyboardMapper.RDP_SCANCODE_ESCAPE;
      case 'Space': return KeyboardMapper.RDP_SCANCODE_SPACE;
      case 'ArrowLeft': return KeyboardMapper.RDP_SCANCODE_LEFT;
      case 'ArrowRight': return KeyboardMapper.RDP_SCANCODE_RIGHT;
      case 'ArrowUp': return KeyboardMapper.RDP_SCANCODE_UP;
      case 'ArrowDown': return KeyboardMapper.RDP_SCANCODE_DOWN;
      case 'Delete': return KeyboardMapper.RDP_SCANCODE_DELETE;
      case 'Insert': return KeyboardMapper.RDP_SCANCODE_INSERT;
      case 'Home': return KeyboardMapper.RDP_SCANCODE_HOME;
      case 'End': return KeyboardMapper.RDP_SCANCODE_END;
      case 'PageUp': return KeyboardMapper.RDP_SCANCODE_PAGEUP;
      case 'PageDown': return KeyboardMapper.RDP_SCANCODE_PAGEDOWN;
      case 'Shift': return KeyboardMapper.RDP_SCANCODE_LSHIFT;
      case 'Control': return KeyboardMapper.RDP_SCANCODE_LCONTROL;
      case 'Alt': return KeyboardMapper.RDP_SCANCODE_LALT;
      case 'Meta': return KeyboardMapper.RDP_SCANCODE_LWIN;
      case 'CapsLock': return KeyboardMapper.RDP_SCANCODE_CAPSLOCK;
      case 'NumLock': return KeyboardMapper.RDP_SCANCODE_NUMLOCK;
      case 'ScrollLock': return KeyboardMapper.RDP_SCANCODE_SCROLLLOCK;
      case 'PrintScreen': return KeyboardMapper.RDP_SCANCODE_PRINTSCREEN;
      case 'Pause': return KeyboardMapper.RDP_SCANCODE_PAUSE;
      case 'F1': return KeyboardMapper.RDP_SCANCODE_F1;
      case 'F2': return KeyboardMapper.RDP_SCANCODE_F2;
      case 'F3': return KeyboardMapper.RDP_SCANCODE_F3;
      case 'F4': return KeyboardMapper.RDP_SCANCODE_F4;
      case 'F5': return KeyboardMapper.RDP_SCANCODE_F5;
      case 'F6': return KeyboardMapper.RDP_SCANCODE_F6;
      case 'F7': return KeyboardMapper.RDP_SCANCODE_F7;
      case 'F8': return KeyboardMapper.RDP_SCANCODE_F8;
      case 'F9': return KeyboardMapper.RDP_SCANCODE_F9;
      case 'F10': return KeyboardMapper.RDP_SCANCODE_F10;
      case 'F11': return KeyboardMapper.RDP_SCANCODE_F11;
      case 'F12': return KeyboardMapper.RDP_SCANCODE_F12;
      case 'ContextMenu': return KeyboardMapper.RDP_SCANCODE_APPS;
      default: break;
    }

    if (keyText.length === 1) {
      const upper = keyText.toUpperCase();
      switch (upper) {
        case 'A': return KeyboardMapper.RDP_SCANCODE_KEY_A;
        case 'B': return KeyboardMapper.RDP_SCANCODE_KEY_B;
        case 'C': return KeyboardMapper.RDP_SCANCODE_KEY_C;
        case 'D': return KeyboardMapper.RDP_SCANCODE_KEY_D;
        case 'E': return KeyboardMapper.RDP_SCANCODE_KEY_E;
        case 'F': return KeyboardMapper.RDP_SCANCODE_KEY_F;
        case 'G': return KeyboardMapper.RDP_SCANCODE_KEY_G;
        case 'H': return KeyboardMapper.RDP_SCANCODE_KEY_H;
        case 'I': return KeyboardMapper.RDP_SCANCODE_KEY_I;
        case 'J': return KeyboardMapper.RDP_SCANCODE_KEY_J;
        case 'K': return KeyboardMapper.RDP_SCANCODE_KEY_K;
        case 'L': return KeyboardMapper.RDP_SCANCODE_KEY_L;
        case 'M': return KeyboardMapper.RDP_SCANCODE_KEY_M;
        case 'N': return KeyboardMapper.RDP_SCANCODE_KEY_N;
        case 'O': return KeyboardMapper.RDP_SCANCODE_KEY_O;
        case 'P': return KeyboardMapper.RDP_SCANCODE_KEY_P;
        case 'Q': return KeyboardMapper.RDP_SCANCODE_KEY_Q;
        case 'R': return KeyboardMapper.RDP_SCANCODE_KEY_R;
        case 'S': return KeyboardMapper.RDP_SCANCODE_KEY_S;
        case 'T': return KeyboardMapper.RDP_SCANCODE_KEY_T;
        case 'U': return KeyboardMapper.RDP_SCANCODE_KEY_U;
        case 'V': return KeyboardMapper.RDP_SCANCODE_KEY_V;
        case 'W': return KeyboardMapper.RDP_SCANCODE_KEY_W;
        case 'X': return KeyboardMapper.RDP_SCANCODE_KEY_X;
        case 'Y': return KeyboardMapper.RDP_SCANCODE_KEY_Y;
        case 'Z': return KeyboardMapper.RDP_SCANCODE_KEY_Z;
        case '1': return KeyboardMapper.RDP_SCANCODE_KEY_1;
        case '2': return KeyboardMapper.RDP_SCANCODE_KEY_2;
        case '3': return KeyboardMapper.RDP_SCANCODE_KEY_3;
        case '4': return KeyboardMapper.RDP_SCANCODE_KEY_4;
        case '5': return KeyboardMapper.RDP_SCANCODE_KEY_5;
        case '6': return KeyboardMapper.RDP_SCANCODE_KEY_6;
        case '7': return KeyboardMapper.RDP_SCANCODE_KEY_7;
        case '8': return KeyboardMapper.RDP_SCANCODE_KEY_8;
        case '9': return KeyboardMapper.RDP_SCANCODE_KEY_9;
        case '0': return KeyboardMapper.RDP_SCANCODE_KEY_0;
        case '-': return KeyboardMapper.RDP_SCANCODE_OEM_MINUS;
        case '=': return KeyboardMapper.RDP_SCANCODE_OEM_PLUS;
        case '[': return KeyboardMapper.RDP_SCANCODE_OEM_4;
        case ']': return KeyboardMapper.RDP_SCANCODE_OEM_6;
        case ';': return KeyboardMapper.RDP_SCANCODE_OEM_1;
        case "'": return KeyboardMapper.RDP_SCANCODE_OEM_7;
        case '`': return KeyboardMapper.RDP_SCANCODE_OEM_3;
        case '\\': return KeyboardMapper.RDP_SCANCODE_OEM_5;
        case ',': return KeyboardMapper.RDP_SCANCODE_OEM_COMMA;
        case '.': return KeyboardMapper.RDP_SCANCODE_OEM_PERIOD;
        case '/': return KeyboardMapper.RDP_SCANCODE_OEM_2;
        case ' ': return KeyboardMapper.RDP_SCANCODE_SPACE;
      }
    }
    return 0;
  }
}
