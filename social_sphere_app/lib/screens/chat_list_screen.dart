// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';
import 'direct_message_screen.dart';

const _bg = Color(0xFF0D0D1A);
const _surface = Color(0xFF1C1C2E);
const _primary = Color(0xFF7C5CF6);
const _textSecondary = Color(0xFF8B8BA7);
const _online = Color(0xFF10B981);

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  ChatListScreenState createState() => ChatListScreenState();
}

class ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<dynamic> _conversations = [];
  List<dynamic> _groups = [];
  bool _loading = true;
  int _currentUserId = 0;
  String? _token;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await ApiService.getProfile();
    final token = await ApiService.getToken();
    final convs = await ApiService.getDmConversations();
    final groups = await ApiService.getMyGroups();
    if (!mounted) return;
    setState(() {
      _currentUserId = (profile?["id"] as int?) ?? 0;
      _token = token;
      _conversations = convs;
      _groups = groups;
      _loading = false;
    });
  }

  Color _userColor(String name) {
    const colors = [
      Color(0xFF7C5CF6), Color(0xFF2E82FF), Color(0xFFEC4899),
      Color(0xFF10B981), Color(0xFFF59E0B),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  String _formatTime(String? iso) {
    if (iso == null) return "";
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      }
      return "${dt.day}/${dt.month}";
    } catch (_) {
      return "";
    }
  }

  Widget _buildAvatar(Map conv) {
    final avatarUrl = conv["avatar_url"] as String?;
    final name = (conv["username"] ?? conv["name"] ?? "?") as String;
    final color = _userColor(name);

    if (avatarUrl != null && avatarUrl.startsWith('data:')) {
      try {
        final bytes = base64Decode(avatarUrl.split(',')[1]);
        return CircleAvatar(radius: 24, backgroundImage: MemoryImage(bytes));
      } catch (_) {}
    }
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(radius: 24, backgroundImage: NetworkImage(avatarUrl));
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: color.withValues(alpha: 0.2),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : "?",
        style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Messages", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _primary,
          labelColor: _primary,
          unselectedLabelColor: _textSecondary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: "Direct Messages"),
            Tab(text: "Group Chats"),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : TabBarView(
              controller: _tab,
              children: [
                _buildDmList(),
                _buildGroupList(),
              ],
            ),
    );
  }

  Widget _buildDmList() {
    if (_conversations.isEmpty) {
      return _buildEmpty(Icons.chat_bubble_outline_rounded, "No direct messages", "Message a group member to get started");
    }
    return RefreshIndicator(
      color: _primary,
      backgroundColor: _surface,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _conversations.length,
        itemBuilder: (_, i) => _buildConvTile(_conversations[i]),
      ),
    );
  }

  Widget _buildConvTile(Map<String, dynamic> conv) {
    final peerId = conv["user_id"] as int;
    final username = conv["username"] as String? ?? "Unknown";
    final fullName = conv["full_name"] as String? ?? "";
    final lastMsg = conv["last_message"] as String? ?? "";
    final lastAt = conv["last_message_at"] as String?;
    final unread = (conv["unread_count"] as int?) ?? 0;
    final isOnline = (conv["is_online"] as bool?) ?? false;
    final displayName = fullName.isNotEmpty ? fullName : username;

    return InkWell(
      onTap: () {
        if (_token == null) return;
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => DirectMessageScreen(
            peerId: peerId,
            peerUsername: username,
            peerAvatarUrl: conv["avatar_url"] as String?,
            currentUserId: _currentUserId,
            token: _token!,
          ),
        )).then((_) => _load());
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: unread > 0 ? _surface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                _buildAvatar(conv),
                if (isOnline)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _online,
                      shape: BoxShape.circle,
                      border: Border.all(color: _bg, width: 2),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(_formatTime(lastAt), style: TextStyle(color: _textSecondary, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMsg.isEmpty ? "No messages yet" : lastMsg,
                          style: TextStyle(
                            color: unread > 0 ? Colors.white70 : _textSecondary,
                            fontSize: 13,
                            fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unread > 99 ? "99+" : unread.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupList() {
    if (_groups.isEmpty) {
      return _buildEmpty(Icons.groups_outlined, "No groups", "Join or create a group first");
    }
    return RefreshIndicator(
      color: _primary,
      backgroundColor: _surface,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _groups.length,
        itemBuilder: (_, i) => _buildGroupTile(_groups[i]),
      ),
    );
  }

  Widget _buildGroupTile(Map<String, dynamic> group) {
    final name = (group["name"] ?? "Unnamed") as String;
    final groupId = group["id"] as int;
    final memberCount = group["member_count"] ?? 0;
    final avatarUrl = group["avatar_url"] as String?;
    final color = _userColor(name);

    Widget avatar;
    if (avatarUrl != null && avatarUrl.startsWith('data:')) {
      try {
        final bytes = base64Decode(avatarUrl.split(',')[1]);
        avatar = CircleAvatar(radius: 24, backgroundImage: MemoryImage(bytes));
      } catch (_) {
        avatar = _groupInitialAvatar(name, color);
      }
    } else if (avatarUrl != null && avatarUrl.isNotEmpty) {
      avatar = CircleAvatar(radius: 24, backgroundImage: NetworkImage(avatarUrl));
    } else {
      avatar = _groupInitialAvatar(name, color);
    }

    return InkWell(
      onTap: () async {
        if (_token == null) return;
        final channels = await ApiService.getChannels(groupId);
        if (!mounted) return;
        if (channels.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No channels in this group")),
          );
          return;
        }
        final channelId = channels[0]["id"] as int;
        final channelName = channels[0]["name"] as String? ?? "general";
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChatScreen(
            channelId: channelId,
            token: _token!,
            channelName: channelName,
            groupId: groupId,
            currentUserId: _currentUserId,
          ),
        ));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text("$memberCount members", style: TextStyle(color: _textSecondary, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _groupInitialAvatar(String name, Color color) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: color.withValues(alpha: 0.2),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : "G",
        style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildEmpty(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: _primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 34, color: _primary),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: _textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
