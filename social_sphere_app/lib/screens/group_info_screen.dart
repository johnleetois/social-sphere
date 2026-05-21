// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'member_profile_screen.dart';

const _bg = Color(0xFF0D0D1A);
const _surface = Color(0xFF1C1C2E);
const _elevated = Color(0xFF252540);
const _primary = Color(0xFF7C5CF6);
const _textSecondary = Color(0xFF8B8BA7);
const _border = Color(0xFF2D2D4A);
const _danger = Color(0xFFEF4444);

class GroupInfoScreen extends StatefulWidget {
  final int groupId;
  final int currentUserId;

  const GroupInfoScreen({
    super.key,
    required this.groupId,
    required this.currentUserId,
  });

  @override
  GroupInfoScreenState createState() => GroupInfoScreenState();
}

class GroupInfoScreenState extends State<GroupInfoScreen> {
  Map<String, dynamic>? info;
  bool isLoading = true;
  String myRole = "member";

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ApiService.getGroupInfo(widget.groupId);
    if (!mounted) return;
    setState(() {
      info = data;
      isLoading = false;
      if (data != null) {
        final members = (data["members"] as List?) ?? [];
        for (final m in members) {
          if (m["user_id"] == widget.currentUserId) {
            myRole = m["role"] ?? "member";
          }
        }
      }
    });
  }

  bool get _isAdmin => myRole == "owner" || myRole == "admin";

  // ── Avatar helpers ──────────────────────────────────────

  Widget _buildGroupAvatar(String? avatarUrl, double radius) {
    if (avatarUrl != null && avatarUrl.startsWith('data:')) {
      try {
        final bytes = base64Decode(avatarUrl.split(',')[1]);
        return CircleAvatar(radius: radius, backgroundImage: MemoryImage(bytes));
      } catch (_) {}
    }
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(avatarUrl));
    }
    final name = info?["name"] ?? "G";
    return CircleAvatar(
      radius: radius,
      backgroundColor: _primary.withValues(alpha: 0.2),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : "G",
        style: TextStyle(color: _primary, fontSize: radius * 0.65, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildMemberAvatar(Map m, double radius) {
    final avatarUrl = m["avatar_url"];
    if (avatarUrl != null && (avatarUrl as String).startsWith('data:')) {
      try {
        final bytes = base64Decode(avatarUrl.split(',')[1]);
        return CircleAvatar(radius: radius, backgroundImage: MemoryImage(bytes));
      } catch (_) {}
    }
    if (avatarUrl != null && (avatarUrl as String).isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(avatarUrl));
    }
    final name = (m["username"] ?? "?") as String;
    const colors = [Color(0xFF7C5CF6), Color(0xFF2E82FF), Color(0xFFEC4899), Color(0xFF10B981), Color(0xFFF59E0B)];
    final color = colors[name.hashCode.abs() % colors.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.2),
      child: Text(name[0].toUpperCase(), style: TextStyle(color: color, fontSize: radius * 0.65, fontWeight: FontWeight.w700)),
    );
  }

  // ── Actions ─────────────────────────────────────────────

  Future<void> _pickGroupAvatar() async {
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
    final ok = await ApiService.updateGroup(widget.groupId, {"avatar_url": dataUri});
    if (ok && mounted) {
      await _load();
      _snack("Group avatar updated");
    }
  }

  void _showEditNameDialog() {
    final ctrl = TextEditingController(text: info?["name"] ?? "");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Edit Group Name", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Group name",
            hintStyle: TextStyle(color: _textSecondary),
            filled: true,
            fillColor: _elevated,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primary)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel", style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (ctrl.text.trim().isEmpty) return;
              final ok = await ApiService.updateGroup(widget.groupId, {"name": ctrl.text.trim()});
              if (ok && mounted) { await _load(); _snack("Group name updated"); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text("Save", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showRoleMenu(Map member) {
    if (!_isAdmin || member["user_id"] == widget.currentUserId || member["role"] == "owner") return;
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${member["username"]}", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _roleOption("Make Admin", "admin", member),
            _roleOption("Make Member", "member", member),
          ],
        ),
      ),
    );
  }

  Widget _roleOption(String label, String role, Map member) {
    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white)),
      leading: Icon(Icons.person_rounded, color: _textSecondary),
      onTap: () async {
        Navigator.pop(context);
        final ok = await ApiService.updateMemberRole(widget.groupId, member["user_id"], role);
        if (ok && mounted) { await _load(); _snack("Role updated"); }
      },
    );
  }

  void _confirmLeave() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Leave Group", style: TextStyle(color: _danger, fontWeight: FontWeight.w700)),
        content: Text("Are you sure you want to leave this group?", style: TextStyle(color: _textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel", style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final err = await ApiService.leaveGroup(widget.groupId);
              if (!mounted) return;
              if (err == null) {
                Navigator.of(context).popUntil((r) => r.isFirst);
              } else {
                _snack(err, isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _danger, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text("Leave", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────

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
        title: const Text("Group Info", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: _textSecondary),
              onPressed: _showEditNameDialog,
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : info == null
              ? Center(child: Text("Could not load group info", style: TextStyle(color: _textSecondary)))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final g = info!;
    final members = (g["members"] as List?) ?? [];

    return SingleChildScrollView(
      child: Column(
        children: [
          // GROUP HEADER
          Container(
            width: double.infinity,
            color: _surface,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    _buildGroupAvatar(g["avatar_url"], 44),
                    if (_isAdmin)
                      GestureDetector(
                        onTap: _pickGroupAvatar,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(color: _primary, shape: BoxShape.circle, border: Border.all(color: _bg, width: 2)),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 13),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(g["name"] ?? "", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                if ((g["description"] ?? "").isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(g["description"], textAlign: TextAlign.center, style: TextStyle(color: _textSecondary, fontSize: 13)),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_rounded, color: _textSecondary, size: 14),
                    const SizedBox(width: 4),
                    Text("${g["member_count"] ?? members.length} members", style: TextStyle(color: _textSecondary, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // INVITE CODE (visible to all members)
          if ((g["invite_code"] ?? "").isNotEmpty)
            Container(
              color: _surface,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("INVITE CODE", style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: _elevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _border),
                        ),
                        child: Text(
                          g["invite_code"],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 4,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: g["invite_code"]));
                          _snack("Invite code copied!");
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _primary.withValues(alpha: 0.4)),
                          ),
                          child: const Icon(Icons.copy_rounded, color: _primary, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text("Share this code so others can join the group", style: TextStyle(color: _textSecondary, fontSize: 12)),
                ],
              ),
            ),

          if ((g["invite_code"] ?? "").isNotEmpty) const SizedBox(height: 8),

          // MEMBERS
          Container(
            color: _surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Text("MEMBERS", style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                ),
                ...members.map((m) => _buildMemberTile(m)),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ACTIONS
          Container(
            color: _surface,
            child: Column(
              children: [
                _actionTile(Icons.logout_rounded, "Leave Group", _danger, _confirmLeave),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMemberTile(Map m) {
    final role = m["role"] ?? "member";
    Color roleColor;
    switch (role) {
      case 'owner': roleColor = const Color(0xFFF59E0B); break;
      case 'admin': roleColor = const Color(0xFFEF4444); break;
      default: roleColor = const Color(0xFF10B981);
    }

    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => MemberProfileScreen(userId: m["user_id"], groupId: widget.groupId),
        ));
      },
      onLongPress: () => _showRoleMenu(m),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _buildMemberAvatar(m, 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m["username"] ?? "", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                  if ((m["full_name"] ?? "").isNotEmpty)
                    Text(m["full_name"], style: TextStyle(color: _textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: roleColor.withValues(alpha: 0.4)),
              ),
              child: Text(role.toUpperCase(), style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 14),
            Text(label, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? _danger : _primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}
