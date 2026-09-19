import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ignore: constant_identifier_names
const BASE_URL = 'https://makazs.xyz';
// ignore: constant_identifier_names
const OFFICIAL_ADMIN_ID = 10000000;

class AdminUser {
  final int id;
  final String customId;
  final String displayName;
  final int points;
  final String status;
  final String role;
  final bool officialBadge;
  final int mutedUntil;
  AdminUser({required this.id, required this.customId, required this.displayName, required this.points, required this.status, required this.role, required this.officialBadge, this.mutedUntil = 0});

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
        id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
        customId: j['custom_id'] as String? ?? '',
        displayName: j['display_name'] as String? ?? '',
        points: (j['points'] as num?)?.toInt() ?? 0,
        status: j['status'] as String? ?? 'active',
        role: j['role'] as String? ?? 'user',
        officialBadge: j['official_badge'] == true || j['official_badge'] == 1,
        mutedUntil: (j['muted_until'] as num?)?.toInt() ?? 0,
      );

  bool get isOfficial => id == OFFICIAL_ADMIN_ID;
  bool get isAdmin => isOfficial || role == 'admin';
  String get statusLabel => status == 'banned' ? '已封禁' : (status == 'muted' ? '禁言中' : '正常');
}

class AdminReport {
  final int id;
  final String targetType;
  final int targetId;
  final String reason;
  final String? description;
  final Map<String, dynamic>? target;
  final Map<String, dynamic>? reporter;
  final Map<String, dynamic>? snapshot;
  final Map<String, dynamic>? offender;
  AdminReport({required this.id, required this.targetType, required this.targetId, required this.reason, this.description, this.target, this.reporter, this.snapshot, this.offender});

  factory AdminReport.fromJson(Map<String, dynamic> j) => AdminReport(
        id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
        targetType: j['target_type'] as String? ?? '',
        targetId: (j['target_id'] as num?)?.toInt() ?? 0,
        reason: j['reason'] as String? ?? '',
        description: j['description'] as String?,
        target: j['target'] as Map<String, dynamic>?,
        reporter: j['reporter'] as Map<String, dynamic>?,
        snapshot: j['snapshot'] as Map<String, dynamic>?,
        offender: j['offender'] as Map<String, dynamic>?,
      );

  bool get isMessageReport =>
      targetType == 'dm_message' || targetType == 'message' || targetType == 'chat_message' || targetType == 'group_message';

  String get targetTypeLabel => switch (targetType) {
        'post' => '动态',
        'comment' => '评论',
        'user' => '用户',
        'group' => '群组',
        'dm_message' || 'message' => '私信消息',
        'chat_message' => '聊天群消息',
        'group_message' => '小社区消息',
        _ => targetType,
      };
}

class AdminApi {
  static String? _token;
  static AdminUser? me;
  static final http.Client _client = http.Client();

  static bool get isOfficial => me?.isOfficial ?? false;
  static bool get isAdmin => me?.isAdmin ?? false;

  static Future<void> saveToken(String t) async {
    _token = t;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_token', t);
  }

