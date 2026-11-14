"""
Helper to ensure background threads and processes can interact with
the active Windows desktop (winsta0\\default) for screen capture and SendInput.
"""
import ctypes
import ctypes.wintypes

u32 = ctypes.windll.user32
k32 = ctypes.windll.kernel32

def attach_to_desktop():
    """Attaches the current process and thread to the active user desktop."""
    try:
        hwinsta = u32.OpenWindowStationW("winsta0", False, 0x10000000)
        if hwinsta:
            u32.SetProcessWindowStation(hwinsta)
        hdesk = u32.OpenDesktopW("default", 0, False, 0x10000000)
        if hdesk:
            u32.SetThreadDesktop(hdesk)
        return True
    except Exception as e:
        print(f"[DesktopAttach] Warning: {e}")
        return False
