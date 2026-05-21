import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = "http://127.0.0.1:8000";

  static Future<Map<String, dynamic>?> login(
    String email,
    String password,
  ) async {
    log("SENDING LOGIN REQUEST...");

    final response = await http.post(
      Uri.parse("$baseUrl/auth/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );

    log("STATUS: ${response.statusCode}");
    log("BODY: ${response.body}");

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    return null;
  }

  static Future<bool> register(
    String username,
    String email,
    String password,
  ) async {
    return registerFull(
      username: username,
      email: email,
      password: password,
      fullName: "",
      birthdate: "",
      gender: "",
      mobile: "",
      address: "",
      facebook: "",
      hobbies: "",
      bio: "",
    );
  }

  static Future<bool> registerFull({
    required String username,
    required String email,
    required String password,
    required String fullName,
    required String birthdate,
    required String gender,
    required String mobile,
    required String address,
    required String facebook,
    required String hobbies,
    required String bio,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "username": username,
        "email": email,
        "password": password,
        "full_name": fullName,
        "birthdate": birthdate,
        "gender": gender,
        "mobile": mobile,
        "address": address,
        "facebook_link": facebook,
        "hobbies": hobbies,
        "bio": bio,
      }),
    );

    log("REGISTER STATUS: ${response.statusCode}");
    log("REGISTER BODY: ${response.body}");

    return response.statusCode == 200;
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("token");
  }

  static Future<Map<String, dynamic>?> createGroup(
    String name,
    String description,
    String purpose, {
    String category = "friends",
  }) async {
    final token = await getToken();

    final response = await http.post(
      Uri.parse("$baseUrl/groups/create"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "name": name,
        "description": description,
        "purpose": purpose,
        "type": "public",
        "category": category,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    return null;
  }

  static Future<bool> joinGroup(int groupId) async {
    final token = await getToken();

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/groups/join"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"group_id": groupId}),
      );

      log("STATUS: ${response.statusCode}");
      log("BODY: ${response.body}");

      if (response.statusCode == 200) return true;
      if (response.statusCode == 400 &&
          response.body.contains("Already a member")) {
        return true;
      }

      return false;
    } catch (e) {
      log("ERROR: $e");
      return false;
    }
  }

  // Returns the group_id on success, null on failure.
  // errMsg is set if the code was invalid.
  static Future<Map<String, dynamic>?> joinGroupByCode(String code) async {
    final token = await getToken();

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/groups/join-by-code"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"code": code.trim().toUpperCase()}),
      );

      log("JOIN-BY-CODE STATUS: ${response.statusCode}");
      log("JOIN-BY-CODE BODY: ${response.body}");

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 404) {
        return {"error": "Invalid invite code"};
      }
      return {"error": "Failed to join group"};
    } catch (e) {
      log("JOIN-BY-CODE ERROR: $e");
      return {"error": "Network error"};
    }
  }

  static Future<List<dynamic>> getPosts(int groupId) async {
    final token = await getToken();

    final response = await http.get(
      Uri.parse("$baseUrl/posts/group/$groupId"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 401) {
      await _clearToken();
      return [];
    }

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    return [];
  }

  static Future<Map<String, dynamic>?> createPost(
    int groupId,
    String content, {
    String? mediaUrl,
  }) async {
    final token = await getToken();

    final body = <String, dynamic>{"group_id": groupId, "content": content};
    if (mediaUrl != null) body["media_url"] = mediaUrl;

    final response = await http.post(
      Uri.parse("$baseUrl/posts/"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 401) {
      await _clearToken();
      return null;
    }
    if (response.statusCode == 200) return jsonDecode(response.body);
    return null;
  }

  static Future<bool> editPost(int postId, String content) async {
    final token = await getToken();
    final response = await http.patch(
      Uri.parse("$baseUrl/posts/$postId"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"content": content}),
    );
    return response.statusCode == 200;
  }

  static Future<bool> deletePost(int postId) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse("$baseUrl/posts/$postId"),
      headers: {"Authorization": "Bearer $token"},
    );
    return response.statusCode == 200;
  }

  static Future<bool> pinPost(int postId) async {
    final token = await getToken();
    final response = await http.patch(
      Uri.parse("$baseUrl/posts/$postId/pin"),
      headers: {"Authorization": "Bearer $token"},
    );
    return response.statusCode == 200;
  }

  static Future<bool> toggleLike(int postId) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse("$baseUrl/reactions/toggle/$postId"),
      headers: {"Authorization": "Bearer $token"},
    );
    return response.statusCode == 200;
  }

  static Future<List<dynamic>> getLikers(int postId) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse("$baseUrl/reactions/$postId/likers"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<List<dynamic>> getComments(int postId) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse("$baseUrl/comments/$postId"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<Map<String, dynamic>?> addComment(
    int postId,
    String content,
  ) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse("$baseUrl/comments/"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"post_id": postId, "content": content}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    return null;
  }

  static Future<bool> deleteComment(int commentId) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse("$baseUrl/comments/$commentId"),
      headers: {"Authorization": "Bearer $token"},
    );
    return response.statusCode == 200;
  }

  static Future<List<dynamic>> getMyGroups() async {
    final token = await getToken();

    log("GET GROUPS TOKEN: $token");

    final response = await http.get(
      Uri.parse("$baseUrl/groups/my"),
      headers: {"Authorization": "Bearer $token"},
    );

    log("GROUP STATUS: ${response.statusCode}");
    log("GROUP BODY: ${response.body}");

    if (response.statusCode == 401) {
      await _clearToken();
      return [];
    }

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    return [];
  }

  static Future<List<dynamic>> getChannels(int groupId) async {
    final token = await getToken();

    final response = await http.get(
      Uri.parse("$baseUrl/channels/group/$groupId"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 401) {
      await _clearToken();
      return [];
    }

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    return [];
  }

  static Future<Map<String, dynamic>?> createChannel(
    int groupId,
    String name,
  ) async {
    final token = await getToken();

    final response = await http.post(
      Uri.parse("$baseUrl/channels/"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"group_id": groupId, "name": name, "type": "text"}),
    );

    if (response.statusCode == 401) {
      await _clearToken();
      return null;
    }

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    return null;
  }

  // ── DM ───────────────────────────────────────────────────

  static Future<List<dynamic>> getDmConversations() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse("$baseUrl/dm/conversations"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (response.statusCode == 401) {
      await _clearToken();
      return [];
    }
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<List<dynamic>> getDmHistory(
    int peerId, {
    int skip = 0,
    int limit = 50,
  }) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse("$baseUrl/dm/history/$peerId?skip=$skip&limit=$limit"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (response.statusCode == 401) {
      await _clearToken();
      return [];
    }
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // ── Group Info & Management ───────────────────────────────

  static Future<Map<String, dynamic>?> getGroupInfo(int groupId) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse("$baseUrl/groups/$groupId"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (response.statusCode == 401) {
      await _clearToken();
      return null;
    }
    if (response.statusCode == 200) return jsonDecode(response.body);
    return null;
  }

  static Future<bool> updateGroup(
    int groupId,
    Map<String, dynamic> data,
  ) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse("$baseUrl/groups/$groupId"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(data),
    );
    if (response.statusCode == 401) {
      await _clearToken();
      return false;
    }
    return response.statusCode == 200;
  }

  static Future<bool> updateMemberRole(
    int groupId,
    int userId,
    String role,
  ) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse("$baseUrl/groups/$groupId/members/$userId/role"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"role": role}),
    );
    return response.statusCode == 200;
  }

  static Future<String?> leaveGroup(int groupId) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse("$baseUrl/groups/$groupId/leave"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (response.statusCode == 200) return null;
    try {
      return jsonDecode(response.body)["detail"];
    } catch (_) {
      return "Failed to leave";
    }
  }

  // ── Profile ──────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getProfile() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse("$baseUrl/profile/me"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (response.statusCode == 401) {
      await _clearToken();
      return null;
    }
    if (response.statusCode == 200) return jsonDecode(response.body);
    return null;
  }

  static Future<bool> updateProfile(Map<String, dynamic> data) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse("$baseUrl/profile/me"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(data),
    );
    if (response.statusCode == 401) {
      await _clearToken();
      return false;
    }
    return response.statusCode == 200;
  }

  static Future<String?> changePassword(String current, String newPwd) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse("$baseUrl/profile/me/password"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"current_password": current, "new_password": newPwd}),
    );
    if (response.statusCode == 200) return null;
    try {
      final body = jsonDecode(response.body);
      return body["detail"] ?? "Failed to change password";
    } catch (_) {
      return "Failed to change password";
    }
  }

  static Future<bool> deleteAccount() async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse("$baseUrl/profile/me"),
      headers: {"Authorization": "Bearer $token"},
    );
    return response.statusCode == 200;
  }

  static Future<List<dynamic>> getLoginActivity() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse("$baseUrl/profile/me/activity"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (response.statusCode == 401) {
      await _clearToken();
      return [];
    }
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<List<dynamic>> getMyGroupStats() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse("$baseUrl/profile/me/groups-stats"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (response.statusCode == 401) {
      await _clearToken();
      return [];
    }
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<Map<String, dynamic>?> getMemberProfile(
    int userId,
    int groupId,
  ) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse("$baseUrl/profile/$userId/group/$groupId"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (response.statusCode == 401) {
      await _clearToken();
      return null;
    }
    if (response.statusCode == 200) return jsonDecode(response.body);
    return null;
  }

  static Future<void> logout() async {
    final token = await getToken();
    try {
      await http.post(
        Uri.parse("$baseUrl/auth/logout"),
        headers: {"Authorization": "Bearer $token"},
      );
    } catch (_) {}
    await _clearToken();
  }

  // ── School Sections/Subjects ───────────────────────
  static Future<List<dynamic>> getSections(int groupId) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse("$baseUrl/groups/$groupId/sections"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<Map<String, dynamic>?> createSection(
    int groupId,
    String name,
    String? subject,
  ) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse("$baseUrl/groups/$groupId/sections"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"name": name, "subject": subject}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    return null;
  }

  // ── Tasks/Deadlines ────────────────────────────
  static Future<List<dynamic>> getTasks(int groupId) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse("$baseUrl/groups/$groupId/tasks"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<Map<String, dynamic>?> createTask(
    int groupId,
    String title,
    String? description,
    String? dueDate,
    String? sectionId,
  ) async {
    final token = await getToken();
    final body = <String, dynamic>{"title": title, "group_id": groupId};
    if (description != null) body["description"] = description;
    if (dueDate != null) body["due_date"] = dueDate;
    if (sectionId != null) body["section_id"] = sectionId;

    final response = await http.post(
      Uri.parse("$baseUrl/groups/$groupId/tasks"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    return null;
  }

  static Future<bool> completeTask(int taskId) async {
    final token = await getToken();
    final response = await http.patch(
      Uri.parse("$baseUrl/tasks/$taskId/complete"),
      headers: {"Authorization": "Bearer $token"},
    );
    return response.statusCode == 200;
  }

  // ── Files/Materials ─────────────────────────
  static Future<List<dynamic>> getFiles(int groupId) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse("$baseUrl/groups/$groupId/files"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<Map<String, dynamic>?> uploadFile(
    int groupId,
    String name,
    String base64Data,
    String mimeType,
  ) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse("$baseUrl/groups/$groupId/files"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "name": name,
        "data": base64Data,
        "mime_type": mimeType,
        "group_id": groupId,
      }),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    return null;
  }

  static Future<bool> deleteFile(int fileId) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse("$baseUrl/files/$fileId"),
      headers: {"Authorization": "Bearer $token"},
    );
    return response.statusCode == 200;
  }

  // ─────────────────────────────────────────────────────────

  static Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
    log("Token cleared — session expired");
  }
}
