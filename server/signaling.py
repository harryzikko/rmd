"""
Signaling & Web Server for Remote Desktop.
Supports both WebRTC negotiation and High-Speed WebSocket Direct Streaming (for 4G/WAN).
"""
import os
import json
import time
import asyncio
import threading
import logging
import cv2
import mss
import numpy as np
from aiohttp import web
from host.host_service import HostService
from host.desktop_attach import attach_to_desktop

logger = logging.getLogger("SignalingServer")

class SignalingServer:
    def __init__(self, host_id: str, passcode: str, host_service: HostService, static_dir: str):
        self.host_id = host_id.replace(" ", "")
        self.passcode = passcode
        self.host_service = host_service
        self.static_dir = static_dir
        self.app = web.Application()
        self.cursor_poly = np.array(
            [[0, 0], [0, 26], [7, 20], [12, 31], [16, 29], [11, 18], [20, 18]],
            dtype=np.int32,
        )
        self._setup_routes()

    def _setup_routes(self):
        self.app.router.add_get("/api/info", self._handle_info)
        self.app.router.add_post("/api/connect", self._handle_connect)
        self.app.router.add_get("/ws/stream", self._handle_ws_stream)
        self.app.router.add_get("/download/app.apk", self._handle_download_apk)
        self.app.router.add_get("/download/app.ipa", self._handle_download_ipa)
        self.app.router.add_get("/favicon.ico", self._handle_favicon)
        self.app.router.add_get("/", self._handle_index)
        self.app.router.add_get("/index.html", self._handle_index)
        # Static assets (style.css, app.js, icons)
        self.app.router.add_static("/", path=self.static_dir)

    async def _handle_download_apk(self, request):
        apk_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            "mobile_flutter", "build", "app", "outputs", "flutter-apk", "app-release.apk"
        )
        if os.path.exists(apk_path):
            return web.FileResponse(
                apk_path,
                headers={
                    "Content-Disposition": 'attachment; filename="HybridRemoteDesktop.apk"',
                    "Content-Type": "application/vnd.android.package-archive"
                }
            )
        return web.Response(text="APK đang được biên dịch hoặc không tìm thấy.", status=404)

    async def _handle_download_ipa(self, request):
        ipa_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            "mobile_flutter", "HybridRemote-Unsigned.ipa"
        )
        if os.path.exists(ipa_path):
            return web.FileResponse(
                ipa_path,
                headers={
                    "Content-Disposition": 'attachment; filename="HybridRemote-Unsigned.ipa"',
                    "Content-Type": "application/octet-stream"
                }
            )
        # Chuyển hướng tới link tải trực tiếp trên GitHub raw
        raise web.HTTPFound("https://github.com/harryzikko/rmd/raw/ipa/HybridRemote-Unsigned.ipa")

    async def _handle_favicon(self, request):
        return web.Response(status=204)

    async def _handle_index(self, request):
        index_file = os.path.join(self.static_dir, "index.html")
        return web.FileResponse(index_file)

    async def _handle_info(self, request):
        return web.json_response({
            "host_id": self.host_id,
            "connected_peers": len(self.host_service.pcs),
        })

    async def _handle_connect(self, request):
        try:
            data = await request.json()
            req_id = str(data.get("id", "")).replace(" ", "")
            req_passcode = str(data.get("passcode", "")).strip()
            sdp = data.get("sdp")
            sdp_type = data.get("type", "offer")

            # Check credentials
            if req_id != self.host_id:
                return web.json_response({"error": "ID máy tính không đúng!"}, status=403)

            if req_passcode != self.passcode:
                return web.json_response({"error": "Mật khẩu không chính xác!"}, status=403)

            if not sdp:
                return web.json_response({"error": "Thiếu dữ liệu SDP Offer!"}, status=400)

            logger.info("Credentials verified! Negotiating WebRTC peer connection...")
            answer = await self.host_service.handle_offer(sdp, sdp_type)
            return web.json_response(answer)

        except Exception as e:
            logger.error(f"Signaling error: {e}")
            return web.json_response({"error": str(e)}, status=500)

    async def _handle_ws_stream(self, request):
        """
        High-performance WebSocket screen streaming and input channel.
        Bypasses WebRTC NAT/CGNAT/UDP issues over 4G/WAN.
        """
        ws = web.WebSocketResponse(max_msg_size=10 * 1024 * 1024)
        await ws.prepare(request)

        req_id = request.query.get("id", "").replace(" ", "")
        req_pwd = request.query.get("pwd", "").strip()

        if req_id != self.host_id or req_pwd != self.passcode:
            await ws.send_json({"error": "ID hoặc Mật khẩu không chính xác!"})
            await ws.close()
            return ws

        logger.info("WebSocket Client authenticated! Starting real-time stream...")
        attach_to_desktop()

        async def receive_inputs():
            try:
                async for msg in ws:
                    if msg.type == web.WSMsgType.TEXT:
                        try:
                            data = json.loads(msg.data)
                            self.host_service._process_input(data)
                        except Exception as e:
                            logger.error(f"Input parse error: {e}")
                    elif msg.type in [web.WSMsgType.CLOSE, web.WSMsgType.ERROR]:
                        break
            except Exception:
                pass

        stop_worker = threading.Event()
        latest_jpeg = None
        new_frame_event = asyncio.Event()
        loop = asyncio.get_running_loop()

        def capture_worker():
            attach_to_desktop()
            sct = mss.MSS()
            monitor = sct.monitors[1]
            orig_w = monitor["width"]
            orig_h = monitor["height"]
            scale_w = 1280
            scale_h = 720
            mon_l = monitor.get("left", 0)
            mon_t = monitor.get("top", 0)
            target_delay = 1.0 / 25.0

            while not stop_worker.is_set():
                t0 = time.time()
                try:
                    raw = np.array(sct.grab(monitor)) # BGRA
                    bgr = raw[:, :, :3]

                    # Scale down
                    if (scale_w, scale_h) != (orig_w, orig_h):
                        frame = cv2.resize(bgr, (scale_w, scale_h), interpolation=cv2.INTER_LINEAR)
                    else:
                        frame = bgr

                    # Draw prominent, high-contrast mouse cursor AFTER resizing
                    try:
                        cx, cy = self.host_service.injector.get_cursor_pos()
                        cur_x = int((cx - mon_l) * scale_w / orig_w)
                        cur_y = int((cy - mon_t) * scale_h / orig_h)

                        if 0 <= cur_x < scale_w and 0 <= cur_y < scale_h:
                            poly = self.cursor_poly + [cur_x, cur_y]
                            # Drop shadow
                            cv2.fillPoly(frame, [self.cursor_poly + [cur_x + 2, cur_y + 2]], (20, 20, 20))
                            # 3px high-contrast black border
                            cv2.polylines(frame, [poly], True, (0, 0, 0), 3, cv2.LINE_AA)
                            # Bright white fill
                            cv2.fillPoly(frame, [poly], (255, 255, 255))
                            # Yellow accent tip dot
                            cv2.circle(frame, (cur_x, cur_y), 3, (0, 255, 255), -1)
                    except Exception:
                        pass

                    # Compress to JPEG (Quality: 55 - low bandwidth, fast delivery, zero lag)
                    success, jpeg_data = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 55])
                    if success:
                        nonlocal latest_jpeg
                        latest_jpeg = jpeg_data.tobytes()
                        loop.call_soon_threadsafe(new_frame_event.set)

                except Exception as e:
                    logger.debug(f"Frame capture error: {e}")

                elapsed = time.time() - t0
                rem = target_delay - elapsed
                if rem > 0:
                    time.sleep(rem)
                else:
                    time.sleep(0.001)

        worker_thread = threading.Thread(target=capture_worker, daemon=True)
        worker_thread.start()

        async def stream_screen():
            try:
                while not ws.closed:
                    await new_frame_event.wait()
                    new_frame_event.clear()
                    frame_bytes = latest_jpeg
                    if frame_bytes and not ws.closed:
                        await ws.send_bytes(frame_bytes)
            finally:
                stop_worker.set()

        input_task = asyncio.create_task(receive_inputs())
        stream_task = asyncio.create_task(stream_screen())

        done, pending = await asyncio.wait(
            [input_task, stream_task],
            return_when=asyncio.FIRST_COMPLETED,
        )

        for task in pending:
            task.cancel()

        logger.info("WebSocket Client disconnected.")
        return ws
