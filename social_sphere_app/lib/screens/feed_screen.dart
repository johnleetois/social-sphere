// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';
import 'member_profile_screen.dart';
import 'group_info_screen.dart';

// ─────────────────────────────────────────────
// COLOUR CONSTANTS
// ─────────────────────────────────────────────
const _bg = Color(0xFF0D0D1A);
const _surface = Color(0xFF1C1C2E);
const _elevated = Color(0xFF252540);
const _primary = Color(0xFF7C5CF6);
const _textSecondary = Color(0xFF8B8BA7);
const _border = Color(0xFF2D2D4A);
const _danger = Color(0xFFEF4444);
const _pinColor = Color(0xFFF59E0B);

// ─────────────────────────────────────────────
// TAG SYSTEM
// ─────────────────────────────────────────────
class _TagDef {
  final String key;
  final String label;
  final Color color;
  final IconData icon;
  const _TagDef(this.key, this.label, this.color, this.icon);
}

const _tags = [
  _TagDef(
    'announcement',
    'Announcement',
    Color(0xFFF97316),
    Icons.campaign_rounded,
  ),
  _TagDef(
    'question',
    'Question',
    Color(0xFF2E82FF),
    Icons.help_outline_rounded,
  ),
  _TagDef('discussion', 'Discussion', Color(0xFF10B981), Icons.forum_rounded),
  _TagDef(
    'achievement',
    'Achievement',
    Color(0xFFF59E0B),
    Icons.emoji_events_rounded,
  ),
  _TagDef('idea', 'Idea', Color(0xFF7C5CF6), Icons.lightbulb_outline_rounded),
];

const _schoolTags = [
  _TagDef(
    'announcement',
    'Announcement',
    Color(0xFFF97316),
    Icons.campaign_rounded,
  ),
  _TagDef(
    'schedule',
    'Schedule',
    Color(0xFF2E82FF),
    Icons.calendar_today_rounded,
  ),
  _TagDef('task', 'Task', Color(0xFF10B981), Icons.assignment_rounded),
];

const _allTags = [
  _TagDef(
    'announcement',
    'Announcement',
    Color(0xFFF97316),
    Icons.campaign_rounded,
  ),
  _TagDef(
    'question',
    'Question',
    Color(0xFF2E82FF),
    Icons.help_outline_rounded,
  ),
  _TagDef('discussion', 'Discussion', Color(0xFF10B981), Icons.forum_rounded),
  _TagDef(
    'achievement',
    'Achievement',
    Color(0xFFF59E0B),
    Icons.emoji_events_rounded,
  ),
  _TagDef('idea', 'Idea', Color(0xFF7C5CF6), Icons.lightbulb_outline_rounded),
  _TagDef(
    'schedule',
    'Schedule',
    Color(0xFF2E82FF),
    Icons.calendar_today_rounded,
  ),
  _TagDef('task', 'Task', Color(0xFF10B981), Icons.assignment_rounded),
];

_TagDef? _findTag(String? key) {
  if (key == null) return null;
  try {
    return _tags.firstWhere((t) => t.key == key);
  } catch (_) {
    return null;
  }
}

/// Splits `[TAG:key] content` → (tagKey, cleanContent)
(String?, String) _parsePostContent(String raw) {
  final m = RegExp(r'^\[TAG:(\w+)\]\s*').firstMatch(raw);
  if (m == null) return (null, raw);
  return (m.group(1), raw.substring(m.end));
}

// ─────────────────────────────────────────────
// REACTION SYSTEM
// ─────────────────────────────────────────────
class _ReactionDef {
  final String emoji;
  final String label;
  final Color color;
  const _ReactionDef(this.emoji, this.label, this.color);
}

const _reactions = [
  _ReactionDef('❤️', 'Love', Color(0xFFEF4444)),
  _ReactionDef('🔥', 'Fire', Color(0xFFF97316)),
  _ReactionDef('🤯', 'Mind-blown', Color(0xFF7C5CF6)),
  _ReactionDef('😂', 'Haha', Color(0xFFF59E0B)),
  _ReactionDef('👏', 'Clap', Color(0xFF10B981)),
];

