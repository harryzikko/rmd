/**
 * Remote Desktop Web Client (WebSocket Direct Stream Engine)
 * High performance, zero UDP drops, works 100% over 4G/WAN/Cloudflare Tunnel.
 */

let ws = null;
let controlMode = "trackpad"; // "trackpad" or "touch"
let currentHostId = "";
let currentPasscode = "";

// Virtual cursor position for trackpad mode
let cursorX = window.innerWidth / 2;
let cursorY = window.innerHeight / 2;

// Elements
const connectOverlay = document.getElementById("connectOverlay");
const statusMsg = document.getElementById("statusMsg");
const remoteScreen = document.getElementById("remoteScreen");
const touchSurface = document.getElementById("touchSurface");
const virtualCursor = document.getElementById("virtualCursor");
const toolbarPanel = document.getElementById("toolbarPanel");
const keyboardDrawer = document.getElementById("keyboardDrawer");
const badgeInfo = document.getElementById("badgeInfo");

// Parse URL params for auto-fill and auto-connect
window.addEventListener("DOMContentLoaded", () => {
  const urlParams = new URLSearchParams(window.location.search);
  const idParam = urlParams.get("id");
  const pwdParam = urlParams.get("pwd");

  if (idParam) document.getElementById("hostIdInput").value = idParam;
  if (pwdParam) document.getElementById("passcodeInput").value = pwdParam;

  if (idParam && pwdParam) {
    startConnect();
  }
});

// UI Toggles
function toggleToolbar() {
  toolbarPanel.style.display = toolbarPanel.style.display === "flex" ? "none" : "flex";
}

function toggleKeyboard() {
  keyboardDrawer.style.display = keyboardDrawer.style.display === "flex" ? "none" : "flex";
}

function setMode(mode) {
  controlMode = mode;
  document.getElementById("btnModeTrackpad").classList.toggle("active", mode === "trackpad");
  document.getElementById("btnModeTouch").classList.toggle("active", mode === "touch");
  virtualCursor.style.display = "none"; // Host already draws the real Windows cursor
}

function toggleFullscreen() {
  if (!document.fullscreenElement) {
    document.documentElement.requestFullscreen().catch(() => {});
  } else {
    document.exitFullscreen().catch(() => {});
  }
}

// WebSocket Direct Streaming
async function startConnect() {
  const hostId = document.getElementById("hostIdInput").value.trim().replace(/\s+/g, "");
  const passcode = document.getElementById("passcodeInput").value.trim();

  if (!hostId || !passcode) {
    statusMsg.innerText = "Vui lòng nhập đầy đủ ID và Mật khẩu!";
    return;
  }

  currentHostId = hostId;
  currentPasscode = passcode;
  statusMsg.innerText = "Đang kết nối tới máy chủ...";

  try {
    const proto = window.location.protocol === "https:" ? "wss://" : "ws://";
    const wsUrl = `${proto}${window.location.host}/ws/stream?id=${encodeURIComponent(hostId)}&pwd=${encodeURIComponent(passcode)}`;

    if (ws) {
      ws.close();
    }

    ws = new WebSocket(wsUrl);
    ws.binaryType = "blob";

    let prevBlobUrl = null;

    ws.onopen = () => {
      console.log("WebSocket connection established!");
      connectOverlay.style.display = "none";
      badgeInfo.style.display = "block";
      badgeInfo.innerText = `Connected: ${hostId}`;
      setMode("trackpad");
    };

    ws.onmessage = (event) => {
      if (typeof event.data === "string") {
        try {
          const msg = JSON.parse(event.data);
          if (msg.error) {
            statusMsg.innerText = msg.error;
            disconnectSession(msg.error);
          }
        } catch (e) {}
      } else {
        // High-speed binary JPEG frame from desktop capture
        const blobUrl = URL.createObjectURL(event.data);
        remoteScreen.onload = () => {
          if (prevBlobUrl) {
            URL.revokeObjectURL(prevBlobUrl);
          }
          prevBlobUrl = blobUrl;
        };
        remoteScreen.src = blobUrl;
      }
    };

    ws.onerror = (err) => {
      console.error("WebSocket error:", err);
      statusMsg.innerText = "Lỗi kết nối WebSocket!";
    };

    ws.onclose = () => {
      disconnectSession("Đã ngắt kết nối.");
    };

  } catch (err) {
    console.error("Connect error:", err);
    statusMsg.innerText = "Lỗi kết nối: " + err.message;
  }
}

function sendInput(payload) {
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(payload));
  }
}

function disconnectSession(reason = "Đã ngắt kết nối") {
  if (ws) ws.close();
  connectOverlay.style.display = "flex";
  statusMsg.innerText = reason;
  badgeInfo.style.display = "none";
  toolbarPanel.style.display = "none";
  keyboardDrawer.style.display = "none";
}

// ----------------- Touch Gesture & Input Handling -----------------
let touchStartX = 0;
let touchStartY = 0;
let touchStartTime = 0;
let isTwoFingerScroll = false;
let lastTouchY = 0;
let lastTouchX = 0;

