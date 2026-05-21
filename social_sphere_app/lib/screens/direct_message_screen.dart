// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/api_service.dart';
import 'call_screen.dart';

const _bg = Color(0xFF0D0D1A);
const _surface = Color(0xFF1C1C2E);
const _elevated = Color(0xFF252540);
const _primary = Color(0xFF7C5CF6);
const _textSecondary = Color(0xFF8B8BA7);
const _border = Color(0xFF2D2D4A);
const _online = Color(0xFF10B981);

class DirectMessageScreen extends StatefulWidget {
  final int peerId;
  final String peerUsername;
  final String? peerAvatarUrl;
  final int currentUserId;
  final String token;

  const DirectMessageScreen({
    super.key,
    required this.peerId,
    required this.peerUsername,
    this.peerAvatarUrl,
    required this.currentUserId,
    required this.token,
  });

  @override
  DirectMessageScreenState createState() => DirectMessageScreenState();
}

class DirectMessageScreenState extends State<DirectMessageScreen> {
  WebSocketChannel? _channel;
  final _msgCtrl = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isOnline = false;
  bool _peerTyping = false;
  bool _connected = false;
  bool _loadingHistory = true;
  Timer? _typingTimer;
  bool _isSendingTyping = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await ApiService.getDmHistory(widget.peerId);
    if (!mounted) return;
    setState(() {
      _messages.clear();
      for (final m in history) {
        _messages.add(Map<String, dynamic>.from(m as Map));
      }
      _loadingHistory = false;
    });
    _scrollToBottom();
    _connectWs();
  }

  void _connectWs() {
    final url = "ws://10.0.9.104:8000/ws/dm/${widget.peerId}?token=${widget.token}";
    log("DM WS: $url");
    _channel = WebSocketChannel.connect(Uri.parse(url));
    setState(() => _connected = true);

    _channel!.stream.listen(
      (raw) {
        try {
          final data = jsonDecode(raw as String) as Map<String, dynamic>;
          _handleEvent(data);
        } catch (e) {
          log("DM WS parse error: $e");
        }
      },
      onError: (e) { log("DM WS error: $e"); if (mounted) setState(() => _connected = false); },
      onDone: () { log("DM WS closed"); if (mounted) setState(() => _connected = false); },
    );
  }

  void _handleEvent(Map<String, dynamic> data) {
    final type = data["type"] as String? ?? "";
    switch (type) {
      case "message":
        if (!mounted) return;
        setState(() => _messages.add(data));
        _scrollToBottom();
        // Send seen receipt if message is from peer
        if ((data["sender_id"] as int?) == widget.peerId) {
          _channel?.sink.add(jsonEncode({"type": "seen"}));
        }
        break;
      case "typing":
        if (!mounted) return;
        final uid = data["user_id"] as int?;
        final isTyping = data["is_typing"] as bool? ?? false;
        if (uid == widget.peerId) {
          setState(() => _peerTyping = isTyping);
        }
        break;
      case "seen":
        // Optionally mark our sent messages as seen
        break;
      case "presence":
        if (!mounted) return;
        final uid = data["user_id"] as int?;
        if (uid == widget.peerId) {
          setState(() => _isOnline = data["is_online"] as bool? ?? false);
        }
        break;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendTyping(bool isTyping) {
    if (_isSendingTyping == isTyping) return;
    _isSendingTyping = isTyping;
    _channel?.sink.add(jsonEncode({"type": "typing", "is_typing": isTyping}));
  }

  void _onTextChanged(String text) {
    if (text.isNotEmpty) {
      _sendTyping(true);
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () => _sendTyping(false));
    } else {
      _typingTimer?.cancel();
      _sendTyping(false);
    }
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _channel == null) return;
    _typingTimer?.cancel();
    _sendTyping(false);
    _channel!.sink.add(jsonEncode({"type": "message", "content": text, "message_type": "text"}));
    _msgCtrl.clear();
  }

  Future<void> _sendImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    List<int>? bytes;
    if (file.bytes != null) {
      bytes = file.bytes!;
    } else if (file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null || _channel == null) return;
    final ext = (file.extension ?? 'jpg').toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';
    _channel!.sink.add(jsonEncode({"type": "message", "content": dataUri, "message_type": "image"}));
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _msgCtrl.dispose();
    _scroll.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _loadingHistory ? const Center(child: CircularProgressIndicator(color: _primary)) : _buildMessageList()),
          if (_peerTyping) _buildTypingIndicator(),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _bg,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              _buildPeerAvatar(20),
              if (_isOnline)
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: _online, shape: BoxShape.circle,
                    border: Border.all(color: _bg, width: 1.5),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.peerUsername, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              Text(
                _isOnline ? "Online" : _connected ? "Away" : "Offline",
                style: TextStyle(
                  color: _isOnline ? _online : _textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.call_rounded, color: _textSecondary, size: 22),
          onPressed: () => _startCall("audio"),
          tooltip: "Audio call",
        ),
        IconButton(
          icon: const Icon(Icons.videocam_rounded, color: _textSecondary, size: 22),
          onPressed: () => _startCall("video"),
          tooltip: "Video call",
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  void _startCall(String callType) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CallScreen(
        peerId: widget.peerId,
        peerUsername: widget.peerUsername,
        peerAvatarUrl: widget.peerAvatarUrl,
        callType: callType,
        currentUserId: widget.currentUserId,
        token: widget.token,
        isIncoming: false,
      ),
    ));
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 52, color: _textSecondary),
            const SizedBox(height: 12),
            Text("No messages yet", style: TextStyle(color: _textSecondary, fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text("Say hello to ${widget.peerUsername}!", style: TextStyle(color: _textSecondary.withValues(alpha: 0.6), fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _buildBubble(_messages[i], i),
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg, int index) {
    // Both history (sender_id) and WS (sender_id) use sender_id
    final senderId = (msg["sender_id"] as int?) ?? 0;
    final isMine = senderId == widget.currentUserId;
    final content = msg["content"] as String? ?? "";
    final msgType = msg["message_type"] as String? ?? "text";
    final ts = msg["created_at"] as String? ?? msg["timestamp"] as String? ?? "";

    final showTimestamp = index == 0 ||
        _messages[index - 1]["sender_id"] != senderId ||
        _timestampDiffOver2Min(_messages[index - 1]["created_at"] ?? _messages[index - 1]["timestamp"] ?? "", ts);

    return Padding(
      padding: EdgeInsets.only(
        top: showTimestamp ? 12 : 2,
        bottom: 2,
        left: isMine ? 48 : 0,
        right: isMine ? 0 : 48,
      ),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showTimestamp && ts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Center(
                child: Text(
                  _formatTimestamp(ts),
                  style: TextStyle(color: _textSecondary, fontSize: 11),
                ),
              ),
            ),
          Row(
            mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMine) ...[
                _buildPeerAvatar(14),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Container(
                  padding: msgType == "image"
                      ? const EdgeInsets.all(4)
                      : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMine ? _primary.withValues(alpha: 0.85) : _surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMine ? 16 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 16),
                    ),
                    border: isMine ? null : Border.all(color: _border),
                  ),
                  child: msgType == "image"
                      ? _buildImageContent(content)
                      : Text(
                          content,
                          style: TextStyle(
                            color: isMine ? Colors.white : Colors.white,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageContent(String dataUri) {
    try {
      final bytes = base64Decode(dataUri.split(',')[1]);
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(bytes, width: 200, fit: BoxFit.cover),
      );
    } catch (_) {
      return const Text("📷 Image", style: TextStyle(color: Colors.white));
    }
  }

  Widget _buildPeerAvatar(double radius) {
    final avatarUrl = widget.peerAvatarUrl;
    if (avatarUrl != null && avatarUrl.startsWith('data:')) {
      try {
        final bytes = base64Decode(avatarUrl.split(',')[1]);
        return CircleAvatar(radius: radius, backgroundImage: MemoryImage(bytes));
      } catch (_) {}
    }
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(avatarUrl));
    }
    const colors = [Color(0xFF7C5CF6), Color(0xFF2E82FF), Color(0xFFEC4899), Color(0xFF10B981), Color(0xFFF59E0B)];
    final color = colors[widget.peerUsername.hashCode.abs() % colors.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.2),
      child: Text(
        widget.peerUsername.isNotEmpty ? widget.peerUsername[0].toUpperCase() : "?",
        style: TextStyle(color: color, fontSize: radius * 0.7, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Row(
        children: [
          _buildPeerAvatar(10),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dot(0),
                const SizedBox(width: 4),
                _dot(1),
                const SizedBox(width: 4),
                _dot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: Duration(milliseconds: 400 + index * 150),
      builder: (context, v, _) => Opacity(
        opacity: v,
        child: Container(
          width: 6, height: 6,
          decoration: BoxDecoration(color: _textSecondary, shape: BoxShape.circle),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.image_outlined, color: _textSecondary, size: 24),
            onPressed: _sendImage,
            tooltip: "Send image",
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _elevated,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _border),
              ),
              child: TextField(
                controller: _msgCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                onChanged: _onTextChanged,
                decoration: InputDecoration(
                  hintText: "Message ${widget.peerUsername}…",
                  hintStyle: TextStyle(color: _textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF7C5CF6), Color(0xFF2E82FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  bool _timestampDiffOver2Min(String a, String b) {
    try {
      final da = DateTime.parse(a);
      final db = DateTime.parse(b);
      return db.difference(da).inMinutes.abs() >= 2;
    } catch (_) {
      return false;
    }
  }

  String _formatTimestamp(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      }
      return "${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return "";
    }
  }
}