_ReactionDef? _findReaction(String? emoji) {
  if (emoji == null) return null;
  try {
    return _reactions.firstWhere((r) => r.emoji == emoji);
  } catch (_) {
    return null;
  }
}

// ─────────────────────────────────────────────
// FEED SCREEN
// ─────────────────────────────────────────────
class FeedScreen extends StatefulWidget {
  final int groupId;
  final String? category;
  const FeedScreen({super.key, required this.groupId, this.category});

  @override
  FeedScreenState createState() => FeedScreenState();
}

class FeedScreenState extends State<FeedScreen> {
  List<Map<String, dynamic>> _posts = [];
  final _postCtrl = TextEditingController();
  bool _isPosting = false;
  bool _isLoading = true;
  int _currentUserId = 0;
  String _currentUsername = "";
  bool _isAdmin = false;
  String? _pendingImageUri;
  String _groupCategory = "";

  bool get _isSchoolGroup => _groupCategory == "school";

  List<_TagDef> get _currentTags {
    if (_isSchoolGroup) return _schoolTags;
    return _tags;
  }

  List<_TagDef> get _currentFilterTags {
    if (_isSchoolGroup) return _schoolTags;
    return _allTags;
  }

  // ── New: Focus Mode ────────────────────────
  bool _focusMode = false;

  // ── New: Tag filter & post-tag selector ───
  String? _activeTagFilter;
  String? _selectedPostTag;

  // ── Derived: filtered post list ───────────
  List<Map<String, dynamic>> get _filteredPosts {
    var posts = _posts;

    // Focus Mode: only show posts from the last 7 days
    if (_focusMode) {
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      posts = posts.where((p) {
        final iso = p["created_at"] as String?;
        if (iso == null) return false;
        try {
          return DateTime.parse(iso).isAfter(cutoff);
        } catch (_) {
          return false;
        }
      }).toList();
    }

    // Tag filter
    if (_activeTagFilter != null) {
      posts = posts.where((p) {
        final raw = (p["content"] ?? "") as String;
        final (tag, _) = _parsePostContent(raw);
        return tag == _activeTagFilter;
      }).toList();
    }

    return posts;
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final profile = await ApiService.getProfile();
    if (!mounted) return;
    setState(() {
      _currentUserId = (profile?["id"] as int?) ?? 0;
      _currentUsername = (profile?["username"] as String?) ?? "";
      _groupCategory = widget.category ?? "";
    });
    if (_groupCategory.isEmpty) {
      await _loadGroupCategory();
    }
    await _checkAdmin();
    await _loadPosts();
  }

  Future<void> _loadGroupCategory() async {
    final info = await ApiService.getGroupInfo(widget.groupId);
    if (!mounted) return;
    if (info != null) {
      setState(() {
        _groupCategory = (info["category"] as String?) ?? "";
      });
    }
  }

  Future<void> _checkAdmin() async {
    final info = await ApiService.getGroupInfo(widget.groupId);
    if (!mounted || info == null) return;
    final members = (info["members"] as List?) ?? [];
    for (final m in members) {
      if (m["user_id"] == _currentUserId) {
        final role = m["role"] ?? "member";
        setState(() => _isAdmin = role == "owner" || role == "admin");
        break;
      }
    }
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getPosts(widget.groupId);
    if (!mounted) return;
    setState(() {
      _posts = data.cast<Map<String, dynamic>>();
      _isLoading = false;
    });
  }

  Future<void> _pickImage() async {
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
    setState(
      () => _pendingImageUri = 'data:$mime;base64,${base64Encode(bytes!)}',
    );
  }

  Future<void> _createPost() async {
    final text = _postCtrl.text.trim();
    if (text.isEmpty && _pendingImageUri == null) return;

    // Encode tag prefix when set
    final fullContent = _selectedPostTag != null
        ? '[TAG:$_selectedPostTag] $text'
        : text;

    setState(() => _isPosting = true);
    final result = await ApiService.createPost(
      widget.groupId,
      fullContent,
      mediaUrl: _pendingImageUri,
    );
    if (!mounted) return;
    setState(() {
      _isPosting = false;
      _pendingImageUri = null;
      _selectedPostTag = null;
    });
    if (result != null) {
      _postCtrl.clear();
      await _loadPosts();
    }
  }

