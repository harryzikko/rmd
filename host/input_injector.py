"""
Windows Input Injector for Remote Desktop
Handles mouse movement, clicks, scrolling, virtual keys, shortcuts, and Unicode text typing.
"""
import ctypes
import ctypes.wintypes
import time
import subprocess
try:
    import win32clipboard
    import win32con
    HAS_WIN32_CLIP = True
except ImportError:
    HAS_WIN32_CLIP = False
from host.desktop_attach import attach_to_desktop

u32 = ctypes.windll.user32

# Constants
INPUT_MOUSE = 0
INPUT_KEYBOARD = 1

# Mouse flags
MOUSEEVENTF_MOVE = 0x0001
MOUSEEVENTF_LEFTDOWN = 0x0002
MOUSEEVENTF_LEFTUP = 0x0004
MOUSEEVENTF_RIGHTDOWN = 0x0008
MOUSEEVENTF_RIGHTUP = 0x0010
MOUSEEVENTF_MIDDLEDOWN = 0x0020
MOUSEEVENTF_MIDDLEUP = 0x0040
MOUSEEVENTF_WHEEL = 0x0800
MOUSEEVENTF_ABSOLUTE = 0x8000

# Keyboard flags
KEYEVENTF_EXTENDEDKEY = 0x0001
KEYEVENTF_KEYUP = 0x0002
KEYEVENTF_UNICODE = 0x0004
KEYEVENTF_SCANCODE = 0x0008

# Common VK codes
VK_MAP = {
    "backspace": 0x08,
    "tab": 0x09,
    "enter": 0x0D,
    "shift": 0x10,
    "control": 0x11,
    "ctrl": 0x11,
    "alt": 0x12,
    "pause": 0x13,
    "capslock": 0x14,
    "escape": 0x1B,
    "esc": 0x1B,
    "space": 0x20,
    "pageup": 0x21,
    "pagedown": 0x22,
    "end": 0x23,
    "home": 0x24,
    "left": 0x25,
    "up": 0x26,
    "right": 0x27,
    "down": 0x28,
    "arrowup": 0x26,
    "arrowdown": 0x28,
    "arrowleft": 0x25,
    "arrowright": 0x27,
    "printscreen": 0x2C,
    "prtscn": 0x2C,
    "insert": 0x2D,
    "delete": 0x2E,
    "del": 0x2E,
    "pgup": 0x21,
    "pgdn": 0x22,
    "volumeup": 0xAF,
    "volumedown": 0xAE,
    "volumemute": 0xAD,
    "win": 0x5B,
    "meta": 0x5B,
    "f1": 0x70, "f2": 0x71, "f3": 0x72, "f4": 0x73,
    "f5": 0x74, "f6": 0x75, "f7": 0x76, "f8": 0x77,
    "f9": 0x78, "f10": 0x79, "f11": 0x7A, "f12": 0x7B,
}

# Structures
class MOUSEINPUT(ctypes.Structure):
    _fields_ = [
        ("dx", ctypes.c_long),
        ("dy", ctypes.c_long),
        ("mouseData", ctypes.c_ulong),
        ("dwFlags", ctypes.c_ulong),
        ("time", ctypes.c_ulong),
        ("dwExtraInfo", ctypes.c_void_p),
    ]

class KEYBDINPUT(ctypes.Structure):
    _fields_ = [
        ("wVk", ctypes.c_ushort),
        ("wScan", ctypes.c_ushort),
        ("dwFlags", ctypes.c_ulong),
        ("time", ctypes.c_ulong),
        ("dwExtraInfo", ctypes.c_void_p),
    ]

class HARDWAREINPUT(ctypes.Structure):
    _fields_ = [
        ("uMsg", ctypes.c_ulong),
        ("wParamL", ctypes.c_ushort),
        ("wParamH", ctypes.c_ushort),
    ]

