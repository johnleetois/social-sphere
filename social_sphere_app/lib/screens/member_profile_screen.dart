import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

const _bg = Color(0xFF0D0D1A);
const _surface = Color(0xFF1C1C2E);
const _primary = Color(0xFF7C5CF6);
const _textSecondary = Color(0xFF8B8BA7);
const _border = Color(0xFF2D2D4A);

class MemberProfileScreen extends StatefulWidget {
  final int userId;
  final int groupId;

  const MemberProfileScreen({
    super.key,
    required this.userId,
    required this.groupId,
  });

  @override
  MemberProfileScreenState createState() => MemberProfileScreenState();
}

class MemberProfileScreenState extends State<MemberProfileScreen> {
  Map<String, dynamic>? profile;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ApiService.getMemberProfile(widget.userId, widget.groupId);
    if (!mounted) return;
    setState(() {
      profile = data;
      isLoading = false;
    });
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return const Color(0xFFF59E0B);
      case 'admin':
        return const Color(0xFFEF4444);
      case 'mod':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF10B981);
    }
  }

  Color _badgeColor(String badge) {
    switch (badge) {
      case 'Legend':
        return const Color(0xFFF59E0B);
      case 'Star Member':
        return const Color(0xFFEC4899);
      case 'Active Member':
        return const Color(0xFF7C5CF6);
      case 'Contributor':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF10B981);
    }
  }

  Widget _buildAvatar(String? avatarUrl, double radius) {
    if (avatarUrl != null && avatarUrl.startsWith('data:')) {
      try {
        final base64Str = avatarUrl.split(',')[1];
        final bytes = base64Decode(base64Str);
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
    final username = profile?["username"] ?? "?";
    final initial = username.isNotEmpty ? username[0].toUpperCase() : "?";
    return CircleAvatar(
      radius: radius,
      backgroundColor: _primary.withValues(alpha: 0.2),
      child: Text(
        initial,
        style: TextStyle(
          color: _primary,
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w700,
        ),
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
        title: const Text(
          "Member Profile",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : profile == null
              ? Center(
                  child: Text(
                    "Profile not available",
                    style: TextStyle(color: _textSecondary),
                  ),
                )
              : _buildProfile(),
    );
  }

  Widget _buildProfile() {
    final p = profile!;
    final username = p["username"] ?? "Unknown";
    final fullName = p["full_name"] ?? "";
    final bio = p["bio"] ?? "";
    final role = p["role"] ?? "member";
    final points = p["points"] ?? 0;
    final rank = p["rank"] ?? 0;
    final badges = (p["badges"] as List?)?.cast<String>() ?? [];
    final joinedGroupAt = p["joined_group_at"] != null
        ? _formatDate(p["joined_group_at"])
        : "Unknown";
    final joinedAppAt = p["created_at"] != null
        ? _formatDate(p["created_at"])
        : "Unknown";

    return SingleChildScrollView(
      child: Column(
        children: [
          // HEADER
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: _surface,
              border: Border(bottom: BorderSide(color: _border)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: Column(
              children: [
                _buildAvatar(p["avatar_url"], 48),
                const SizedBox(height: 14),
                Text(
                  username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (fullName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    fullName,
                    style: TextStyle(color: _textSecondary, fontSize: 14),
                  ),
                ],
                const SizedBox(height: 10),
                // ROLE BADGE
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: _roleColor(role).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _roleColor(role).withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: TextStyle(
                      color: _roleColor(role),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    bio,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _textSecondary, fontSize: 14, height: 1.5),
                  ),
                ],
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ENGAGEMENT STATS
                _sectionTitle("Engagement"),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _statCard("Points", "$points", Icons.star_rounded, const Color(0xFFF59E0B))),
                    const SizedBox(width: 10),
                    Expanded(child: _statCard("Rank", "#$rank", Icons.leaderboard_rounded, const Color(0xFF7C5CF6))),
                  ],
                ),

                const SizedBox(height: 20),

                // BADGES
                _sectionTitle("Badges"),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: badges.map((b) => _badgeChip(b)).toList(),
                ),

                const SizedBox(height: 20),

                // DATES
                _sectionTitle("Timeline"),
                const SizedBox(height: 10),
                _infoRow(Icons.group_add_rounded, "Joined Group", joinedGroupAt),
                const SizedBox(height: 8),
                _infoRow(Icons.calendar_today_rounded, "On Social Sphere Since", joinedAppAt),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: _textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _badgeChip(String badge) {
    final color = _badgeColor(badge);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.military_tech_rounded, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            badge,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(icon, color: _textSecondary, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: _textSecondary, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return "${months[dt.month - 1]} ${dt.day}, ${dt.year}";
    } catch (_) {
      return iso;
    }
  }
}
