"""
Main Launcher for Hybrid Remote Desktop Host & Signaling Server.
Uses persistent device credentials from config.json and provides Cloudflare Tunnel.
"""
import os
import sys
import time
import socket
import json
import random
import re
import subprocess
import threading
import logging
import qrcode
from aiohttp import web
from host.host_service import HostService
from server.signaling import SignalingServer

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("Launcher")

CLOUDFLARED_PATH = r"C:\Program Files (x86)\cloudflared\cloudflared.exe"
CONFIG_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "config.json")

def load_or_create_credentials():
    """Loads persistent ID and PIN from config.json, or creates new ones."""
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
                if "device_id" in data and "passcode" in data:
                    return str(data["device_id"]), str(data["passcode"])
        except Exception:
            pass

    # Default if missing
    dev_id = f"{random.randint(100, 999)} {random.randint(100, 999)} {random.randint(100, 999)}"
    pin = f"{random.randint(1000, 9999)}"
    try:
        with open(CONFIG_PATH, "w", encoding="utf-8") as f:
            json.dump({"device_id": dev_id, "passcode": pin}, f, indent=2)
    except Exception:
        pass
    return dev_id, pin

def get_lan_ip():
    """Detects primary local LAN IPv4 address."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
    except Exception:
        ip = "127.0.0.1"
    finally:
        s.close()
    return ip

def kill_process_on_port(port):
    """Kills any orphaned process occupying our target port."""
    try:
        output = subprocess.check_output(
            f"powershell -NoProfile -Command \"(Get-NetTCPConnection -LocalPort {port} -State Listen -ErrorAction SilentlyContinue).OwningProcess\"",
            shell=True,
            text=True,
            stderr=subprocess.DEVNULL
        ).strip()
        if output:
            for pid_str in output.split():
                pid = int(pid_str)
                if pid != os.getpid():
                    logger.info(f"Đang giải phóng cổng {port} (dừng tiến trình cũ PID {pid})...")
                    subprocess.call(f"taskkill /F /PID {pid}", shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            time.sleep(0.5)
    except Exception:
        pass

def start_cloudflared_tunnel(local_port=8000):
    """Starts Cloudflare Tunnel for secure Internet access (4G/5G)."""
    if not os.path.exists(CLOUDFLARED_PATH):
        return None, None

    logger.info("Đang khởi tạo đường hầm Internet (Cloudflare Tunnel)...")
    cmd = [CLOUDFLARED_PATH, "tunnel", "--url", f"http://127.0.0.1:{local_port}"]
    try:
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="ignore",
        )
        url_container = []
        event = threading.Event()

        def drain_output():
            for line in proc.stdout:
                if not event.is_set():
                    match = re.search(r"https://[a-zA-Z0-9-]+\.trycloudflare\.com", line)
                    if match:
                        url_container.append(match.group(0))
                        event.set()

        t = threading.Thread(target=drain_output, daemon=True)
        t.start()
        event.wait(timeout=12)

        return proc, (url_container[0] if url_container else None)
    except Exception as e:
        logger.warning(f"Không thể khởi động Cloudflare Tunnel: {e}")
        return None, None

def main():
    port = 8000
    kill_process_on_port(port)

    lan_ip = get_lan_ip()
    device_id, passcode = load_or_create_credentials()
    clean_id = device_id.replace(" ", "")

    # Start Cloudflare Tunnel for WAN / 4G / 5G
    tunnel_proc, tunnel_url = start_cloudflared_tunnel(port)

    # Primary connection URL (Prefer Internet HTTPS Tunnel)
    if tunnel_url:
        primary_url = f"{tunnel_url}/?id={clean_id}&pwd={passcode}"
    else:
        primary_url = f"http://{lan_ip}:{port}/?id={clean_id}&pwd={passcode}"

    lan_url = f"http://{lan_ip}:{port}/?id={clean_id}&pwd={passcode}"

    print("\n" + "=" * 65)
    print("   🚀 HYBRID REMOTE DESKTOP (Windows Host ➔ Mobile Viewer)")
    print("=" * 65)
    print(f"   📌 ID CỐ ĐỊNH (TeamViewer Style): \033[1;36m{device_id}\033[0m")
    print(f"   🔑 MẬT KHẨU PIN                : \033[1;32m{passcode}\033[0m")
    print("-" * 65)
    if tunnel_url:
        print("   🌍 KẾT NỐI TOÀN CẦU (4G / 5G / Khác Wi-Fi / Ra ngoài đường):")
        print(f"      🔗 {primary_url}")
        print("-" * 65)
    print(f"   🏠 KẾT NỐI NỘI BỘ (Chung Wi-Fi LAN):")
    print(f"      🔗 {lan_url}")
    print("=" * 65)
    print("   📱 QUÉT MÃ QR BẰNG ĐIỆN THOẠI ĐỂ ĐIỀU KHIỂN NGAY LẬP TỨC:")
    print("=" * 65 + "\n")

    # Generate and print QR code
    qr = qrcode.QRCode(box_size=1, border=2)
    qr.add_data(primary_url)
    qr.make(fit=True)
    try:
        qr.print_ascii(invert=True)
    except Exception:
        pass

    print("\n" + "=" * 65)
    print("   Đang lắng nghe kết nối... (Nhấn Ctrl+C để dừng)")
    print("=" * 65 + "\n")

    static_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "web_viewer")
    host_service = HostService(target_fps=30, scale_width=1280, scale_height=720)
    signaling = SignalingServer(
        host_id=device_id,
        passcode=passcode,
        host_service=host_service,
        static_dir=static_dir,
    )

    try:
        web.run_app(signaling.app, host="0.0.0.0", port=port, print=None)
    except KeyboardInterrupt:
        print("\nĐang tắt máy chủ...")
    except Exception as e:
        logger.error(f"Lỗi: {e}")
    finally:
        if tunnel_proc:
            try:
                tunnel_proc.terminate()
            except Exception:
                pass

if __name__ == "__main__":
    main()
