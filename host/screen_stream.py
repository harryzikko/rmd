"""
Screen Capture Video Track for aiortc WebRTC Streaming.
Captures screen at ~30 FPS, draws cursor, and yields av.VideoFrame.
"""
import asyncio
import time
from fractions import Fraction
import cv2
import mss
import numpy as np
import av
from aiortc import VideoStreamTrack
from aiortc.mediastreams import MediaStreamError
from host.desktop_attach import attach_to_desktop
from host.input_injector import InputInjector


class ScreenVideoTrack(VideoStreamTrack):
    """A WebRTC video track that streams the local Windows desktop."""

    kind = "video"

    def __init__(self, target_fps=30, scale_width=1280, scale_height=720):
        super().__init__()
        attach_to_desktop()
        self.target_fps = target_fps
        self.sct = mss.MSS()
        self.monitor = self.sct.monitors[1] # Primary monitor
        self.orig_width = self.monitor["width"]
        self.orig_height = self.monitor["height"]

        self.scale_width = scale_width if scale_width else self.orig_width
        self.scale_height = scale_height if scale_height else self.orig_height

        self.injector = InputInjector(self.orig_width, self.orig_height)
        self.running = True
        self.last_frame = None

        # Precompute cursor polygon shape
        self.cursor_poly = np.array(
            [[0, 0], [0, 18], [5, 14], [9, 23], [13, 21], [9, 13], [16, 13]],
            dtype=np.int32,
        )

    def draw_cursor(self, img_bgr):
        """Draws the mouse cursor onto the raw frame before scaling."""
        try:
            cx, cy = self.injector.get_cursor_pos()
            poly = self.cursor_poly + [cx, cy]
            cv2.fillPoly(img_bgr, [poly], (255, 255, 255))
            cv2.polylines(img_bgr, [poly], True, (0, 0, 0), 1, cv2.LINE_AA)
        except Exception:
            pass

    async def recv(self):
        """Captures a frame and yields it to the WebRTC peer."""
        if not self.running:
            raise MediaStreamError

        # Use aiortc's built-in timestamp and pacing calculator
        pts, time_base = await self.next_timestamp()

        try:
            # Capture desktop frame
            raw = np.array(self.sct.grab(self.monitor)) # BGRA
            bgr = raw[:, :, :3] # Drop alpha channel -> BGR

            # Draw mouse pointer
            self.draw_cursor(bgr)

            # Scale down if requested
            if (self.scale_width, self.scale_height) != (self.orig_width, self.orig_height):
                frame_img = cv2.resize(
                    bgr, (self.scale_width, self.scale_height), interpolation=cv2.INTER_LINEAR
                )
            else:
                frame_img = bgr

            self.last_frame = frame_img
        except Exception:
            if self.last_frame is not None:
                frame_img = self.last_frame
            else:
                frame_img = np.zeros((self.scale_height, self.scale_width, 3), dtype=np.uint8)

        # Convert to VideoFrame
        video_frame = av.VideoFrame.from_ndarray(frame_img, format="bgr24")
        video_frame.pts = pts
        video_frame.time_base = time_base

        return video_frame

    def stop(self):
        self.running = False
        super().stop()
