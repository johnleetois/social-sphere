// ignore_for_file: use_build_context_synchronously
import 'dart:developer';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'feed_screen.dart';
import 'group_screen.dart';
import 'group_info_screen.dart';
import 'profile_screen.dart';

// ── Palette ──────────────────────────────────────────────────────────────────
const _bg      = Color(0xFF07071A);
const _surface = Color(0xFF111128);
const _card    = Color(0xFF14142B);
const _primary = Color(0xFF7C5CF6);
const _cyan    = Color(0xFF00CFFF);
const _pink    = Color(0xFFFF52A2);
const _dim     = Color(0xFF4A4A6A);

const _palettes = [
  [Color(0xFF7C5CF6), Color(0xFF00CFFF)],
  [Color(0xFFFF52A2), Color(0xFFFF9A3C)],
  [Color(0xFF00CFFF), Color(0xFF10E8A0)],
  [Color(0xFF10B981), Color(0xFF7C5CF6)],
  [Color(0xFFF59E0B), Color(0xFFEF4444)],
  [Color(0xFFEC4899), Color(0xFF7C5CF6)],
];

List<Color> _palette(String name) =>
    _palettes[name.hashCode.abs() % _palettes.length];

// ── Sort modes ───────────────────────────────────────────────────────────────
enum _SortMode { az, za, role }

// ── Type badge helpers ───────────────────────────────────────────────────────
Color _typeColor(String? type) {
  switch (type) {
    case 'private': return _pink;
    case 'invite':  return _primary;
    default:        return _cyan;
  }
}

IconData _typeIcon(String? type) {
  switch (type) {
    case 'private': return Icons.lock_rounded;
    case 'invite':  return Icons.mail_rounded;
    default:        return Icons.public_rounded;
  }
}

String _typeLabel(String? type) {
  switch (type) {
    case 'private': return 'Private';
    case 'invite':  return 'Invite';
    default:        return 'Public';
  }
}

// ── Role sort order ──────────────────────────────────────────────────────────
int _roleOrder(String? role) {
  switch (role) {
    case 'owner': return 0;
    case 'admin': return 1;
    default:      return 2;
  }
}

