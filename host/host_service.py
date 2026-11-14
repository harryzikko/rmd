"""
WebRTC Host Service.
Manages peer connections, video streaming tracks, and incoming input commands.
"""
import asyncio
import json
import logging
from aiortc import RTCPeerConnection, RTCSessionDescription, RTCConfiguration, RTCIceServer
from host.screen_stream import ScreenVideoTrack
from host.input_injector import InputInjector

logger = logging.getLogger("HostService")

class HostService:
    def __init__(self, target_fps=30, scale_width=1280, scale_height=720):
        self.target_fps = target_fps
        self.scale_width = scale_width
        self.scale_height = scale_height
        self.pcs = set()
        self.injector = InputInjector()

    async def handle_offer(self, sdp: str, sdp_type: str):
        """Processes an incoming WebRTC offer from mobile client."""
        config = RTCConfiguration(
            iceServers=[
                RTCIceServer(urls=[
                    "stun:stun.l.google.com:19302",
                    "stun:stun1.l.google.com:19302",
                    "stun:stun2.l.google.com:19302",
                    "stun:stun.cloudflare.com:3478",
                ])
            ]
        )
        pc = RTCPeerConnection(configuration=config)
        self.pcs.add(pc)

        # Dedicated video track for this connection
        track = ScreenVideoTrack(
            target_fps=self.target_fps,
            scale_width=self.scale_width,
            scale_height=self.scale_height,
        )
        pc.addTrack(track)

        # Listen for DataChannel (created by viewer for input commands)
        @pc.on("datachannel")
        def on_datachannel(channel):
            logger.info(f"DataChannel established: {channel.label}")

            @channel.on("message")
            def on_message(message):
                try:
                    data = json.loads(message)
                    self._process_input(data)
                except Exception as e:
                    logger.error(f"Error handling input: {e}")

        @pc.on("connectionstatechange")
        async def on_state_change():
            logger.info(f"Connection state changed: {pc.connectionState}")
            if pc.connectionState in ["failed", "closed"]:
                track.stop()
                await pc.close()
                self.pcs.discard(pc)

        # Apply remote offer
        offer = RTCSessionDescription(sdp=sdp, type=sdp_type)
        await pc.setRemoteDescription(offer)

        # Defensive check: Ensure any transceiver has a valid _offerDirection to prevent 'None is not in list'
        for t in pc.getTransceivers():
            if t._offerDirection is None:
                t._offerDirection = "recvonly"

        # Create answer
        answer = await pc.createAnswer()
        await pc.setLocalDescription(answer)

        # Wait briefly for local ICE candidates to populate SDP
        for _ in range(25):
            if pc.iceGatheringState == "complete":
                break
            await asyncio.sleep(0.05)

        return {
            "sdp": pc.localDescription.sdp,
            "type": pc.localDescription.type,
        }

    def _process_input(self, data: dict):
        """Translates incoming DataChannel payload to Windows input events."""
        event_type = data.get("type")

        if event_type == "mouse_move_abs":
            x = float(data.get("x", 0))
            y = float(data.get("y", 0))
            self.injector.mouse_move_abs(x, y)

        elif event_type == "mouse_move_rel":
            dx = float(data.get("dx", 0))
            dy = float(data.get("dy", 0))
            self.injector.mouse_move_rel(dx, dy)

        elif event_type == "mouse_button":
            btn = data.get("button", "left")
            act = data.get("action", "click")
            self.injector.mouse_button(btn, act)

        elif event_type == "mouse_wheel":
            delta_y = float(data.get("delta_y", 0))
            self.injector.mouse_wheel(delta_y)

        elif event_type == "key_event":
            key = data.get("key", "")
            act = data.get("action", "down")
            if key:
                self.injector.key_event(key, act)

        elif event_type == "type_text":
            text = data.get("text", "")
            if text:
                self.injector.type_unicode_text(text)

        elif event_type == "shortcut":
            sc = data.get("shortcut", "")
            if sc:
                self.injector.trigger_shortcut(sc)

    async def close_all(self):
        """Shuts down all active peer connections."""
        for pc in list(self.pcs):
            await pc.close()
        self.pcs.clear()
