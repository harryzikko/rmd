import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    title: 'Hybrid Remote Desktop',
    debugShowCheckedModeBanner: false,
    home: ConnectScreen(),
  ));
}

// ---------------------------------------------------------------------------
// 1. CONNECT SCREEN (With Quick Reconnect & Fixed Credentials)
// ---------------------------------------------------------------------------
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

  // Quick saved history list (in-memory persistent across app session)
  static final List<Map<String, String>> _recentHosts = [
    {
      'title': 'Máy tính Windows chính (888 666 999)',
      'url': 'https://signs-scuba-advantage-amazing.trycloudflare.com',
      'id': '888 666 999',
      'pwd': '1234',
    }
  ];

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

  void _connect([String? overrideUrl, String? overrideId, String? overridePwd]) {
    String serverUrl = (overrideUrl ?? _urlCtrl.text).trim();
    final hostId = (overrideId ?? _hostIdCtrl.text).trim().replaceAll(' ', '');
    final passcode = (overridePwd ?? _pwdCtrl.text).trim();

    if (serverUrl.isEmpty || hostId.isEmpty || passcode.isEmpty) {
      setState(() => _status = 'Vui lòng điền đủ Đường dẫn, ID và Mật khẩu!');
      return;
    }

    if (!serverUrl.startsWith('http://') && !serverUrl.startsWith('https://')) {
      serverUrl = 'https://$serverUrl';
    }

    // Save to recents if not already there
    final exists = _recentHosts.any((h) => h['url'] == serverUrl && h['id'] == hostId);
    if (!exists) {
      _recentHosts.insert(0, {
        'title': 'Máy tính ID $hostId',
        'url': serverUrl,
        'id': hostId,
        'pwd': passcode,
      });
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
        title: const Text('Hybrid Remote Desktop', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1F2C),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 10)),
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
                const SizedBox(height: 6),
                const Center(
                  child: Text(
                    'Chuẩn TeamViewer & Remote Desktop Connection',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
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
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A7BD5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.bolt),
                  onPressed: () => _connect(),
                  label: const Text('KẾT NỐI NGAY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                if (_status.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(_status, style: const TextStyle(color: Colors.orange, fontSize: 13), textAlign: TextAlign.center),
                ],
                if (_recentHosts.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  const Text('⚡ Kết nối gần đây (1 chạm):', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...List.generate(_recentHosts.length, (idx) {
                    final item = _recentHosts[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF252D3E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.computer, color: Colors.cyanAccent),
                        title: Text(item['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
                        subtitle: Text(item['url'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
                        onTap: () => _connect(item['url'], item['id'], item['pwd']),
                      ),
                    );
                  }),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. REMOTE VIEWER SCREEN (Full-Featured Pro Client)
// ---------------------------------------------------------------------------
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
  bool _isLandscape = false;
  String _qualityPreset = 'balanced'; // 'speed', 'balanced', 'hd'
  final _textCtrl = TextEditingController();

  // Zoom & Pan Controller
  final TransformationController _transCtrl = TransformationController();
  bool _isZoomed = false;

  // Virtual cursor position
  Offset? _virtualCursorPos;
  int _lastMouseMoveTime = 0;
  Size _currentContainerSize = const Size(1280, 720);

  // Sticky modifiers state for virtual keyboard
  bool _ctrlActive = false;
  bool _altActive = false;
  bool _shiftActive = false;
  bool _winActive = false;

  final double _desktopW = 1920;
  final double _desktopH = 1080;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _connectWebSocket();
  }

  void _toggleOrientation() {
    setState(() {
      _isLandscape = !_isLandscape;
      _virtualCursorPos = null;
      if (_isLandscape) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      }
    });
  }

  void _toggleZoom() {
    setState(() {
      _isZoomed = !_isZoomed;
      if (_isZoomed) {
        _transCtrl.value = Matrix4.diagonal3Values(2.0, 2.0, 1.0);
      } else {
        _transCtrl.value = Matrix4.identity();
      }
    });
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
              } else if (json['type'] == 'clipboard_data') {
                // Clipboard data arrived from Windows PC
                final text = json['text'] as String? ?? '';
                if (text.isNotEmpty) {
                  Clipboard.setData(ClipboardData(text: text));
                  _showToast('📋 Đã nhận Clipboard từ máy tính:\n"$text"');
                } else {
                  _showToast('ℹ️ Khay nhớ tạm máy tính đang trống.');
                }
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

  void _throttledMouseMove(double normX, double normY) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastMouseMoveTime >= 20) {
      _lastMouseMoveTime = now;
      _sendInput({
        'type': 'mouse_move_abs',
        'x': normX.clamp(0.0, 1.0),
        'y': normY.clamp(0.0, 1.0),
      });
    }
  }

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

  void _sendMouseClick(String button, String action) {
    if (_mode == 'trackpad' && _virtualCursorPos != null) {
      final imageRect = _getRenderedImageRect(_currentContainerSize);
      final normX = (_virtualCursorPos!.dx - imageRect.left) / imageRect.width;
      final normY = (_virtualCursorPos!.dy - imageRect.top) / imageRect.height;
      _sendInput({
        'type': 'mouse_move_abs',
        'x': normX.clamp(0.0, 1.0),
        'y': normY.clamp(0.0, 1.0),
      });
    }
    _sendInput({
      'type': 'mouse_button',
      'button': button,
      'action': action,
    });
  }

  void _handleDirectTouch(Offset localPos, Size containerSize, String action) {
    final imageRect = _getRenderedImageRect(containerSize);
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

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E2638),
      ),
    );
  }

  // ------------------------- 2-Way Clipboard -------------------------
  void _syncClipboardToPC() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text ?? '';
    if (text.isNotEmpty) {
      _sendInput({'type': 'clipboard_set', 'text': text});
      _showToast('📤 Đã dán Clipboard điện thoại vào máy tính!');
    } else {
      _showToast('ℹ️ Clipboard trên điện thoại đang trống.');
    }
  }

  void _getClipboardFromPC() {
    _sendInput({'type': 'clipboard_get'});
  }

  // ------------------------- Quality Switcher -------------------------
  void _setQuality(String preset) {
    setState(() => _qualityPreset = preset);
    _sendInput({'type': 'set_quality', 'preset': preset});
    final label = preset == 'speed'
        ? '⚡ Siêu mượt (Tiết kiệm 4G)'
        : preset == 'hd'
            ? '💎 Sắc nét (Full HD)'
            : '⚖️ Cân bằng';
    _showToast('Chất lượng stream: $label');
  }

  // ------------------------- Windows System Actions Modal -------------------------
  void _showSystemMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B26),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('⚡ Menu Hành động Windows', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 10),

              // Clipboard Section
              const Text('📋 Đồng bộ Khay nhớ tạm (Clipboard)', style: TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF23304A), foregroundColor: Colors.white),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Lấy từ PC'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _getClipboardFromPC();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF23304A), foregroundColor: Colors.white),
                      icon: const Icon(Icons.upload, size: 18),
                      label: const Text('Gửi tới PC'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _syncClipboardToPC();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quality Preset Section
              const Text('📶 Chất lượng truyền phát', style: TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildQualityBtn('Tiết kiệm 4G', 'speed'),
                  const SizedBox(width: 6),
                  _buildQualityBtn('Cân bằng', 'balanced'),
                  const SizedBox(width: 6),
                  _buildQualityBtn('Full HD', 'hd'),
                ],
              ),
              const SizedBox(height: 16),

              // Windows System Actions
              const Text('🛠️ Tác vụ hệ thống Windows', style: TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildActionChip('📊 Task Manager', () => _sendInput({'type': 'system_action', 'action': 'task_manager'})),
                  _buildActionChip('📁 File Explorer (Win+E)', () => _sendInput({'type': 'system_action', 'action': 'file_explorer'})),
                  _buildActionChip('🏃 Run (Win+R)', () => _sendInput({'type': 'system_action', 'action': 'run_dialog'})),
                  _buildActionChip('❌ Đóng App (Alt+F4)', () => _sendInput({'type': 'system_action', 'action': 'close_window'})),
                  _buildActionChip('🔀 Đổi App (Alt+Tab)', () => _sendInput({'type': 'system_action', 'action': 'switch_window'})),
                  _buildActionChip('🖥️ Hiện Desktop (Win+D)', () => _sendInput({'type': 'shortcut', 'shortcut': 'win+d'})),
                  _buildActionChip('🔒 Khóa máy (Win+L)', () => _sendInput({'type': 'system_action', 'action': 'lock'})),
                  _buildActionChip('🕶️ Màn hình riêng tư (Tắt màn PC)', () => _sendInput({'type': 'system_action', 'action': 'privacy_on'})),
                  _buildActionChip('💡 Bật lại màn PC', () => _sendInput({'type': 'system_action', 'action': 'privacy_off'})),
                ],
              ),
              const SizedBox(height: 16),

              // Power Section
              const Text('⚠️ Tùy chọn Nguồn', style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.orangeAccent, side: const BorderSide(color: Colors.orangeAccent)),
                      icon: const Icon(Icons.restart_alt, size: 16),
                      label: const Text('Khởi động lại'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmPowerAction('Khởi động lại PC', 'reboot');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                      icon: const Icon(Icons.power_settings_new, size: 16),
                      label: const Text('Tắt nguồn'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmPowerAction('Tắt nguồn PC', 'shutdown');
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQualityBtn(String label, String preset) {
    final active = _qualityPreset == preset;
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: active ? const Color(0xFF3A7BD5) : const Color(0xFF23304A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        onPressed: () => _setQuality(preset),
        child: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
  }

  Widget _buildActionChip(String label, VoidCallback onTap) {
    return ActionChip(
      backgroundColor: const Color(0xFF23304A),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      onPressed: () {
        onTap();
        _showToast('Đã gửi lệnh: $label');
      },
    );
  }

  void _confirmPowerAction(String title, String action) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2638),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text('Bạn có chắc chắn muốn thực hiện lệnh $title trên máy tính không?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              _sendInput({'type': 'system_action', 'action': action});
              _showToast('Đã gửi lệnh $title!');
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  // ------------------------- Remote File Manager Modal -------------------------
  void _showFileManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141923),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => RemoteFileManagerModal(
        serverUrl: widget.serverUrl,
        hostId: widget.hostId,
        passcode: widget.passcode,
      ),
    );
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _transCtrl.dispose();
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
          // Screen Stream Viewport with Pinch-to-Zoom & Pan
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final containerSize = Size(constraints.maxWidth, constraints.maxHeight);
                _currentContainerSize = containerSize;
                final imageRect = _getRenderedImageRect(containerSize);
                _virtualCursorPos ??= imageRect.center;

                return Stack(
                  children: [
                    InteractiveViewer(
                      transformationController: _transCtrl,
                      minScale: 1.0,
                      maxScale: 4.0,
                      boundaryMargin: const EdgeInsets.all(double.infinity),
                      child: Center(
                        child: _connected && _latestFrame != null
                            ? Image.memory(
                                _latestFrame!,
                                gaplessPlayback: true,
                                fit: BoxFit.contain,
                              )
                            : Text(_status, style: const TextStyle(color: Colors.white70)),
                      ),
                    ),

                    // High-Visibility Virtual Cursor Overlay for Trackpad Mode
                    if (_mode == 'trackpad' && _virtualCursorPos != null)
                      Positioned(
                        left: _virtualCursorPos!.dx,
                        top: _virtualCursorPos!.dy,
                        child: IgnorePointer(
                          child: CustomPaint(
                            size: const Size(22, 28),
                            painter: VirtualCursorPainter(),
                          ),
                        ),
                      ),

                    // Gesture Detector for Mouse & Touch
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanUpdate: (details) {
                          if (_mode == 'trackpad') {
                            final newX = (_virtualCursorPos!.dx + details.delta.dx * 1.3).clamp(imageRect.left, imageRect.right);
                            final newY = (_virtualCursorPos!.dy + details.delta.dy * 1.3).clamp(imageRect.top, imageRect.bottom);
                            setState(() {
                              _virtualCursorPos = Offset(newX, newY);
                            });
                            final normX = (newX - imageRect.left) / imageRect.width;
                            final normY = (newY - imageRect.top) / imageRect.height;
                            _throttledMouseMove(normX, normY);
                          } else {
                            _handleDirectTouch(details.localPosition, containerSize, '');
                          }
                        },
                        onPanEnd: (_) {
                          if (_mode == 'trackpad' && _virtualCursorPos != null) {
                            final normX = (_virtualCursorPos!.dx - imageRect.left) / imageRect.width;
                            final normY = (_virtualCursorPos!.dy - imageRect.top) / imageRect.height;
                            _sendInput({
                              'type': 'mouse_move_abs',
                              'x': normX.clamp(0.0, 1.0),
                              'y': normY.clamp(0.0, 1.0),
                            });
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
                            final normX = (_virtualCursorPos!.dx - imageRect.left) / imageRect.width;
                            final normY = (_virtualCursorPos!.dy - imageRect.top) / imageRect.height;
                            _sendInput({
                              'type': 'mouse_move_abs',
                              'x': normX.clamp(0.0, 1.0),
                              'y': normY.clamp(0.0, 1.0),
                            });
                            _sendInput({'type': 'mouse_button', 'button': 'left', 'action': 'click'});
                          }
                        },
                        onDoubleTap: () {
                          _sendMouseClick('left', 'dblclick');
                        },
                        onLongPress: () {
                          _sendMouseClick('right', 'click');
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Top Status & Mode Indicator Badge
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xCC1A1F2C),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _connected ? Colors.greenAccent : Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _mode == 'trackpad' ? '🖱️ Trackpad' : '👆 Chạm trực tiếp',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Trackpad Helper Buttons
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildMouseBtn('🖱️ Trái', () => _sendMouseClick('left', 'click')),
                  const SizedBox(width: 6),
                  _buildMouseBtn('⚡ Đúp', () => _sendMouseClick('left', 'dblclick')),
                  const SizedBox(width: 6),
                  _buildMouseBtn('🖱️ Phải', () => _sendMouseClick('right', 'click')),
                  const SizedBox(width: 6),
                  _buildMouseBtn('🔼 Cuộn', () => _sendInput({'type': 'mouse_wheel', 'delta_y': 240})),
                  const SizedBox(width: 6),
                  _buildMouseBtn('🔽 Cuộn', () => _sendInput({'type': 'mouse_wheel', 'delta_y': -240})),
                  const SizedBox(width: 6),
                  _buildMouseBtn('📋 Dán', _syncClipboardToPC),
                  const SizedBox(width: 6),
                  _buildMouseBtn('📁 Files', _showFileManager),
                ],
              ),
            ),
          ),

          // Top Floating Action Toolbar
          Positioned(
            top: 16,
            right: 16,
            child: Row(
              children: [
                _buildToolIcon(
                  _isZoomed ? Icons.zoom_out : Icons.zoom_in,
                  _toggleZoom,
                  tooltip: _isZoomed ? 'Về 1x' : 'Thu phóng 2x',
                  color: _isZoomed ? Colors.amberAccent : Colors.white,
                ),
                const SizedBox(width: 8),
                _buildToolIcon(
                  _isLandscape ? Icons.stay_current_portrait : Icons.screen_rotation,
                  _toggleOrientation,
                  tooltip: _isLandscape ? 'Chuyển màn hình dọc' : 'Xoay ngang màn hình (Cực rõ)',
                  color: _isLandscape ? Colors.greenAccent : Colors.white,
                ),
                const SizedBox(width: 8),
                _buildToolIcon(
                  _mode == 'trackpad' ? Icons.touch_app : Icons.mouse,
                  () => setState(() => _mode = _mode == 'trackpad' ? 'touch' : 'trackpad'),
                  tooltip: _mode == 'trackpad' ? 'Đang bật: Trackpad' : 'Đang bật: Chạm trực tiếp',
                ),
                const SizedBox(width: 8),
                _buildToolIcon(Icons.keyboard, () => setState(() => _showKeyboard = !_showKeyboard), tooltip: 'Bàn phím ảo'),
                const SizedBox(width: 8),
                _buildToolIcon(Icons.flash_on, _showSystemMenu, tooltip: 'Menu Hệ thống Windows & Nguồn', color: Colors.cyanAccent),
                const SizedBox(width: 8),
                _buildToolIcon(Icons.close, () => Navigator.pop(context), color: Colors.redAccent, tooltip: 'Ngắt kết nối'),
              ],
            ),
          ),

          // Virtual Keyboard Drawer (Full Windows Navigation & Modifiers)
          if (_showKeyboard)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: const Color(0xF212151E),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                        IconButton(
                          icon: const Icon(Icons.keyboard_hide, color: Colors.white70),
                          onPressed: () => setState(() => _showKeyboard = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Modifiers & Quick Action Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildStickyModifier('Ctrl', _ctrlActive, () => _toggleModifier('ctrl')),
                          _buildStickyModifier('Alt', _altActive, () => _toggleModifier('alt')),
                          _buildStickyModifier('Shift', _shiftActive, () => _toggleModifier('shift')),
                          _buildStickyModifier('Win', _winActive, () => _toggleModifier('win')),
                          _buildKbKey('Esc', () => _sendKey('escape')),
                          _buildKbKey('Tab', () => _sendKey('tab')),
                          _buildKbKey('Ctrl+C', () => _sendInput({'type': 'shortcut', 'shortcut': 'ctrl+c'})),
                          _buildKbKey('Ctrl+V', () => _sendInput({'type': 'shortcut', 'shortcut': 'ctrl+v'})),
                          _buildKbKey('Ctrl+Z', () => _sendInput({'type': 'shortcut', 'shortcut': 'ctrl+z'})),
                          _buildKbKey('Ctrl+A', () => _sendInput({'type': 'shortcut', 'shortcut': 'ctrl+a'})),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Navigation & Function Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildKbKey('⬅️', () => _sendKey('left')),
                          _buildKbKey('⬆️', () => _sendKey('up')),
                          _buildKbKey('⬇️', () => _sendKey('down')),
                          _buildKbKey('➡️', () => _sendKey('right')),
                          _buildKbKey('Home', () => _sendKey('home')),
                          _buildKbKey('End', () => _sendKey('end')),
                          _buildKbKey('PgUp', () => _sendKey('pageup')),
                          _buildKbKey('PgDn', () => _sendKey('pagedown')),
                          _buildKbKey('Del', () => _sendKey('delete')),
                          _buildKbKey('⌫', () => _sendKey('backspace')),
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

  void _toggleModifier(String mod) {
    setState(() {
      if (mod == 'ctrl') {
        _ctrlActive = !_ctrlActive;
        _sendInput({'type': 'key_event', 'key': 'ctrl', 'action': _ctrlActive ? 'down' : 'up'});
      } else if (mod == 'alt') {
        _altActive = !_altActive;
        _sendInput({'type': 'key_event', 'key': 'alt', 'action': _altActive ? 'down' : 'up'});
      } else if (mod == 'shift') {
        _shiftActive = !_shiftActive;
        _sendInput({'type': 'key_event', 'key': 'shift', 'action': _shiftActive ? 'down' : 'up'});
      } else if (mod == 'win') {
        _winActive = !_winActive;
        _sendInput({'type': 'key_event', 'key': 'win', 'action': _winActive ? 'down' : 'up'});
      }
    });
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildToolIcon(IconData icon, VoidCallback onPressed, {String? tooltip, Color? color}) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xCC1A1F2C),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: color ?? Colors.white, size: 18),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildStickyModifier(String label, bool active, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: active ? Colors.blueAccent : const Color(0xFF252D3E),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          minimumSize: Size.zero,
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildKbKey(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF252D3E),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          minimumSize: Size.zero,
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. REMOTE FILE MANAGER MODAL (Direct PC Browsing & Downloading)
// ---------------------------------------------------------------------------
class RemoteFileManagerModal extends StatefulWidget {
  final String serverUrl;
  final String hostId;
  final String passcode;

  const RemoteFileManagerModal({
    super.key,
    required this.serverUrl,
    required this.hostId,
    required this.passcode,
  });

  @override
  State<RemoteFileManagerModal> createState() => _RemoteFileManagerModalState();
}

class _RemoteFileManagerModalState extends State<RemoteFileManagerModal> {
  String _currentPath = 'My PC';
  String _parentPath = '';
  List<dynamic> _items = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchDirectory('My PC');
  }

  Future<void> _fetchDirectory(String path) async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final cleanUrl = widget.serverUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$cleanUrl/api/fs/list?id=${widget.hostId}&pwd=${widget.passcode}&path=${Uri.encodeComponent(path)}');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        setState(() {
          _currentPath = data['current_path'] ?? path;
          _parentPath = data['parent_path'] ?? '';
          _items = data['items'] ?? [];
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Lỗi máy chủ (${res.statusCode}): ${res.body}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Không thể tải danh sách file: $e';
        _loading = false;
      });
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _downloadFile(String filePath, String fileName) async {
    final cleanUrl = widget.serverUrl.replaceAll(RegExp(r'/+$'), '');
    final downloadUrl = '$cleanUrl/api/fs/download?id=${widget.hostId}&pwd=${widget.passcode}&path=${Uri.encodeComponent(filePath)}';

    // Copy link to clipboard for 1-tap browser download
    await Clipboard.setData(ClipboardData(text: downloadUrl));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📥 Đã sao chép link tải "$fileName" vào Clipboard!\nBạn có thể dán vào trình duyệt để tải ngay.'),
          duration: const Duration(seconds: 4),
          backgroundColor: const Color(0xFF1E2638),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_shared, color: Colors.cyanAccent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Quản lý & Truyền File Từ Xa', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 8),
          // Path breadcrumb
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFF1E2638), borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                if (_parentPath.isNotEmpty) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, color: Colors.cyanAccent, size: 18),
                    tooltip: 'Lên thư mục cha',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _fetchDirectory(_parentPath),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(_currentPath, style: const TextStyle(color: Colors.white, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _fetchDirectory(_currentPath),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // File List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(child: Text(_error, style: const TextStyle(color: Colors.orange)))
                    : _items.isEmpty
                        ? const Center(child: Text('Thư mục trống', style: TextStyle(color: Colors.white38)))
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                            itemBuilder: (_, idx) {
                              final it = _items[idx];
                              final isDir = it['is_dir'] == true;
                              final name = it['name'] ?? '';
                              final path = it['path'] ?? name;
                              final sizeStr = _formatSize(it['size'] ?? 0);

                              return ListTile(
                                dense: true,
                                leading: Icon(
                                  isDir ? Icons.folder : Icons.insert_drive_file,
                                  color: isDir ? Colors.amberAccent : Colors.lightBlueAccent,
                                ),
                                title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                subtitle: isDir ? null : Text(sizeStr, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                trailing: isDir
                                    ? const Icon(Icons.chevron_right, color: Colors.white24)
                                    : IconButton(
                                        icon: const Icon(Icons.download, color: Colors.cyanAccent, size: 20),
                                        tooltip: 'Tải file về máy',
                                        onPressed: () => _downloadFile(path, name),
                                      ),
                                onTap: isDir ? () => _fetchDirectory(path) : () => _downloadFile(path, name),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. VIRTUAL CURSOR PAINTER (High-Visibility Electric Cyan Cursor)
// ---------------------------------------------------------------------------
class VirtualCursorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..color = Colors.black.withAlpha(150)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = const Color(0xFF00E5FF) // Electric Cyan
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, 24)
      ..lineTo(6, 19)
      ..lineTo(11, 28)
      ..lineTo(15, 26)
      ..lineTo(10, 17)
      ..lineTo(18, 17)
      ..close();

    // Drop shadow
    canvas.save();
    canvas.translate(2, 2);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    // Outer black boundary
    canvas.drawPath(path, borderPaint);

    // Bright cyan fill
    canvas.drawPath(path, fillPaint);

    // Precise white targeting dot at tip
    canvas.drawCircle(Offset.zero, 2.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