  Future<void> _openChat() async {
    final token = await ApiService.getToken();
    if (token == null) return;
    List channels = await ApiService.getChannels(widget.groupId);
    if (!mounted) return;
    if (channels.isEmpty) {
      final created = await ApiService.createChannel(widget.groupId, "general");
      if (!mounted) return;
      if (created == null) return;
      channels = [created];
    }
    final channelId = channels[0]["id"] as int;
    final channelName = channels[0]["name"] as String? ?? "general";
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          channelId: channelId,
          token: token,
          channelName: channelName,
          groupId: widget.groupId,
          currentUserId: _currentUserId,
        ),
      ),
    );
  }

  Future<void> _showFilesSheet() async {
    final files = await ApiService.getFiles(widget.groupId);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => _FilesSheet(
          groupId: widget.groupId,
          files: files.cast<Map<String, dynamic>>(),
          scrollController: scrollCtrl,
          isAdmin: _isAdmin,
        ),
      ),
    );
  }

  Future<void> _showTasksSheet() async {
    final tasks = await ApiService.getTasks(widget.groupId);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => _TasksSheet(
          groupId: widget.groupId,
          tasks: tasks.cast<Map<String, dynamic>>(),
          scrollController: scrollCtrl,
          isAdmin: _isAdmin,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Group Feed",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              "Group #${widget.groupId}",
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          // ── Focus Mode toggle ──────────────
          Tooltip(
            message: _focusMode
                ? 'Exit Focus Mode'
                : 'Focus Mode (last 7 days)',
            child: GestureDetector(
              onTap: () => setState(() => _focusMode = !_focusMode),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _focusMode
                      ? _primary.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _focusMode ? _primary : _border,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.center_focus_strong_rounded,
                      size: 14,
                      color: _focusMode ? _primary : _textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Focus",
                      style: TextStyle(
                        fontSize: 12,
                        color: _focusMode ? _primary : _textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isSchoolGroup) ...[
            IconButton(
              icon: const Icon(Icons.folder_outlined, color: _textSecondary),
              onPressed: () => _showFilesSheet(),
              tooltip: "Files",
            ),
            IconButton(
              icon: const Icon(
                Icons.check_circle_outline_rounded,
                color: _textSecondary,
              ),
              onPressed: () => _showTasksSheet(),
              tooltip: "Tasks",
            ),
          ],
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: _textSecondary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroupInfoScreen(
                  groupId: widget.groupId,
                  currentUserId: _currentUserId,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildChatFab(),
      body: Column(
        children: [
          // ── Focus Mode banner ──────────────
          if (_focusMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: _primary.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(
                    Icons.center_focus_strong_rounded,
                    size: 14,
                    color: _primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Focus Mode — showing posts from the last 7 days",
                    style: TextStyle(
                      color: _primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          _buildCreatePostCard(),

          // ── Tag filter chips ───────────────
          _buildTagFilterRow(),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _primary),
                  )
                : RefreshIndicator(
                    color: _primary,
                    backgroundColor: _surface,
                    onRefresh: _loadPosts,
                    child: _filteredPosts.isEmpty
                        ? _buildEmptyFeed()
                        : _buildPostList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatFab() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C5CF6), Color(0xFF2E82FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C5CF6).withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _openChat,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  "Open Chat",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // TAG FILTER ROW
  // ─────────────────────────────────────────
  Widget _buildTagFilterRow() {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        children: [
          // "All" chip
          _FilterChip(
            label: "All",
            icon: Icons.dynamic_feed_rounded,
            color: _textSecondary,
            selected: _activeTagFilter == null,
            onTap: () => setState(() => _activeTagFilter = null),
          ),
          const SizedBox(width: 6),
          ..._currentFilterTags.map(
            (t) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _FilterChip(
                label: t.label,
                icon: t.icon,
                color: t.color,
                selected: _activeTagFilter == t.key,
                onTap: () => setState(() {
                  _activeTagFilter = _activeTagFilter == t.key ? null : t.key;
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // CREATE POST CARD
  // ─────────────────────────────────────────
  Widget _buildCreatePostCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Tag selector ──────────────────
            SizedBox(
              height: 30,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _currentTags.map((t) {
                  final selected = _selectedPostTag == t.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(
                        () => _selectedPostTag = selected ? null : t.key,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? t.color.withValues(alpha: 0.15)
                              : _elevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? t.color : _border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              t.icon,
                              size: 12,
                              color: selected ? t.color : _textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              t.label,
                              style: TextStyle(
                                fontSize: 11,
                                color: selected ? t.color : _textSecondary,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _postCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: "What's on your mind?",
                hintStyle: TextStyle(color: _textSecondary),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
            if (_pendingImageUri != null) ...[
              const SizedBox(height: 8),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      base64Decode(_pendingImageUri!.split(',')[1]),
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() => _pendingImageUri = null),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.image_outlined,
                    color: _textSecondary,
                    size: 22,
                  ),
                  onPressed: _pickImage,
                  tooltip: "Attach image",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Text(
                  "Photo",
                  style: TextStyle(color: _textSecondary, fontSize: 13),
                ),
                const Spacer(),
                SizedBox(
                  height: 34,
                  child: ElevatedButton(
                    onPressed: _isPosting ? null : _createPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      disabledBackgroundColor: _border,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: _isPosting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Post",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _filteredPosts.length,
      itemBuilder: (_, i) => _PostCard(
        post: _filteredPosts[i],
        currentUserId: _currentUserId,
        currentUsername: _currentUsername,
        isAdmin: _isAdmin,
        groupId: widget.groupId,
        onRefresh: _loadPosts,
      ),
    );
  }

  Widget _buildEmptyFeed() {
    final isFiltered = _activeTagFilter != null || _focusMode;
    return ListView(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.dynamic_feed_outlined,
                  size: 34,
                  color: _primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isFiltered ? "No posts match this filter" : "No posts yet",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isFiltered
                    ? "Try a different tag or turn off Focus Mode"
                    : "Be the first to share something!",
                style: TextStyle(color: _textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FILTER CHIP (feed tag filter row)
// ─────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : _elevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: selected ? color : _textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected ? color : _textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// POST CARD
// ─────────────────────────────────────────────────────────────
class _PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final int currentUserId;
  final String currentUsername;
  final bool isAdmin;
  final int groupId;
  final VoidCallback onRefresh;

  const _PostCard({
    required this.post,
    required this.currentUserId,
    required this.currentUsername,
    required this.isAdmin,
    required this.groupId,
    required this.onRefresh,
  });

  @override
  _PostCardState createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard>
    with SingleTickerProviderStateMixin {
  late bool _isLiked;
  late int _likeCount;
  late bool _isPinned;
  bool _showComments = false;
  List<Map<String, dynamic>> _comments = [];
  bool _loadingComments = false;
  final _commentCtrl = TextEditingController();
  bool _sendingComment = false;
  late AnimationController _heartAnim;

  // ── New: Reactions ─────────────────────────
  String? _myReaction; // emoji string, e.g. "🔥"
  bool _showReactionBar = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post["is_liked_by_me"] == true;
    _likeCount = (widget.post["like_count"] as int?) ?? 0;
    _isPinned = widget.post["is_pinned"] == true;
    // Restore default reaction from existing like state
    if (_isLiked) _myReaction = '❤️';
    _heartAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _heartAnim.dispose();
    super.dispose();
  }

  int get _postId => widget.post["id"] as int;
  int get _postUserId => widget.post["user_id"] as int;

  Color get _userColor {
    const colors = [
      Color(0xFF7C5CF6),
      Color(0xFF2E82FF),
      Color(0xFFEC4899),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
    ];
    final username = widget.post["username"]?.toString() ?? "";
    return colors[username.hashCode.abs() % colors.length];
  }

  // Border accent colour based on current user's reaction
  Color get _reactionAccentColor {
    if (_myReaction == null) return Colors.transparent;
    return _findReaction(_myReaction)?.color.withValues(alpha: 0.6) ??
        Colors.transparent;
  }

  String _timeAgo(String? iso) {
    if (iso == null) return "";
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return "just now";
      if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
      if (diff.inHours < 24) return "${diff.inHours}h ago";
      if (diff.inDays < 7) return "${diff.inDays}d ago";
      return "${dt.day}/${dt.month}/${dt.year}";
    } catch (_) {
      return "";
    }
  }

  // ─── Reactions ──────────────────────────────
  Future<void> _applyReaction(String emoji) async {
    setState(() => _showReactionBar = false);

    if (_myReaction == emoji) {
      // Tapping same reaction removes it
      setState(() {
        _myReaction = null;
        _isLiked = false;
        _likeCount = (_likeCount - 1).clamp(0, 999999);
      });
      await ApiService.toggleLike(_postId); // un-like on backend
      return;
    }

    final wasLiked = _isLiked;
    setState(() {
      _myReaction = emoji;
      _isLiked = true;
      if (!wasLiked) _likeCount += 1;
    });
    _heartAnim.forward(from: 0);

    if (!wasLiked) {
      await ApiService.toggleLike(_postId); // register like on backend
    }
  }

  Future<void> _quickTapReaction() async {
    if (_showReactionBar) {
      setState(() => _showReactionBar = false);
      return;
    }
    // Quick tap: toggle current reaction (or default ❤️)
    final current = _myReaction ?? '❤️';
    await _applyReaction(current);
  }

  // ─── Comments ──────────────────────────────
  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    final data = await ApiService.getComments(_postId);
    if (!mounted) return;
    setState(() {
      _comments = data.cast<Map<String, dynamic>>();
      _loadingComments = false;
    });
  }

  Future<void> _toggleComments() async {
    setState(() => _showComments = !_showComments);
    if (_showComments) await _loadComments();
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sendingComment = true);
    final result = await ApiService.addComment(_postId, text);
    if (!mounted) return;
    setState(() => _sendingComment = false);
    if (result != null) {
      _commentCtrl.clear();
      await _loadComments();
      setState(() => widget.post["comment_count"] = (_comments.length));
    }
  }

  Future<void> _deleteComment(int commentId) async {
    await ApiService.deleteComment(commentId);
    if (!mounted) return;
    await _loadComments();
    setState(() => widget.post["comment_count"] = _comments.length);
  }

  void _showLikersDialog() {
    final likers =
        (widget.post["likers"] as List?)?.cast<Map<String, dynamic>>() ?? [];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Liked by",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: likers.isEmpty
            ? Text("No likes yet", style: TextStyle(color: _textSecondary))
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: likers.length,
                  itemBuilder: (_, i) {
                    final u = likers[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          _buildAvatar(
                            u["avatar_url"],
                            u["username"] ?? "?",
                            16,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            u["username"] ?? "",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close", style: TextStyle(color: _primary)),
          ),
        ],
      ),
    );
  }

  void _showPostMenu() {
    final isOwn = _postUserId == widget.currentUserId;
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwn) ...[
              _menuItem(
                Icons.edit_rounded,
                "Edit Post",
                Colors.white,
                _editPost,
              ),
              _menuItem(
                Icons.delete_rounded,
                "Delete Post",
                _danger,
                _deletePost,
              ),
            ],
            if (widget.isAdmin)
              _menuItem(
                _isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                _isPinned ? "Unpin Post" : "Pin Post",
                _pinColor,
                _togglePin,
              ),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _editPost() {
    final ctrl = TextEditingController(text: widget.post["content"] ?? "");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Edit Post",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          maxLines: 5,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Edit your post...",
            hintStyle: TextStyle(color: _textSecondary),
            filled: true,
            fillColor: _elevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ApiService.editPost(_postId, ctrl.text.trim());
              if (ok) widget.onRefresh();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _deletePost() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Delete Post",
          style: TextStyle(color: _danger, fontWeight: FontWeight.w700),
        ),
        content: Text(
          "Are you sure you want to delete this post?",
          style: TextStyle(color: _textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ApiService.deletePost(_postId);
              if (ok) widget.onRefresh();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePin() async {
    final ok = await ApiService.pinPost(_postId);
    if (ok) {
      setState(() => _isPinned = !_isPinned);
      widget.onRefresh();
    }
  }

  Widget _buildAvatar(String? avatarUrl, String name, double radius) {
    const colors = [
      Color(0xFF7C5CF6),
      Color(0xFF2E82FF),
      Color(0xFFEC4899),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
    ];
    final color = colors[name.hashCode.abs() % colors.length];
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
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.2),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : "?",
        style: TextStyle(
          color: color,
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildContent(String content) {
    final parts = content.split(RegExp(r'(@\w+)'));
    final spans = <TextSpan>[];
    for (final p in parts) {
      if (p.startsWith('@')) {
        spans.add(
          TextSpan(
            text: p,
            style: const TextStyle(
              color: _primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: p));
      }
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
        children: spans,
      ),
    );
  }

  // ─── Reaction bar ───────────────────────────
  Widget _buildReactionBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _elevated,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _reactions.map((r) {
            final isActive = _myReaction == r.emoji;
            return GestureDetector(
              onTap: () => _applyReaction(r.emoji),
              child: Tooltip(
                message: r.label,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? r.color.withValues(alpha: 0.2)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    r.emoji,
                    style: TextStyle(fontSize: isActive ? 26 : 22),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final username = post["username"]?.toString() ?? "Unknown";
    final avatarUrl = post["avatar_url"] as String?;
    final rawContent = (post["content"] ?? "") as String;
    final (tagKey, cleanContent) = _parsePostContent(rawContent);
    final tagDef = _findTag(tagKey);
    final mediaUrl = post["media_url"] as String?;
    final createdAt = post["created_at"] as String?;
    final commentCount = (post["comment_count"] as int?) ?? 0;
    final isOwn = _postUserId == widget.currentUserId;
    final showMenu = isOwn || widget.isAdmin;

    final reactionDef = _findReaction(_myReaction);
    final reactionColor = reactionDef?.color ?? _textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            // Reaction accent on left edge
            left: BorderSide(
              color: _myReaction != null
                  ? _reactionAccentColor
                  : (_isPinned ? _pinColor.withValues(alpha: 0.5) : _border),
              width: _myReaction != null ? 3 : 1,
            ),
            right: BorderSide(
              color: _isPinned ? _pinColor.withValues(alpha: 0.5) : _border,
            ),
            top: BorderSide(
              color: _isPinned ? _pinColor.withValues(alpha: 0.5) : _border,
            ),
            bottom: BorderSide(
              color: _isPinned ? _pinColor.withValues(alpha: 0.5) : _border,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 0),
              child: Row(
                children: [
                  if (_isPinned) ...[
                    const Icon(
                      Icons.push_pin_rounded,
                      color: _pinColor,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                  ],
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MemberProfileScreen(
                          userId: _postUserId,
                          groupId: widget.groupId,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildAvatar(avatarUrl, username, 18),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              username,
                              style: TextStyle(
                                color: _userColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _timeAgo(createdAt),
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // ── Tag badge ────────────────────
                  if (tagDef != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: tagDef.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: tagDef.color.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(tagDef.icon, size: 10, color: tagDef.color),
                          const SizedBox(width: 3),
                          Text(
                            tagDef.label,
                            style: TextStyle(
                              fontSize: 10,
                              color: tagDef.color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (showMenu)
                    IconButton(
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        color: _textSecondary,
                        size: 20,
                      ),
                      onPressed: _showPostMenu,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),

            // ── Content ──────────────────────────────
            if (cleanContent.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: _buildContent(cleanContent),
              ),

            // ── Image ────────────────────────────────
            if (mediaUrl != null && mediaUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.zero,
                child: _buildMediaImage(mediaUrl),
              ),
            ],

            // ── Reaction bar (shown on long-press) ───
            if (_showReactionBar) ...[
              const SizedBox(height: 6),
              _buildReactionBar(),
            ],

            // ── Actions ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Row(
                children: [
                  // Reaction button (tap = quick toggle, long-press = picker)
                  GestureDetector(
                    onTap: _quickTapReaction,
                    onLongPress: () =>
                        setState(() => _showReactionBar = !_showReactionBar),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          ScaleTransition(
                            scale: Tween(begin: 1.0, end: 1.4).animate(
                              CurvedAnimation(
                                parent: _heartAnim,
                                curve: Curves.elasticOut,
                              ),
                            ),
                            child: _myReaction != null
                                ? Text(
                                    _myReaction!,
                                    style: const TextStyle(fontSize: 20),
                                  )
                                : Icon(
                                    Icons.favorite_border_rounded,
                                    color: _textSecondary,
                                    size: 20,
                                  ),
                          ),
                          if (_likeCount > 0) ...[
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: _likeCount > 0 ? _showLikersDialog : null,
                              child: Text(
                                "$_likeCount",
                                style: TextStyle(
                                  color: reactionColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor: reactionColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Comment button
                  _ActionButton(
                    icon: Icon(
                      _showComments
                          ? Icons.chat_bubble_rounded
                          : Icons.chat_bubble_outline_rounded,
                      color: _showComments ? _primary : _textSecondary,
                      size: 20,
                    ),
                    label: commentCount > 0 ? "$commentCount" : "",
                    onTap: _toggleComments,
                    color: _showComments ? _primary : _textSecondary,
                  ),

                  // Hint label for long-press
                  if (_myReaction == null && _likeCount == 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        "Hold to react",
                        style: TextStyle(
                          color: _textSecondary.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Comments Section ──────────────────────
            if (_showComments) _buildCommentsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaImage(String mediaUrl) {
    try {
      if (mediaUrl.startsWith('data:')) {
        final bytes = base64Decode(mediaUrl.split(',')[1]);
        return Image.memory(bytes, width: double.infinity, fit: BoxFit.cover);
      }
      return Image.network(mediaUrl, width: double.infinity, fit: BoxFit.cover);
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildCommentsSection() {
    return Container(
      decoration: BoxDecoration(
        color: _bg.withValues(alpha: 0.6),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: Color(0xFF2D2D4A), height: 1),
          if (_loadingComments)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: _primary,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else if (_comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                "No comments yet. Be the first!",
                style: TextStyle(color: _textSecondary, fontSize: 13),
              ),
            )
          else
            ..._comments.map((c) => _buildCommentTile(c)),

          // Comment input
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                _buildAvatar(null, widget.currentUsername, 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _elevated,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _border),
                    ),
                    child: TextField(
                      controller: _commentCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendComment(),
                      decoration: InputDecoration(
                        hintText: "Write a comment...",
                        hintStyle: TextStyle(
                          color: _textSecondary,
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _sendComment,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF7C5CF6), Color(0xFF2E82FF)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: _sendingComment
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 1.5,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentTile(Map<String, dynamic> c) {
    final isOwn = (c["user_id"] as int?) == widget.currentUserId;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(c["avatar_url"], c["username"] ?? "?", 14),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _elevated,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        c["username"] ?? "",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _timeAgo(c["created_at"]),
                        style: TextStyle(color: _textSecondary, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c["content"] ?? "",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isOwn) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _deleteComment(c["id"] as int),
              child: Icon(Icons.close_rounded, color: _textSecondary, size: 16),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ACTION BUTTON HELPER
// ─────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: icon,
          ),
        ),
        if (label.isNotEmpty)
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// FILES SHEET (School group material sharing)
// ─────────────────────────────────────────────────────────
class _FilesSheet extends StatefulWidget {
  final int groupId;
  final List<Map<String, dynamic>> files;
  final ScrollController scrollController;
  final bool isAdmin;

  const _FilesSheet({
    required this.groupId,
    required this.files,
    required this.scrollController,
    required this.isAdmin,
  });

  @override
  _FilesSheetState createState() => _FilesSheetState();
}

class _FilesSheetState extends State<_FilesSheet> {
  // ignore: unused_field
  bool _isUploading = false;

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    List<int>? bytes;
    if (file.bytes != null) {
      bytes = file.bytes;
    } else if (file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null) return;
    setState(() => _isUploading = true);
    final b64 = base64Encode(bytes);
    final ext = (file.extension ?? '').toLowerCase();
    final mime = ext == 'pdf'
        ? 'application/pdf'
        : ext == 'png'
        ? 'image/png'
        : ext == 'jpg' || ext == 'jpeg'
        ? 'image/jpeg'
        : 'application/octet-stream';
    await ApiService.uploadFile(widget.groupId, file.name, b64, mime);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.folder_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
                "School Materials",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (widget.isAdmin)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: _primary),
                  onPressed: _pickAndUpload,
                ),
            ],
          ),
        ),
        const Divider(color: _border),
        Expanded(
          child: widget.files.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.folder_open_rounded,
                        size: 48,
                        color: _textSecondary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "No files yet",
                        style: TextStyle(color: _textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.files.length,
                  itemBuilder: (_, i) {
                    final f = widget.files[i];
                    return _FileCard(
                      file: f,
                      onDelete: widget.isAdmin
                          ? () async {
                              await ApiService.deleteFile(f["id"] as int);
                              if (mounted) Navigator.pop(context);
                            }
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FileCard extends StatelessWidget {
  final Map<String, dynamic> file;
  final VoidCallback? onDelete;

  const _FileCard({required this.file, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name = file["name"] as String? ?? "Untitled";
    final size = (file["size"] as num?) ?? 0;
    final sizeStr = size < 1024
        ? "$size B"
        : size < 1024 * 1024
        ? "${(size / 1024).toStringAsFixed(1)} KB"
        : "${(size / (1024 * 1024)).toStringAsFixed(1)} MB";
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.insert_drive_file_outlined,
              color: _primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  sizeStr,
                  style: TextStyle(color: _textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: _danger, size: 20),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: _surface,
                  title: const Text(
                    "Delete file?",
                    style: TextStyle(color: Colors.white),
                  ),
                  content: Text(
                    "Are you sure you want to delete $name?",
                    style: TextStyle(color: _textSecondary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Cancel",
                        style: TextStyle(color: _textSecondary),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onDelete!();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _danger,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Delete"),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────���─��───────────────────────────────────
// TASKS SHEET (School group deadline tracking)
// ─────────────────────────────────────────────────────────
class _TasksSheet extends StatefulWidget {
  final int groupId;
  final List<Map<String, dynamic>> tasks;
  final ScrollController scrollController;
  final bool isAdmin;

  const _TasksSheet({
    required this.groupId,
    required this.tasks,
    required this.scrollController,
    required this.isAdmin,
  });

  @override
  _TasksSheetState createState() => _TasksSheetState();
}

class _TasksSheetState extends State<_TasksSheet> {
  final _titleCtrl = TextEditingController();
  DateTime? _dueDate;
  bool _isCreating = false;

  Future<void> _createTask() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _isCreating = true);
    final dueStr = _dueDate != null
        ? _dueDate!.toIso8601String().split('T')[0]
        : null;
    await ApiService.createTask(
      widget.groupId,
      _titleCtrl.text.trim(),
      null,
      dueStr,
      null,
    );
    if (mounted) Navigator.pop(context);
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        title: const Text(
          "Add Task",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Task title",
                hintStyle: TextStyle(color: _textSecondary),
                filled: true,
                fillColor: _elevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _border),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) setState(() => _dueDate = date);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: _elevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: _textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _dueDate != null
                          ? "${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}"
                          : "Due date (optional)",
                      style: TextStyle(
                        color: _dueDate != null ? Colors.white : _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: _isCreating ? null : _createTask,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
            child: const Text("Add Task"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                "Tasks & Deadlines",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (widget.isAdmin)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: _primary),
                  onPressed: _showCreateDialog,
                ),
            ],
          ),
        ),
        const Divider(color: _border),
        Expanded(
          child: widget.tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        size: 48,
                        color: _textSecondary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "No tasks yet",
                        style: TextStyle(color: _textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.tasks.length,
                  itemBuilder: (_, i) {
                    final t = widget.tasks[i];
                    return _TaskCard(
                      task: t,
                      onToggle: () async {
                        await ApiService.completeTask(t["id"] as int);
                        if (mounted) Navigator.pop(context);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onToggle;

  const _TaskCard({required this.task, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final title = task["title"] as String? ?? "Untitled";
    final due = task["due_date"] as String?;
    final isComplete = task["completed"] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isComplete ? _elevated.withValues(alpha: 0.5) : _elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isComplete ? Colors.transparent : _border),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isComplete ? _primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isComplete ? _primary : _textSecondary,
                  width: 2,
                ),
              ),
              child: isComplete
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isComplete ? _textSecondary : Colors.white,
                    fontSize: 14,
                    decoration: isComplete ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (due != null)
                  Text(
                    "Due: $due",
                    style: TextStyle(color: _danger, fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
