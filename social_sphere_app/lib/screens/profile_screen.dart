// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'intro_screen.dart';

const _bg = Color(0xFF0D0D1A);
const _surface = Color(0xFF1C1C2E);
const _elevated = Color(0xFF252540);
const _primary = Color(0xFF7C5CF6);
const _textSecondary = Color(0xFF8B8BA7);
const _border = Color(0xFF2D2D4A);
const _danger = Color(0xFFEF4444);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? profile;
  List groupStats = [];
  List activityLog = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final results = await Future.wait([
      ApiService.getProfile(),
      ApiService.getMyGroupStats(),
      ApiService.getLoginActivity(),
    ]);
    if (!mounted) return;
    setState(() {
      profile = results[0] as Map<String, dynamic>?;
      groupStats = results[1] as List;
      activityLog = results[2] as List;
      isLoading = false;
    });
  }

  // ── Avatar helpers ──────────────────────────────────────

  Widget _buildAvatar(String? avatarUrl, double radius) {
    if (avatarUrl != null && avatarUrl.startsWith('data:')) {
      try {
        final bytes = base64Decode(avatarUrl.split(',')[1]);
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {}
    }
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }
    final initial = (profile?["username"] ?? "?").toString();
    return CircleAvatar(
      radius: radius,
      backgroundColor: _primary.withValues(alpha: 0.2),
      child: Text(
        initial.isNotEmpty ? initial[0].toUpperCase() : "?",
        style: TextStyle(
          color: _primary,
          fontSize: radius * 0.65,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
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

    final ok = await ApiService.updateProfile({"avatar_url": dataUri});
    if (ok && mounted) {
      setState(() => profile!["avatar_url"] = dataUri);
      _showSnack("Avatar updated");
    }
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
        title: const Text(
          "My Profile",
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _primary,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: _primary,
          unselectedLabelColor: _textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: "Profile"),
            Tab(text: "Security"),
            Tab(text: "Groups"),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildProfileTab(),
                _buildSecurityTab(),
                _buildGroupsTab(),
              ],
            ),
    );
  }

  // ── Tab 1 — Profile ──────────────────────────────────────

  Widget _buildProfileTab() {
    if (profile == null) {
      return Center(child: Text("Could not load profile", style: TextStyle(color: _textSecondary)));
    }
    final p = profile!;
    final createdAt = p["created_at"] != null ? _formatDate(p["created_at"]) : "Unknown";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // AVATAR + EDIT BUTTON
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              _buildAvatar(p["avatar_url"], 52),
              GestureDetector(
                onTap: _pickAvatar,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: _bg, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            p["username"] ?? "",
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          if ((p["full_name"] ?? "").isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(p["full_name"], style: TextStyle(color: _textSecondary, fontSize: 14)),
            ),
          const SizedBox(height: 6),
          Text(
            "Joined $createdAt",
            style: TextStyle(color: _textSecondary, fontSize: 12),
          ),

          const SizedBox(height: 24),

          // INFO FIELDS
          _infoCard([
            _infoRow(Icons.person_rounded, "Username", p["username"] ?? "—"),
            _divider(),
            _infoRow(Icons.badge_rounded, "Display Name", (p["full_name"] ?? "").isNotEmpty ? p["full_name"] : "—"),
            _divider(),
            _infoRow(Icons.info_outline_rounded, "Bio", (p["bio"] ?? "").isNotEmpty ? p["bio"] : "—"),
            _divider(),
            _infoRow(Icons.interests_rounded, "Hobbies", (p["hobbies"] ?? "").isNotEmpty ? p["hobbies"] : "—"),
            _divider(),
            _infoRow(Icons.email_outlined, "Email", p["email"] ?? "—", isPrivate: true),
          ]),

          const SizedBox(height: 20),

          // EDIT BUTTON
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _showEditDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text("Edit Profile", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2 — Security ─────────────────────────────────────

  Widget _buildSecurityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CHANGE PASSWORD
          _sectionLabel("Account"),
          const SizedBox(height: 10),
          _actionTile(
            icon: Icons.lock_outline_rounded,
            label: "Change Password",
            color: _primary,
            onTap: _showChangePasswordDialog,
          ),
          const SizedBox(height: 8),
          _actionTile(
            icon: Icons.logout_rounded,
            label: "Log Out",
            color: const Color(0xFF3B82F6),
            onTap: _confirmLogout,
          ),
          const SizedBox(height: 8),
          _actionTile(
            icon: Icons.delete_forever_rounded,
            label: "Delete Account",
            color: _danger,
            onTap: _confirmDeleteAccount,
          ),

          const SizedBox(height: 28),

          // LOGIN ACTIVITY
          _sectionLabel("Recent Login Activity"),
          const SizedBox(height: 10),
          if (activityLog.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Text("No activity recorded", style: TextStyle(color: _textSecondary, fontSize: 14)),
            )
          else
            _infoCard(
              activityLog.asMap().entries.map((e) {
                final item = e.value;
                final ip = item["ip_address"] ?? "Unknown IP";
                final time = item["created_at"] != null
                    ? _formatDateTime(item["created_at"])
                    : "Unknown time";
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.login_rounded, color: Color(0xFF3B82F6), size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Login from $ip",
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                                Text(time, style: TextStyle(color: _textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (e.key < activityLog.length - 1) _divider(),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ── Tab 3 — Groups ───────────────────────────────────────

  Widget _buildGroupsTab() {
    if (groupStats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_outlined, size: 48, color: _textSecondary),
            const SizedBox(height: 12),
            Text("No group activity yet", style: TextStyle(color: _textSecondary, fontSize: 15)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupStats.length,
      itemBuilder: (context, index) => _buildGroupStatCard(groupStats[index]),
    );
  }

  Widget _buildGroupStatCard(dynamic stat) {
    final name = stat["group_name"] ?? "Group";
    final role = stat["role"] ?? "member";
    final points = stat["points"] ?? 0;
    final rank = stat["rank"] ?? 0;
    final badges = (stat["badges"] as List?)?.cast<String>() ?? [];
    final joinedAt = stat["joined_at"] != null ? _formatDate(stat["joined_at"]) : "Unknown";
    final initial = name.isNotEmpty ? name[0].toUpperCase() : "G";

    const colorList = [
      Color(0xFF7C5CF6), Color(0xFF2E82FF), Color(0xFFEC4899),
      Color(0xFF10B981), Color(0xFFF59E0B),
    ];
    final color = colorList[name.hashCode.abs() % colorList.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // GROUP HEADER
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.35)),
                  ),
                  child: Center(
                    child: Text(initial, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      Text("Joined $joinedAt", style: TextStyle(color: _textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                _roleBadge(role),
              ],
            ),
            const SizedBox(height: 14),

            // STATS ROW
            Row(
              children: [
                Expanded(child: _miniStat("Points", "$points", Icons.star_rounded, const Color(0xFFF59E0B))),
                const SizedBox(width: 8),
                Expanded(child: _miniStat("Rank", "#$rank", Icons.leaderboard_rounded, const Color(0xFF7C5CF6))),
              ],
            ),

            if (badges.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: badges.map((b) => _smallBadge(b)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Dialogs ──────────────────────────────────────────────

  void _showEditDialog() {
    final usernameCtrl = TextEditingController(text: profile?["username"] ?? "");
    final nameCtrl = TextEditingController(text: profile?["full_name"] ?? "");
    final bioCtrl = TextEditingController(text: profile?["bio"] ?? "");
    final hobbiesCtrl = TextEditingController(text: profile?["hobbies"] ?? "");
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Edit Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dlgField(usernameCtrl, "Username", Icons.person_rounded),
                const SizedBox(height: 12),
                _dlgField(nameCtrl, "Display Name", Icons.badge_rounded),
                const SizedBox(height: 12),
                _dlgField(bioCtrl, "Bio", Icons.info_outline_rounded, maxLines: 3),
                const SizedBox(height: 12),
                _dlgField(hobbiesCtrl, "Hobbies", Icons.interests_rounded),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Cancel", style: TextStyle(color: _textSecondary)),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      setDlg(() => saving = true);
                      final ok = await ApiService.updateProfile({
                        "username": usernameCtrl.text.trim(),
                        "full_name": nameCtrl.text.trim(),
                        "bio": bioCtrl.text.trim(),
                        "hobbies": hobbiesCtrl.text.trim(),
                      });
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      if (ok) {
                        await _loadAll();
                        _showSnack("Profile updated");
                      } else {
                        _showSnack("Failed to update profile", isError: true);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Save", style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String error = "";
    bool saving = false;
    bool obscureCurrent = true;
    bool obscureNew = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Change Password", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dlgField(currentCtrl, "Current Password", Icons.lock_outline_rounded, obscure: obscureCurrent, onToggle: () => setDlg(() => obscureCurrent = !obscureCurrent)),
                const SizedBox(height: 12),
                _dlgField(newCtrl, "New Password", Icons.lock_rounded, obscure: obscureNew, onToggle: () => setDlg(() => obscureNew = !obscureNew)),
                const SizedBox(height: 12),
                _dlgField(confirmCtrl, "Confirm Password", Icons.lock_rounded, obscure: obscureNew),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(error, style: const TextStyle(color: _danger, fontSize: 13)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Cancel", style: TextStyle(color: _textSecondary)),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (newCtrl.text != confirmCtrl.text) {
                        setDlg(() => error = "Passwords do not match");
                        return;
                      }
                      if (newCtrl.text.length < 6) {
                        setDlg(() => error = "Password must be at least 6 characters");
                        return;
                      }
                      setDlg(() { saving = true; error = ""; });
                      final err = await ApiService.changePassword(currentCtrl.text, newCtrl.text);
                      if (!mounted) return;
                      if (err == null) {
                        Navigator.pop(ctx);
                        _showSnack("Password changed successfully");
                      } else {
                        setDlg(() { saving = false; error = err; });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Update", style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Log Out", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text("Are you sure you want to log out?", style: TextStyle(color: _textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel", style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService.logout();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const IntroScreen()),
                (_) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text("Log Out", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Account", style: TextStyle(color: _danger, fontWeight: FontWeight.w700)),
        content: Text(
          "This will permanently delete your account and all associated data. This action cannot be undone.",
          style: TextStyle(color: _textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel", style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ApiService.deleteAccount();
              if (!mounted) return;
              if (ok) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const IntroScreen()),
                  (_) => false,
                );
              } else {
                _showSnack("Failed to delete account", isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _danger, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text("Delete", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Reusable widgets ─────────────────────────────────────

  Widget _infoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(children: children),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {bool isPrivate = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: _textSecondary, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: _textSecondary, fontSize: 11)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (isPrivate)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _textSecondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text("private", style: TextStyle(color: _textSecondary, fontSize: 10)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(height: 1, color: _border, indent: 16, endIndent: 16);

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(color: color == _danger ? _danger : Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, color: _textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dlgField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    int maxLines = 1,
    bool obscure = false,
    VoidCallback? onToggle,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      maxLines: obscure ? 1 : maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _textSecondary, fontSize: 14),
        prefixIcon: Icon(icon, color: _textSecondary, size: 18),
        suffixIcon: onToggle != null
            ? IconButton(
                icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: _textSecondary, size: 18),
                onPressed: onToggle,
              )
            : null,
        filled: true,
        fillColor: _elevated,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _roleBadge(String role) {
    Color color;
    switch (role.toLowerCase()) {
      case 'owner': color = const Color(0xFFF59E0B); break;
      case 'admin': color = const Color(0xFFEF4444); break;
      case 'mod': color = const Color(0xFF3B82F6); break;
      default: color = const Color(0xFF10B981);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(role.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    );
  }

  Widget _miniStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _elevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              Text(label, style: TextStyle(color: _textSecondary, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallBadge(String badge) {
    const colors = {
      'Legend': Color(0xFFF59E0B),
      'Star Member': Color(0xFFEC4899),
      'Active Member': Color(0xFF7C5CF6),
      'Contributor': Color(0xFF3B82F6),
    };
    final color = colors[badge] ?? const Color(0xFF10B981);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(badge, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? _danger : _primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return "${m[dt.month - 1]} ${dt.day}, ${dt.year}";
    } catch (_) { return iso; }
  }

  String _formatDateTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return "${m[dt.month - 1]} ${dt.day}, ${dt.year} at $h:$min";
    } catch (_) { return iso; }
  }
}
