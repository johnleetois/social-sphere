import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'feed_screen.dart';

const _bg = Color(0xFF0D0D1A);
const _surface = Color(0xFF1C1C2E);
const _primary = Color(0xFF7C5CF6);
const _textSecondary = Color(0xFF8B8BA7);
const _border = Color(0xFF2D2D4A);

class _CategoryOption {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const _CategoryOption(this.key, this.label, this.icon, this.color);
}

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  GroupScreenState createState() => GroupScreenState();
}

class GroupScreenState extends State<GroupScreen> {
  final nameController = TextEditingController();
  final descController = TextEditingController();
  final purposeController = TextEditingController();
  final groupIdController = TextEditingController();

  String _selectedCategory = "friends";
  String message = "";
  bool isCreating = false;
  bool isJoining = false;

  static const _categories = [
    _CategoryOption(
      "friends",
      "Friends",
      Icons.people_rounded,
      Color(0xFF10B981),
    ),
    _CategoryOption(
      "family",
      "Family",
      Icons.family_restroom_rounded,
      Color(0xFFEC4899),
    ),
    _CategoryOption(
      "school",
      "School",
      Icons.school_rounded,
      Color(0xFF2E82FF),
    ),
  ];

  Future<void> createGroup() async {
    if (nameController.text.trim().isEmpty) {
      setState(() => message = "Group name is required");
      return;
    }
    setState(() {
      isCreating = true;
      message = "";
    });

    final result = await ApiService.createGroup(
      nameController.text.trim(),
      descController.text.trim(),
      purposeController.text.trim(),
      category: _selectedCategory,
    );

    if (!mounted) return;
    setState(() => isCreating = false);

    if (result != null) {
      final groupId = result["id"] is int
          ? result["id"] as int
          : int.parse(result["id"].toString());
      final category = result["category"] as String? ?? _selectedCategory;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FeedScreen(groupId: groupId, category: category),
        ),
      );
    } else {
      setState(() => message = "Failed to create group. Try again.");
    }
  }

  Future<void> joinGroup() async {
    final code = groupIdController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => message = "Invite code is required");
      return;
    }
    setState(() {
      isJoining = true;
      message = "";
    });

    final result = await ApiService.joinGroupByCode(code);

    if (!mounted) return;
    setState(() => isJoining = false);

    if (result == null || result.containsKey("error")) {
      setState(() => message = result?["error"] ?? "Failed to join group");
      return;
    }

    final groupId = result["group_id"] as int;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => FeedScreen(groupId: groupId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
          title: const Text(
            "Groups",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          bottom: TabBar(
            indicatorColor: _primary,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: _primary,
            unselectedLabelColor: _textSecondary,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: "Create"),
              Tab(text: "Join"),
            ],
          ),
        ),
        body: TabBarView(children: [_buildCreateTab(), _buildJoinTab()]),
      ),
    );
  }

  Widget _buildCreateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            "Create a new group",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Build a community around your interests",
            style: TextStyle(color: _textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 28),
          _buildInput(
            nameController,
            "Group Name",
            Icons.group_outlined,
            hint: "e.g. Flutter Devs",
          ),
          const SizedBox(height: 16),
          _buildInput(
            descController,
            "Description",
            Icons.description_outlined,
            hint: "What is this group about?",
          ),
          const SizedBox(height: 16),
          _buildInput(
            purposeController,
            "Purpose",
            Icons.flag_outlined,
            hint: "What's the goal?",
          ),
          const SizedBox(height: 20),
          const Text(
            "Category",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: _categories.map((c) {
              final selected = _selectedCategory == c.key;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedCategory = c.key),
                  child: Container(
                    margin: EdgeInsets.only(right: selected ? 12 : 8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? c.color.withValues(alpha: 0.15)
                          : _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? c.color : _border,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          c.icon,
                          color: selected ? c.color : _textSecondary,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          c.label,
                          style: TextStyle(
                            color: selected ? c.color : _textSecondary,
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w600
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
          const SizedBox(height: 28),
          _buildErrorBanner(),
          _buildGradientButton(
            onPressed: isCreating ? null : createGroup,
            isLoading: isCreating,
            label: "Create Group",
          ),
        ],
      ),
    );
  }

  Widget _buildJoinTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            "Join a group",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Enter the invite code to join an existing community",
            style: TextStyle(color: _textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 28),
          _buildInput(
            groupIdController,
            "Invite Code",
            Icons.vpn_key_rounded,
            hint: "e.g. XYZ7K3PQ",
          ),
          const SizedBox(height: 28),
          _buildErrorBanner(),
          _buildGradientButton(
            onPressed: isJoining ? null : joinGroup,
            isLoading: isJoining,
            label: "Join Group",
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    if (message.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(
    TextEditingController controller,
    String label,
    IconData icon, {
    String hint = "",
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: _textSecondary),
            prefixIcon: Icon(icon, color: _textSecondary, size: 20),
            filled: true,
            fillColor: _surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGradientButton({
    required VoidCallback? onPressed,
    required String label,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed != null
              ? const LinearGradient(
                  colors: [Color(0xFF7C5CF6), Color(0xFF2E82FF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: onPressed == null ? _border : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white54,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }
}
