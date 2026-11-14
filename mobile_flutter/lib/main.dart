import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    title: 'Hybrid Remote Desktop',
    debugShowCheckedModeBanner: false,
    home: ConnectScreen(),
  ));
}

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _urlCtrl = TextEditingController();
  final _hostIdCtrl = TextEditingController(text: '888 666 999');
  final _pwdCtrl = TextEditingController(text: '1234');
  String _status = '';

  void _pasteFullLink() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      final text = data!.text!.trim();
      try {
        final uri = Uri.parse(text);
        final baseUrl = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
        final id = uri.queryParameters['id'] ?? '';
        final pwd = uri.queryParameters['pwd'] ?? '';

        setState(() {
          _urlCtrl.text = baseUrl;
          if (id.isNotEmpty) _hostIdCtrl.text = id;
          if (pwd.isNotEmpty) _pwdCtrl.text = pwd;
        });
      } catch (e) {
        _urlCtrl.text = text;
      }
    }
  }

  void _connect() {
    String serverUrl = _urlCtrl.text.trim();
    final hostId = _hostIdCtrl.text.trim().replaceAll(' ', '');
    final passcode = _pwdCtrl.text.trim();

    if (serverUrl.isEmpty || hostId.isEmpty || passcode.isEmpty) {
      setState(() => _status = 'Vui lòng điền đủ Đường dẫn, ID và Mật khẩu!');
      return;
    }

    // Auto-detect protocol
    if (!serverUrl.startsWith('http://') && !serverUrl.startsWith('https://')) {
      serverUrl = 'https://$serverUrl';
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RemoteViewerScreen(
          serverUrl: serverUrl,
          hostId: hostId,
          passcode: passcode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        title: const Text('Hybrid Remote Desktop'),
        backgroundColor: const Color(0xFF1A1F2C),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: Text('💻📱', style: TextStyle(fontSize: 44))),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Điều khiển Máy tính từ xa',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _urlCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Link Server / Domain / LAN IP',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: 'https://xxxx.trycloudflare.com',
                    hintStyle: const TextStyle(color: Colors.white24),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.paste, color: Colors.blueAccent),
                      tooltip: 'Dán toàn bộ link kết nối',
                      onPressed: _pasteFullLink,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _hostIdCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'ID Máy tính (9 số)',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _pwdCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Mã PIN',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A7BD5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _connect,
                  child: const Text('KẾT NỐI NGAY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                if (_status.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(_status, style: const TextStyle(color: Colors.orange, fontSize: 13), textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RemoteViewerScreen extends StatefulWidget {
  final String serverUrl;
  final String hostId;
  final String passcode;

  const RemoteViewerScreen({
    super.key,
    required this.serverUrl,
    required this.hostId,
    required this.passcode,
  });

  @override
  State<RemoteViewerScreen> createState() => _RemoteViewerScreenState();
}

class _RemoteViewerScreenState extends State<RemoteViewerScreen> {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Uint8List? _latestFrame;
  bool _connected = false;
  String _status = 'Đang kết nối...';
  String _mode = 'trackpad'; // 'trackpad' or 'touch'
  bool _showKeyboard = false;
  final _textCtrl = TextEditingController();

  // Desktop native resolution
  final double _desktopW = 1920;
  final double _desktopH = 1080;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _connectWebSocket();
  }

  void _connectWebSocket() {
    try {
      final uri = Uri.parse(widget.serverUrl);
      final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
      final portStr = uri.hasPort ? ':${uri.port}' : '';
      final wsUrl = '$wsScheme://${uri.host}$portStr/ws/stream?id=${widget.hostId}&pwd=${widget.passcode}';

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _sub = _channel!.stream.listen(
        (message) {
          if (message is Uint8List) {
            setState(() {
              _latestFrame = message;
              _connected = true;
            });
          } else if (message is List<int>) {
            setState(() {
              _latestFrame = Uint8List.fromList(message);
              _connected = true;
            });
          } else if (message is String) {
            try {
              final json = jsonDecode(message);
              if (json['error'] != null) {
                setState(() => _status = json['error']);
              }
            } catch (_) {}
          }
        },
        onError: (err) {
          setState(() => _status = 'Lỗi kết nối: $err');
        },
        onDone: () {
          setState(() => _status = 'Đã ngắt kết nối.');
        },
      );
    } catch (e) {
      setState(() => _status = 'Lỗi: $e');
    }
  }

  void _sendInput(Map<String, dynamic> data) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  /// Calculates exact letterboxed image rect inside container
  Rect _getRenderedImageRect(Size containerSize) {
    final imageAspect = _desktopW / _desktopH;
    final containerAspect = containerSize.width / containerSize.height;

    double renderW, renderH, offsetX, offsetY;

    if (containerAspect > imageAspect) {
      renderH = containerSize.height;
      renderW = containerSize.height * imageAspect;
      offsetX = (containerSize.width - renderW) / 2;
      offsetY = 0;
    } else {
      renderW = containerSize.width;
      renderH = containerSize.width / imageAspect;
      offsetX = 0;
      offsetY = (containerSize.height - renderH) / 2;
    }

    return Rect.fromLTWH(offsetX, offsetY, renderW, renderH);
  }

  void _handleDirectTouch(Offset localPos, Size containerSize, String action) {
    final imageRect = _getRenderedImageRect(containerSize);

    // Normalize touch strictly relative to image area
    final relX = (localPos.dx - imageRect.left) / imageRect.width;
    final relY = (localPos.dy - imageRect.top) / imageRect.height;

    final clampedX = relX.clamp(0.0, 1.0);
    final clampedY = relY.clamp(0.0, 1.0);

    _sendInput({
      'type': 'mouse_move_abs',
      'x': clampedX,
      'y': clampedY,
    });

    if (action.isNotEmpty) {
      _sendInput({
        'type': 'mouse_button',
        'button': 'left',
        'action': action,
      });
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _sub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Screen Stream Viewport
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final containerSize = Size(constraints.maxWidth, constraints.maxHeight);

                return Stack(
                  children: [
                    Center(
                      child: _connected && _latestFrame != null
                          ? Image.memory(
                              _latestFrame!,
                              gaplessPlayback: true,
                              fit: BoxFit.contain,
                            )
                          : Text(_status, style: const TextStyle(color: Colors.white70)),
                    ),
                    // Gesture Detector for Mouse & Touch
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanUpdate: (details) {
                          if (_mode == 'trackpad') {
                            // Relative movement with fine control (no drift)
                            _sendInput({
                              'type': 'mouse_move_rel',
                              'dx': details.delta.dx * 1.25,
                              'dy': details.delta.dy * 1.25,
                            });
                          } else {
                            // Pixel-perfect direct touch
                            _handleDirectTouch(details.localPosition, containerSize, '');
                          }
                        },
                        onTapDown: (details) {
                          if (_mode == 'touch') {
                            _handleDirectTouch(details.localPosition, containerSize, 'down');
                          }
                        },
                        onTapUp: (details) {
                          if (_mode == 'touch') {
                            _handleDirectTouch(details.localPosition, containerSize, 'up');
                          } else {
                            _sendInput({'type': 'mouse_button', 'button': 'left', 'action': 'click'});
                          }
                        },
                        onDoubleTap: () {
                          _sendInput({'type': 'mouse_button', 'button': 'left', 'action': 'dblclick'});
                        },
                        onLongPress: () {
                          _sendInput({'type': 'mouse_button', 'button': 'right', 'action': 'click'});
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Bottom Trackpad Helper Buttons
          Positioned(
            bottom: 16,
            left: 16,
            child: Row(
              children: [
                _buildMouseBtn('🖱️ Trái', () => _sendInput({'type': 'mouse_button', 'button': 'left', 'action': 'click'})),
                const SizedBox(width: 8),
                _buildMouseBtn('⚡ Nhấp đúp', () => _sendInput({'type': 'mouse_button', 'button': 'left', 'action': 'dblclick'})),
                const SizedBox(width: 8),
                _buildMouseBtn('🖱️ Phải', () => _sendInput({'type': 'mouse_button', 'button': 'right', 'action': 'click'})),
              ],
            ),
          ),

          // Top Floating Action Toolbar
          Positioned(
            top: 16,
            right: 16,
            child: Row(
              children: [
                _buildToolIcon(
                  _mode == 'trackpad' ? Icons.touch_app : Icons.mouse,
                  () => setState(() => _mode = _mode == 'trackpad' ? 'touch' : 'trackpad'),
                  tooltip: _mode == 'trackpad' ? 'Đang bật: Trackpad' : 'Đang bật: Chạm trực tiếp',
                ),
                const SizedBox(width: 8),
                _buildToolIcon(Icons.keyboard, () => setState(() => _showKeyboard = !_showKeyboard)),
                const SizedBox(width: 8),
                _buildToolIcon(Icons.desktop_windows, () => _sendInput({'type': 'shortcut', 'shortcut': 'win+d'}), tooltip: 'Win+D (Hiện Desktop)'),
                const SizedBox(width: 8),
                _buildToolIcon(Icons.close, () => Navigator.pop(context), color: Colors.redAccent),
              ],
            ),
          ),

          // Virtual Keyboard Drawer
          if (_showKeyboard)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: const Color(0xF212151E),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Nhập tiếng Việt hoặc văn bản...',
                              hintStyle: TextStyle(color: Colors.white38),
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (val) {
                              if (val.isNotEmpty) {
                                _sendInput({'type': 'type_text', 'text': val});
                                _textCtrl.clear();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (_textCtrl.text.isNotEmpty) {
                              _sendInput({'type': 'type_text', 'text': _textCtrl.text});
                              _textCtrl.clear();
                            }
                          },
                          child: const Text('Gửi'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildKbKey('Esc', () => _sendKey('escape')),
                          _buildKbKey('Tab', () => _sendKey('tab')),
                          _buildKbKey('Ctrl', () => _sendKey('ctrl')),
                          _buildKbKey('Alt', () => _sendKey('alt')),
                          _buildKbKey('Win', () => _sendKey('win')),
                          _buildKbKey('Shift', () => _sendKey('shift')),
                          _buildKbKey('Del', () => _sendKey('delete')),
                          _buildKbKey('Backspace', () => _sendKey('backspace')),
                          _buildKbKey('Enter', () => _sendKey('enter')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _sendKey(String key) {
    _sendInput({'type': 'key_event', 'key': key, 'action': 'down'});
    Future.delayed(const Duration(milliseconds: 30), () {
      _sendInput({'type': 'key_event', 'key': key, 'action': 'up'});
    });
  }

  Widget _buildMouseBtn(String text, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xCC1A1F2C),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildToolIcon(IconData icon, VoidCallback onPressed, {String? tooltip, Color? color}) {
    return CircleAvatar(
      backgroundColor: const Color(0xCC1A1F2C),
      child: IconButton(
        icon: Icon(icon, color: color ?? Colors.white, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildKbKey(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF252D3E),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: Size.zero,
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