  static Future<void> restoreToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('admin_token');
  }

  static Future<void> clearToken() async {
    _token = null;
    me = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_token');
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'User-Agent': 'MakaAdmin/1.0 (Android; Flutter)',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static String _errMsg(http.Response res) {
    try {
      final m = json.decode(utf8.decode(res.bodyBytes));
      return m['error'] as String? ?? '请求失败 (${res.statusCode})';
    } catch (_) {
      return '请求失败 (${res.statusCode})';
    }
  }

  static Future<(Map<String, dynamic>?, String?)> _send(String method, String path, [Map<String, dynamic>? body]) async {
    try {
      final uri = Uri.parse('$BASE_URL$path');
      late http.Response res;
      if (method == 'POST') {
        res = await _client.post(uri, headers: _headers, body: json.encode(body ?? {})).timeout(const Duration(seconds: 15));
      } else if (method == 'PUT') {
        res = await _client.put(uri, headers: _headers, body: json.encode(body ?? {})).timeout(const Duration(seconds: 15));
      } else if (method == 'DELETE') {
        res = await _client.delete(uri, headers: _headers).timeout(const Duration(seconds: 15));
      } else {
        res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
      }
      if (res.statusCode == 200) {
        final m = json.decode(utf8.decode(res.bodyBytes));
        return m is Map<String, dynamic> ? (m, null) : (<String, dynamic>{}, null);
      }
      return (null, _errMsg(res));
    } catch (e) {
      return (null, '网络错误: $e');
    }
  }

  /// 登录；成功返回 null，失败返回错误信息。仅管理员可用。
  static Future<String?> login(String account, String password) async {
    final (data, err) = await _send('POST', '/api/auth/login', {'account': account, 'password': password});
    if (err != null) return err;
    final u = AdminUser.fromJson((data!['user'] as Map<String, dynamic>));
    if (!u.isAdmin) {
      if (u.status == 'banned') return '账号已被封禁';
      return '该账号不是管理员，无权使用管理面板';
    }
    await saveToken(data['token'] as String);
    me = u;
    return null;
  }

  /// 启动时用保存的 token 恢复登录态；返回错误信息或 null
  static Future<String?> restore() async {
    await restoreToken();
    if (_token == null) return '未登录';
    final (data, err) = await _send('GET', '/api/auth/me');
    if (err != null) {
      await clearToken();
      return err;
    }
    final u = AdminUser.fromJson((data!['user'] as Map<String, dynamic>));
    if (!u.isAdmin) {
      await clearToken();
      return '该账号已无管理权限';
    }
    me = u;
    return null;
  }

  // ---------- 概览 ----------
  static Future<Map<String, dynamic>?> reportStats() async => (await _send('GET', '/api/admin/report-stats')).$1;
  static Future<Map<String, dynamic>?> stats() async => (await _send('GET', '/api/admin/stats')).$1;

  // ---------- 举报 ----------
  static Future<(List<AdminReport>, String?)> getReports({String status = 'pending'}) async {
    final (data, err) = await _send('GET', '/api/admin/reports?status=$status');
    if (err != null) return (<AdminReport>[], err);
    final items = ((data!['items'] as List?) ?? []).map((e) => AdminReport.fromJson(e as Map<String, dynamic>)).toList();
    return (items, null);
  }

  static Future<String?> handleReport(int id, String action, String note) async {
    final (_, err) = await _send('POST', '/api/admin/reports/$id/handle', {'action': action, 'note': note});
    return err;
  }

  // ---------- 用户管理（仅官方） ----------
  static Future<(List<AdminUser>, String?)> searchUsers(String q) async {
    final (data, err) = await _send('GET', '/api/admin/users?q=${Uri.encodeQueryComponent(q)}');
    if (err != null) return (<AdminUser>[], err);
    final items = ((data!['items'] as List?) ?? []).map((e) => AdminUser.fromJson(e as Map<String, dynamic>)).toList();
    return (items, null);
  }

  static Future<String?> setUserStatus(int id, String status, {int? days}) async {
    final (_, err) = await _send('POST', '/api/admin/users/$id/status', {'status': status, 'days': days});
    return err;
  }

  static Future<String?> setPoints(int id, {required String mode, required int amount, String reason = ''}) async {
    final (_, err) = await _send('POST', '/api/admin/users/$id/points', {'mode': mode, 'amount': amount, 'reason': reason});
    return err;
  }

  static Future<String?> setRole(int id, String role) async {
    final (_, err) = await _send('POST', '/api/admin/users/$id/role', {'role': role});
    return err;
  }

  static Future<String?> setOfficialBadge(int id, bool grant) async {
    final (_, err) = await _send('POST', '/api/admin/users/$id/official-badge', {'grant': grant});
    return err;
  }

  // ---------- 内容审核（仅官方） ----------
  static Future<(List<Map<String, dynamic>>, String?)> getPending() async {
    final (data, err) = await _send('GET', '/api/admin/moderation/pending');
    if (err != null) return (<Map<String, dynamic>>[], err);
    final posts = ((data!['posts'] as List?) ?? []).cast<Map<String, dynamic>>();
    final comments = ((data['comments'] as List?) ?? []).cast<Map<String, dynamic>>();
    final List<Map<String, dynamic>> items = [
      ...posts.map((p) => {'kind': 'post', ...p}),
      ...comments.map((c) => {'kind': 'comment', ...c}),
    ];
    return (items, null);
  }

  static Future<String?> moderate(String kind, int id, bool approve) async {
    final (_, err) = await _send('POST', kind == 'post' ? '/api/admin/moderation/posts/$id' : '/api/admin/moderation/comments/$id', {'approve': approve});
    return err;
  }

  // ---------- 公告（仅官方） ----------
  static Future<String?> createAnnouncement(String title, String content, bool pinned) async {
    final (_, err) = await _send('POST', '/api/admin/announcements', {'title': title, 'content': content, 'pinned': pinned});
    return err;
  }

  static Future<String?> deleteAnnouncement(int id) async {
    final (_, err) = await _send('DELETE', '/api/admin/announcements/$id');
    return err;
  }

  static Future<(List<Map<String, dynamic>>, String?)> getAnnouncements() async {
    final (data, err) = await _send('GET', '/api/announcements');
    if (err != null) return (<Map<String, dynamic>>[], err);
    final List<Map<String, dynamic>> items = ((data!['items'] as List?) ?? []).cast<Map<String, dynamic>>().toList();
    return (items, null);
  }

  static void logout() => clearToken();
}