touchSurface.addEventListener("touchstart", (e) => {
  touchStartTime = Date.now();

  if (e.touches.length === 1) {
    const t = e.touches[0];
    touchStartX = t.clientX;
    touchStartY = t.clientY;
    lastTouchX = t.clientX;
    lastTouchY = t.clientY;

    if (controlMode === "touch") {
      sendAbsoluteMove(t);
      sendInput({ type: "mouse_button", button: "left", action: "down" });
    }
  } else if (e.touches.length === 2) {
    isTwoFingerScroll = true;
    lastTouchY = (e.touches[0].clientY + e.touches[1].clientY) / 2;
  }
}, { passive: false });

touchSurface.addEventListener("touchmove", (e) => {
  e.preventDefault();

  if (e.touches.length === 1) {
    const t = e.touches[0];
    const dx = t.clientX - lastTouchX;
    const dy = t.clientY - lastTouchY;
    lastTouchX = t.clientX;
    lastTouchY = t.clientY;

    if (controlMode === "trackpad") {
      // Relative trackpad movement with smooth acceleration
      const speed = 1.35;
      sendInput({
        type: "mouse_move_rel",
        dx: dx * speed,
        dy: dy * speed,
      });

      // Update local virtual cursor
      cursorX = Math.max(0, Math.min(window.innerWidth, cursorX + dx * speed));
      cursorY = Math.max(0, Math.min(window.innerHeight, cursorY + dy * speed));
      virtualCursor.style.left = `${cursorX}px`;
      virtualCursor.style.top = `${cursorY}px`;
    } else {
      // Direct touch mode
      sendAbsoluteMove(t);
    }
  } else if (e.touches.length === 2 && isTwoFingerScroll) {
    const currentY = (e.touches[0].clientY + e.touches[1].clientY) / 2;
    const deltaY = currentY - lastTouchY;
    lastTouchY = currentY;

    // Scroll vertical wheel (Windows delta 120 per notch)
    sendInput({
      type: "mouse_wheel",
      delta_y: deltaY * 8,
    });
  }
}, { passive: false });

touchSurface.addEventListener("touchend", (e) => {
  const duration = Date.now() - touchStartTime;

  if (controlMode === "touch") {
    sendInput({ type: "mouse_button", button: "left", action: "up" });
  } else if (controlMode === "trackpad") {
    // Detect tap
    if (e.touches.length === 0) {
      if (duration < 250) {
        // Quick tap: left click
        sendInput({ type: "mouse_button", button: "left", action: "click" });
      }
      isTwoFingerScroll = false;
    } else if (e.touches.length === 1 && isTwoFingerScroll && duration < 300) {
      // Two finger tap: right click
      sendInput({ type: "mouse_button", button: "right", action: "click" });
      isTwoFingerScroll = false;
    }
  }
});

function getRenderedScreenRect() {
  const img = document.getElementById("remoteScreen");
  const rect = img.getBoundingClientRect();
  const naturalW = img.naturalWidth || 1280;
  const naturalH = img.naturalHeight || 720;
  const imageAR = naturalW / naturalH;
  const elementAR = rect.width / (rect.height || 1);

  let renderW, renderH, offsetX, offsetY;

  if (elementAR > imageAR) {
    renderH = rect.height;
    renderW = rect.height * imageAR;
    offsetX = rect.left + (rect.width - renderW) / 2;
    offsetY = rect.top;
  } else {
    renderW = rect.width;
    renderH = rect.width / imageAR;
    offsetX = rect.left;
    offsetY = rect.top + (rect.height - renderH) / 2;
  }

  return { renderW, renderH, offsetX, offsetY };
}

function sendAbsoluteMove(touch) {
  const { renderW, renderH, offsetX, offsetY } = getRenderedScreenRect();
  const relX = (touch.clientX - offsetX) / renderW;
  const relY = (touch.clientY - offsetY) / renderH;

  const clampedX = Math.max(0, Math.min(1, relX));
  const clampedY = Math.max(0, Math.min(1, relY));

  sendInput({
    type: "mouse_move_abs",
    x: clampedX,
    y: clampedY,
  });
}

// Button controls (left / right / double click)
function sendClick(button) {
  sendInput({ type: "mouse_button", button: button, action: "click" });
}

function sendDblClick() {
  sendInput({ type: "mouse_button", button: "left", action: "dblclick" });
}

// Keyboard and Shortcuts
function sendKey(keyName) {
  sendInput({ type: "key_event", key: keyName, action: "down" });
  setTimeout(() => {
    sendInput({ type: "key_event", key: keyName, action: "up" });
  }, 30);
}

function sendShortcut(shortcut) {
  sendInput({ type: "shortcut", shortcut: shortcut });
}

function sendTypedText() {
  const input = document.getElementById("kbTextInput");
  const text = input.value;
  if (text) {
    sendInput({ type: "type_text", text: text });
    input.value = "";
  }
}
