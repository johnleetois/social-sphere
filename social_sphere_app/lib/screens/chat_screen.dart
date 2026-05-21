// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'group_info_screen.dart';

const _bg = Color(0xFF0D0D1A);
const _surface = Color(0xFF1C1C2E);
const _elevated = Color(0xFF252540);
const _primary = Color(0xFF7C5CF6);
const _textSecondary = Color(0xFF8B8BA7);
const _border = Color(0xFF2D2D4A);

class ChatScreen extends StatefulWidget {
  final int channelId;
  final String token;
  final String channelName;
  final int groupId;
  final int currentUserId;

  const ChatScreen({
    super.key,
    required this.channelId,
    required this.token,
    this.channelName = "general",
    this.groupId = 0,
    this.currentUserId = 0,
  });

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  late WebSocketChannel _ws;
  final _msgCtrl = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _connected = false;
  final Map<int, String> _typingUsers = {}; // userId -> username
  Timer? _typingTimer;
  bool _isSendingTyping = false;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    final url = "ws://10.0.9.104:8000/ws/chat/${widget.channelId}?token=${widget.token}";
    log("CHAT WS: $url");
    _ws = WebSocketChannel.connect(Uri.parse(url));
    setState(() => _connected = true);

    _ws.stream.listen(
      (raw) {
        try {
          final data = jsonDecode(raw as String) as Map<String, dynamic>;
          _handleEvent(data);
        } catch (e) {
          log("WS parse error: $e");
        }
      },
      onError: (e) { log("WS error: $e"); if (mounted) setState(() => _connected = false); },
      onDone: () { log("WS closed"); if (mounted) setState(() => _connected = false); },
    );
  }

  void _handleEvent(Map<String, dynamic> data) {
    if (!mounted) return;
    final type = data["type"] as String? ?? "message";
    switch (type) {
      case "history":
      case "message":
        setState(() => _messages.add(data));
        _scrollToBottom();
        break;
      case "typing":
        final uid = data["user_id"] as int?;
        final username = data["username"] as String? ?? "";
        final isTyping = data["is_typing"] as bool? ?? false;
        if (uid != null && uid != widget.currentUserId) {
          setState(() {
            if (isTyping) {
              _typingUsers[uid] = username;
            } else {
              _typingUsers.remove(uid);
            }
          });
        }
        break;
      case "presence":
        // Could show presence indicators; for now ignored
        break;
      case "seen":
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
    _ws.sink.add(jsonEncode({"type": "typing", "is_typing": isTyping}));
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
    if (text.isEmpty) return;
    _typingTimer?.cancel();
    _sendTyping(false);
    _ws.sink.add(jsonEncode({"type": "message", "content": text, "message_type": "text"}));
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
    if (bytes == null) return;
    final ext = (file.extension ?? 'jpg').toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';
    _ws.sink.add(jsonEncode({"type": "message", "content": dataUri, "message_type": "image"}));
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _msgCtrl.dispose();
    _scroll.dispose();
    _ws.sink.close();
    super.dispose();
  }

  Color _userColor(String username) {
    const colors = [
      Color(0xFF7C5CF6), Color(0xFF2E82FF), Color(0xFFEC4899),
      Color(0xFF10B981), Color(0xFFF59E0B),
    ];
    return colors[username.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          if (_typingUsers.isNotEmpty) _buildTypingBar(),
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
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: _primary.withValues(alpha: 0.18), shape: BoxShape.circle),
            child: const Icon(Icons.tag_rounded, color: _primary, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.channelName,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Row(
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: _connected ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _connected ? "Connected" : "Disconnected",
                    style: TextStyle(
                      color: _connected ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (widget.groupId != 0)
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: _textSecondary),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => GroupInfoScreen(
                  groupId: widget.groupId,
                  currentUserId: widget.currentUserId,
                ),
              ));
            },
            tooltip: "Group Info",
          ),
      ],
    );
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
            Text("Say hello!", style: TextStyle(color: _textSecondary.withValues(alpha: 0.6), fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _buildMessageBubble(_messages[i], i),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, int index) {
    final username = msg["username"]?.toString() ?? "Unknown";
    final content = msg["content"]?.toString() ?? "";
    final msgType = msg["message_type"]?.toString() ?? "text";
    final timestamp = msg["timestamp"]?.toString();
    final color = _userColor(username);
    final initial = username.isNotEmpty ? username[0].toUpperCase() : "?";
    final showHeader = index == 0 || _messages[index - 1]["username"] != username;
    final avatarUrl = msg["avatar_url"] as String?;

    return Padding(
      padding: EdgeInsets.only(bottom: showHeader ? 10 : 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader)
            Container(
              width: 36, height: 36,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.18), shape: BoxShape.circle),
              child: _buildAvatarContent(avatarUrl, initial, color),
            )
          else
            const SizedBox(width: 46),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showHeader)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      children: [
                        Text(username, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
                        if (timestamp != null) ...[
                          const SizedBox(width: 8),
                          Text(_formatTimestamp(timestamp), style: TextStyle(color: _textSecondary, fontSize: 11)),
                        ],
                      ],
                    ),
                  ),
                if (msgType == "image")
                  _buildImageContent(content)
                else
                  Text(content, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarContent(String? avatarUrl, String initial, Color color) {
    if (avatarUrl != null && avatarUrl.startsWith('data:')) {
      try {
        final bytes = base64Decode(avatarUrl.split(',')[1]);
        return ClipOval(child: Image.memory(bytes, width: 36, height: 36, fit: BoxFit.cover));
      } catch (_) {}
    }
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return ClipOval(child: Image.network(avatarUrl, width: 36, height: 36, fit: BoxFit.cover));
    }
    return Center(child: Text(initial, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)));
  }

  Widget _buildImageContent(String dataUri) {
    try {
      final bytes = base64Decode(dataUri.split(',')[1]);
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(bytes, width: 220, fit: BoxFit.cover),
      );
    } catch (_) {
      return const Text("📷 Image", style: TextStyle(color: Colors.white, fontSize: 15));
    }
  }

  Widget _buildTypingBar() {
    final names = _typingUsers.values.take(3).join(", ");
    final suffix = _typingUsers.length == 1 ? " is typing…" : " are typing…";
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
      child: Text("$names$suffix", style: TextStyle(color: _textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
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
                  hintText: "Message #${widget.channelName}",
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

  String _formatTimestamp(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return "$h:$m";
    } catch (_) {
      return "";
    }
  }
}