class INPUT(ctypes.Structure):
    class _INPUT_UNION(ctypes.Union):
        _fields_ = [
            ("mi", MOUSEINPUT),
            ("ki", KEYBDINPUT),
            ("hi", HARDWAREINPUT),
        ]
    _anonymous_ = ("_u",)
    _fields_ = [
        ("type", ctypes.c_ulong),
        ("_u", _INPUT_UNION),
    ]


class InputInjector:
    def __init__(self, screen_width=1920, screen_height=1080):
        attach_to_desktop()
        self.screen_width = screen_width
        self.screen_height = screen_height

    def update_screen_size(self, width, height):
        self.screen_width = width
        self.screen_height = height

    def get_cursor_pos(self):
        attach_to_desktop()
        pt = ctypes.wintypes.POINT()
        u32.GetCursorPos(ctypes.byref(pt))
        return pt.x, pt.y

    def mouse_move_abs(self, norm_x, norm_y):
        """Move cursor to normalized coordinate (0.0 - 1.0)."""
        attach_to_desktop()
        pixel_x = int(norm_x * self.screen_width)
        pixel_y = int(norm_y * self.screen_height)
        pixel_x = max(0, min(self.screen_width - 1, pixel_x))
        pixel_y = max(0, min(self.screen_height - 1, pixel_y))
        u32.SetCursorPos(pixel_x, pixel_y)

    def mouse_move_rel(self, dx, dy):
        """Move cursor relative to current position (for trackpad mode)."""
        attach_to_desktop()
        cur_x, cur_y = self.get_cursor_pos()
        new_x = max(0, min(self.screen_width - 1, cur_x + int(dx)))
        new_y = max(0, min(self.screen_height - 1, cur_y + int(dy)))
        u32.SetCursorPos(new_x, new_y)

    def mouse_button(self, button="left", action="click"):
        """
        button: 'left', 'right', 'middle'
        action: 'down', 'up', 'click', 'dblclick'
        """
        attach_to_desktop()
        down_flag = {
            "left": MOUSEEVENTF_LEFTDOWN,
            "right": MOUSEEVENTF_RIGHTDOWN,
            "middle": MOUSEEVENTF_MIDDLEDOWN,
        }.get(button, MOUSEEVENTF_LEFTDOWN)

        up_flag = {
            "left": MOUSEEVENTF_LEFTUP,
            "right": MOUSEEVENTF_RIGHTUP,
            "middle": MOUSEEVENTF_MIDDLEUP,
        }.get(button, MOUSEEVENTF_LEFTUP)

        if action == "down":
            u32.mouse_event(down_flag, 0, 0, 0, 0)
        elif action == "up":
            u32.mouse_event(up_flag, 0, 0, 0, 0)
        elif action == "click":
            u32.mouse_event(down_flag, 0, 0, 0, 0)
            time.sleep(0.01)
            u32.mouse_event(up_flag, 0, 0, 0, 0)
        elif action == "dblclick":
            u32.mouse_event(down_flag, 0, 0, 0, 0)
            time.sleep(0.01)
            u32.mouse_event(up_flag, 0, 0, 0, 0)
            time.sleep(0.05)
            u32.mouse_event(down_flag, 0, 0, 0, 0)
            time.sleep(0.01)
            u32.mouse_event(up_flag, 0, 0, 0, 0)

    def mouse_wheel(self, delta_y):
        """Scroll vertical wheel."""
        attach_to_desktop()
        # Windows standard wheel increment is 120
        delta = int(delta_y)
        u32.mouse_event(MOUSEEVENTF_WHEEL, 0, 0, delta, 0)

    def key_event(self, key_name, action="down"):
        """Press or release a virtual key."""
        attach_to_desktop()
        key_lower = key_name.lower()
        vk = VK_MAP.get(key_lower)
        if vk is None and len(key_lower) == 1:
            vk = u32.VkKeyScanW(ord(key_lower)) & 0xFF

        if vk:
            flags = KEYEVENTF_KEYUP if action == "up" else 0
            u32.keybd_event(vk, 0, flags, 0)

    def type_unicode_text(self, text):
        """Types full Unicode text (supports Vietnamese, symbols, accents)."""
        attach_to_desktop()
        for char in text:
            # Key down
            inp_down = INPUT(
                type=INPUT_KEYBOARD,
                ki=KEYBDINPUT(
                    wVk=0,
                    wScan=ord(char),
                    dwFlags=KEYEVENTF_UNICODE,
                    time=0,
                    dwExtraInfo=None,
                ),
            )
            # Key up
            inp_up = INPUT(
                type=INPUT_KEYBOARD,
                ki=KEYBDINPUT(
                    wVk=0,
                    wScan=ord(char),
                    dwFlags=KEYEVENTF_UNICODE | KEYEVENTF_KEYUP,
                    time=0,
                    dwExtraInfo=None,
                ),
            )
            u32.SendInput(1, ctypes.byref(inp_down), ctypes.sizeof(INPUT))
            u32.SendInput(1, ctypes.byref(inp_up), ctypes.sizeof(INPUT))

    def trigger_shortcut(self, shortcut):
        """Executes combinations like 'ctrl+c', 'win+d', 'alt+tab'."""
        keys = [k.strip().lower() for k in shortcut.split("+")]
        for k in keys:
            self.key_event(k, "down")
        time.sleep(0.03)
        for k in reversed(keys):
            self.key_event(k, "up")

    def get_clipboard_text(self) -> str:
        """Reads unicode text from Windows clipboard."""
        if not HAS_WIN32_CLIP:
            return ""
        try:
            attach_to_desktop()
            win32clipboard.OpenClipboard()
            try:
                if win32clipboard.IsClipboardFormatAvailable(win32con.CF_UNICODETEXT):
                    return win32clipboard.GetClipboardData(win32con.CF_UNICODETEXT) or ""
                return ""
            finally:
                win32clipboard.CloseClipboard()
        except Exception as e:
            print(f"[InputInjector] Clipboard read error: {e}")
            return ""

    def set_clipboard_text(self, text: str) -> bool:
        """Sets unicode text to Windows clipboard."""
        if not HAS_WIN32_CLIP:
            return False
        try:
            attach_to_desktop()
            win32clipboard.OpenClipboard()
            try:
                win32clipboard.EmptyClipboard()
                win32clipboard.SetClipboardData(win32con.CF_UNICODETEXT, text)
                return True
            finally:
                win32clipboard.CloseClipboard()
        except Exception as e:
            print(f"[InputInjector] Clipboard write error: {e}")
            return False

    def system_action(self, action: str):
        """Executes system actions like lock, task manager, power options."""
        attach_to_desktop()
        act = action.lower()
        if act == "lock":
            u32.LockWorkStation()
        elif act in ["task_manager", "taskmgr"]:
            self.trigger_shortcut("ctrl+shift+escape")
        elif act == "file_explorer":
            self.trigger_shortcut("win+e")
        elif act == "run_dialog":
            self.trigger_shortcut("win+r")
        elif act == "close_window":
            self.trigger_shortcut("alt+f4")
        elif act == "switch_window":
            self.trigger_shortcut("alt+tab")
        elif act == "privacy_on":
            # Turn off physical monitor (sleep)
            u32.SendMessageW(0xFFFF, 0x0112, 0xF170, 2)
        elif act == "privacy_off":
            # Wake physical monitor
            u32.SendMessageW(0xFFFF, 0x0112, 0xF170, -1)
        elif act == "reboot":
            subprocess.Popen("shutdown /r /t 5", shell=True)
        elif act == "shutdown":
            subprocess.Popen("shutdown /s /t 5", shell=True)
        elif act == "cancel_shutdown":
            subprocess.Popen("shutdown /a", shell=True)