// ── Relative time ────────────────────────────────────────────────────────────
String _relTime(String? isoStr) {
  if (isoStr == null) return 'No posts yet';
  try {
    final dt   = DateTime.parse(isoStr).toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return 'Just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24)  return '${diff.inHours}h ago';
    if (diff.inDays    < 7)   return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  } catch (_) {
    return '';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class MyGroupsScreen extends StatefulWidget {
  const MyGroupsScreen({super.key});
  @override
  MyGroupsScreenState createState() => MyGroupsScreenState();
}

class MyGroupsScreenState extends State<MyGroupsScreen>
    with TickerProviderStateMixin {
  List   groups          = [];
  bool   isLoading       = true;
  String _search         = '';
  _SortMode _sortMode    = _SortMode.az;
  String _roleFilter     = 'all';
  Map<String, DateTime> _lastVisited = {};
  int    _currentUserId  = 0;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _loadPrefs();
    loadGroups();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs   = await SharedPreferences.getInstance();
    final profile = await ApiService.getProfile();
    final map     = <String, DateTime>{};
    for (final k in prefs.getKeys().where((k) => k.startsWith('last_visited_'))) {
      final str = prefs.getString(k);
      if (str != null) {
        try { map[k] = DateTime.parse(str); } catch (_) {}
      }
    }
    if (!mounted) return;
    setState(() {
      _lastVisited  = map;
      if (profile != null) _currentUserId = (profile['id'] ?? 0) as int;
    });
  }

  Future<void> loadGroups() async {
    try {
      final data = await ApiService.getMyGroups();
      log("LOADED GROUPS: $data");
      if (!mounted) return;
      setState(() { groups = data; isLoading = false; });
    } catch (e) {
      log("ERROR LOADING GROUPS: $e");
      if (!mounted) return;
      setState(() { groups = []; isLoading = false; });
    }
  }

  int _parseId(dynamic id) {
    try { return id is int ? id : int.parse(id.toString()); }
    catch (_) { return 0; }
  }

  void _openGroup(dynamic group) async {
    final id = _parseId(group["id"]);
    if (id == 0) return;
    final prefs = await SharedPreferences.getInstance();
    final now   = DateTime.now();
    await prefs.setString('last_visited_$id', now.toIso8601String());
    if (!mounted) return;
    setState(() => _lastVisited['last_visited_$id'] = now);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FeedScreen(groupId: id)),
    );
  }

  bool _isUnread(dynamic group) {
    final id          = _parseId(group["id"]);
    final lastPostStr = group["last_post_at"] as String?;
    if (lastPostStr == null) return false;
    final lastPost    = DateTime.tryParse(lastPostStr);
    if (lastPost == null) return false;
    final lastVisited = _lastVisited['last_visited_$id'];
    if (lastVisited == null) return true;
    return lastPost.isAfter(lastVisited);
  }

  List get _filtered {
    var result = groups.where((g) {
      if (_search.isNotEmpty &&
          !(g["name"] ?? "").toLowerCase().contains(_search.toLowerCase())) {
        return false;
      }
      if (_roleFilter != 'all' && g["role"] != _roleFilter) return false;
      return true;
    }).toList();

    result.sort((a, b) {
      switch (_sortMode) {
        case _SortMode.az:
          return (a["name"] ?? "").compareTo(b["name"] ?? "");
        case _SortMode.za:
          return (b["name"] ?? "").compareTo(a["name"] ?? "");
        case _SortMode.role:
          return _roleOrder(a["role"]).compareTo(_roleOrder(b["role"]));
      }
    });

    return result;
  }

  // ── Context menu ───────────────────────────────────────────────────────────
  void _showContextMenu(dynamic group) {
    final id      = _parseId(group["id"]);
    final name    = (group["name"] ?? "Group") as String;
    final role    = (group["role"] ?? "member") as String;
    final isAdmin = role == "owner" || role == "admin";

    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ContextMenu(
        groupName: name,
        isAdmin: isAdmin,
        onOpen: () { Navigator.pop(context); _openGroup(group); },
        onCopyCode: isAdmin
            ? () async {
                Navigator.pop(context);
                final info = await ApiService.getGroupInfo(id);
                if (!mounted) return;
                final code = info?["invite_code"] as String?;
                if (code != null) {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Invite code copied: $code"),
                      backgroundColor: _primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              }
            : null,
        onViewMembers: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupInfoScreen(
                groupId: id,
                currentUserId: _currentUserId,
              ),
            ),
          ).then((_) => loadGroups());
        },
        onLeave: () {
          Navigator.pop(context);
          _confirmLeave(id, name);
        },
      ),
    );
  }

  void _confirmLeave(int groupId, String groupName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Leave Group", style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to leave "$groupName"?',
          style: const TextStyle(color: _dim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: _dim)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final err = await ApiService.leaveGroup(groupId);
              if (!mounted) return;
              if (err == null) {
                setState(() => isLoading = true);
                loadGroups();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(err), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text("Leave", style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  // ── Sort sheet ─────────────────────────────────────────────────────────────
  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: _dim, borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "SORT BY",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              for (final item in [
                (_SortMode.az,   Icons.sort_by_alpha_rounded, "A → Z"),
                (_SortMode.za,   Icons.sort_by_alpha_rounded, "Z → A"),
                (_SortMode.role, Icons.shield_rounded,        "By Role"),
              ])
                ListTile(
                  onTap: () {
                    setState(() => _sortMode = item.$1);
                    Navigator.pop(context);
                  },
                  leading: Icon(
                    item.$2,
                    color: _sortMode == item.$1 ? _primary : _dim,
                    size: 20,
                  ),
                  title: Text(
                    item.$3,
                    style: TextStyle(
                      color: _sortMode == item.$1 ? _primary : Colors.white,
                      fontWeight: _sortMode == item.$1 ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  trailing: _sortMode == item.$1
                      ? Icon(Icons.check_rounded, color: _primary, size: 18)
                      : null,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            _StarField(),
            Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                _buildFilterRow(),
                Expanded(
                  child: isLoading
                      ? _buildLoader()
                      : _filtered.isEmpty
                          ? _buildEmpty()
                          : _buildContent(),
                ),
              ],
            ),
            _buildDock(),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "YOUR UNIVERSE",
                  style: TextStyle(
                    color: _cyan.withValues(alpha: 0.7),
                    fontSize: 11,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [_cyan, _primary, _pink],
                  ).createShader(b),
                  child: const Text(
                    "My Groups",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) => Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _primary.withValues(alpha: _pulse.value * 0.5),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: child,
            ),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_primary, _pink],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () { setState(() => isLoading = true); loadGroups(); },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _surface,
                shape: BoxShape.circle,
                border: Border.all(color: _dim, width: 1),
              ),
              child: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search Bar ────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _dim, width: 1),
        ),
        child: TextField(
          onChanged: (v) => setState(() => _search = v),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: "Search your groups…",
            hintStyle: TextStyle(color: _dim, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: _dim, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
          ),
        ),
      ),
    );
  }

  // ── Filter & Sort Row ─────────────────────────────────────────────────────
  Widget _buildFilterRow() {
    const chips  = ['all', 'owner', 'admin', 'member'];
    const labels = {'all': 'All', 'owner': 'Owner', 'admin': 'Admin', 'member': 'Member'};

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 30,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: chips.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final chip     = chips[i];
                  final selected = _roleFilter == chip;
                  return GestureDetector(
                    onTap: () => setState(() => _roleFilter = chip),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: selected ? _primary.withValues(alpha: 0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? _primary : _dim,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          labels[chip]!,
                          style: TextStyle(
                            color: selected ? _primary : _dim,
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showSortMenu,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _sortMode != _SortMode.az
                    ? _primary.withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _sortMode != _SortMode.az ? _primary : _dim,
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.sort_rounded,
                color: _sortMode != _SortMode.az ? _primary : _dim,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Loader ────────────────────────────────────────────────────────────────
  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48, height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(_primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Scanning your universe…",
            style: TextStyle(color: _dim, fontSize: 13, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  // ── Main Content ──────────────────────────────────────────────────────────
  Widget _buildContent() {
    final pinned = _filtered.take(3).toList();
    final rest   = _filtered.skip(3).toList();

    return RefreshIndicator(
      color: _primary,
      backgroundColor: _surface,
      onRefresh: loadGroups,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _sectionLabel("PINNED SPACES", Icons.star_rounded)),

          SliverToBoxAdapter(
            child: SizedBox(
              height: 166,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                physics: const BouncingScrollPhysics(),
                itemCount: pinned.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _HeroGroupCard(
                    group:       pinned[i],
                    isUnread:    _isUnread(pinned[i]),
                    onTap:       () => _openGroup(pinned[i]),
                    onLongPress: () => _showContextMenu(pinned[i]),
                  ),
                ),
              ),
            ),
          ),

          if (rest.isNotEmpty) ...[
            SliverToBoxAdapter(child: _sectionLabel("ALL GROUPS", Icons.grid_view_rounded)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _GridGroupCard(
                    group:       rest[i],
                    isUnread:    _isUnread(rest[i]),
                    onTap:       () => _openGroup(rest[i]),
                    onLongPress: () => _showContextMenu(rest[i]),
                  ),
                  childCount: rest.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.80,
                ),
              ),
            ),
          ] else
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Row(
        children: [
          Icon(icon, color: _primary, size: 14),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: _dim,
              fontSize: 11,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) => Transform.scale(
              scale: 0.92 + _pulse.value * 0.08,
              child: child,
            ),
            child: Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [_primary, _cyan],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.35),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.rocket_launch_rounded, size: 44, color: Colors.white),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "No groups yet",
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            "Create your first space or join one",
            style: TextStyle(color: _dim, fontSize: 14),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GroupScreen()),
            ).then((_) => loadGroups()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_primary, _pink]),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(color: _primary.withValues(alpha: 0.4), blurRadius: 16),
                ],
              ),
              child: const Text(
                "Launch a Group",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Dock ───────────────────────────────────────────────────────────
  Widget _buildDock() {
    return Positioned(
      bottom: 20, left: 0, right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GroupScreen()),
          ).then((_) => loadGroups()),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primary, _pink],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: _primary.withValues(alpha: 0.5),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text(
                  "New Group",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero card (horizontal strip)
// ─────────────────────────────────────────────────────────────────────────────
class _HeroGroupCard extends StatelessWidget {
  final dynamic      group;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool         isUnread;

  const _HeroGroupCard({
    required this.group,
    required this.onTap,
    required this.onLongPress,
    required this.isUnread,
  });

  @override
  Widget build(BuildContext context) {
    final name    = (group["name"] ?? "Unnamed") as String;
    final type    = group["type"] as String?;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : "G";
    final colors  = _palette(name);
    final tc      = _typeColor(type);

    return GestureDetector(
      onTap:      onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              colors[0].withValues(alpha: 0.25),
              colors[1].withValues(alpha: 0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: colors[0].withValues(alpha: 0.4), width: 1.5),
        ),
        child: Stack(
          children: [
            // Big watermark letter
            Positioned(
              right: -10, bottom: -10,
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 90,
                  fontWeight: FontWeight.w900,
                  color: colors[0].withValues(alpha: 0.08),
                  height: 1,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: colors),
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: [
                            BoxShadow(
                              color: colors[0].withValues(alpha: 0.5),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      // Unread dot
                      if (isUnread)
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            color: _cyan,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _cyan.withValues(alpha: 0.7),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Type badge
                  Row(
                    children: [
                      Icon(_typeIcon(type), color: tc, size: 10),
                      const SizedBox(width: 4),
                      Text(
                        _typeLabel(type),
                        style: TextStyle(
                          color: tc,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Grid card (2-column section)
// ─────────────────────────────────────────────────────────────────────────────
class _GridGroupCard extends StatelessWidget {
  final dynamic      group;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool         isUnread;

  const _GridGroupCard({
    required this.group,
    required this.onTap,
    required this.onLongPress,
    required this.isUnread,
  });

  @override
  Widget build(BuildContext context) {
    final name        = (group["name"] ?? "Unnamed") as String;
    final type        = group["type"] as String?;
    final lastPostAt  = group["last_post_at"] as String?;
    final lastPreview = group["last_post_preview"] as String?;
    final initial     = name.isNotEmpty ? name[0].toUpperCase() : "G";
    final colors      = _palette(name);
    final tc          = _typeColor(type);

    return GestureDetector(
      onTap:       onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors[0].withValues(alpha: 0.3), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: colors[0].withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Top gradient band
            Positioned(
              top: 0, left: 0, right: 0, height: 5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
              ),
            ),
            // Watermark
            Positioned(
              right: -8, bottom: -8,
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  color: colors[0].withValues(alpha: 0.06),
                  height: 1,
                ),
              ),
            ),
            // Unread dot (top-right)
            if (isUnread)
              Positioned(
                top: 12, right: 12,
                child: Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: _cyan,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _cyan.withValues(alpha: 0.7),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Orb avatar
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colors[0].withValues(alpha: 0.45),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Type badge
                  Row(
                    children: [
                      Icon(_typeIcon(type), color: tc, size: 10),
                      const SizedBox(width: 3),
                      Text(
                        _typeLabel(type),
                        style: TextStyle(
                          color: tc,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Recent activity preview
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors[0].withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colors[0].withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lastPreview != null && lastPreview.isNotEmpty
                              ? lastPreview
                              : 'No posts yet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: lastPreview != null
                                ? Colors.white.withValues(alpha: 0.75)
                                : _dim,
                            fontSize: 10,
                            height: 1.3,
                          ),
                        ),
                        if (lastPostAt != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            _relTime(lastPostAt),
                            style: TextStyle(color: _dim, fontSize: 9),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Enter button
                  Container(
                    height: 26,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors[0].withValues(alpha: 0.2),
                          colors[1].withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors[0].withValues(alpha: 0.4), width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Enter",
                          style: TextStyle(
                            color: colors[0],
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, color: colors[0], size: 11),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Context menu bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _ContextMenu extends StatelessWidget {
  final String        groupName;
  final bool          isAdmin;
  final VoidCallback  onOpen;
  final VoidCallback? onCopyCode;
  final VoidCallback  onViewMembers;
  final VoidCallback  onLeave;

  const _ContextMenu({
    required this.groupName,
    required this.isAdmin,
    required this.onOpen,
    required this.onCopyCode,
    required this.onViewMembers,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: _dim, borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            groupName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _menuItem(
            icon:  Icons.login_rounded,
            label: "Open Group",
            color: _primary,
            onTap: onOpen,
          ),
          if (isAdmin)
            _menuItem(
              icon:  Icons.key_rounded,
              label: "Copy Invite Code",
              color: _cyan,
              onTap: onCopyCode!,
            ),
          _menuItem(
            icon:  Icons.group_rounded,
            label: "View Members",
            color: Colors.white70,
            onTap: onViewMembers,
          ),
          _menuItem(
            icon:  Icons.logout_rounded,
            label: "Leave Group",
            color: const Color(0xFFEF4444),
            onTap: onLeave,
          ),
        ],
      ),
    );
  }

  Widget _menuItem({
    required IconData     icon,
    required String       label,
    required Color        color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      contentPadding: const EdgeInsets.symmetric(vertical: 2),
      dense: true,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Background star field
// ─────────────────────────────────────────────────────────────────────────────
class _StarField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.infinite, painter: _StarPainter());
  }
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng   = math.Random(42);
    final paint = Paint()..color = Colors.white;
    for (int i = 0; i < 80; i++) {
      final x      = rng.nextDouble() * size.width;
      final y      = rng.nextDouble() * size.height;
      final radius = rng.nextDouble() * 1.2 + 0.3;
      paint.color  = Colors.white.withValues(alpha: rng.nextDouble() * 0.25 + 0.05);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
