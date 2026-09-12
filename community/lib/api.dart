import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;
import 'package:intl/intl.dart';

const BASE_URL = 'https://makazs.xyz';

String absUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  return url.startsWith('http') ? url : '$BASE_URL$url';
}

// ===================== 数据模型 =====================

class User {
  final int id;
  final String? displayName;
  final String? customId;
  final String? avatar;
  final String? bio;
  final String? email;
  final int points;
  final String? title;
  final bool titleUnlocked;
  final bool officialBadge;
  final String? role;
  final String? groupRole; // 群成员角色（群详情接口）
  final int createdAt;
  final int customIdChangedAt;
  User({
    required this.id,
    this.displayName,
    this.customId,
    this.avatar,
    this.bio,
    this.email,
    this.points = 0,
    this.title,
    this.titleUnlocked = false,
    this.officialBadge = false,
    this.role,
    this.groupRole,
    this.createdAt = 0,
    this.customIdChangedAt = 0,
  });
  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] as int? ?? 0,
        displayName: j['display_name'] as String?,
        customId: j['custom_id'] as String?,
        avatar: j['avatar'] as String?,
        bio: j['bio'] as String?,
        email: j['email'] as String?,
        points: j['points'] as int? ?? 0,
        title: j['title'] as String?,
        titleUnlocked: _asBool(j['title_unlocked']),
        officialBadge: _asBool(j['official_badge']),
        role: j['role'] as String?,
        groupRole: j['group_role'] as String?,
        createdAt: j['created_at'] as int? ?? 0,
        customIdChangedAt: j['custom_id_changed_at'] as int? ?? 0,
      );
  String get label => displayName ?? customId ?? '用户$id';
}

class Conversation {
  final int peerId;
  final String peerName;
  final String lastMessage;
  final bool lastFromMe;
  final int lastTime;
  final int unread;
  Conversation({
    required this.peerId,
    required this.peerName,
    required this.lastMessage,
    required this.lastFromMe,
    required this.lastTime,
    required this.unread,
  });
  factory Conversation.fromJson(Map<String, dynamic> j) {
    final peer = j['peer'] as Map<String, dynamic>? ?? {};
    final last = j['last'] as Map<String, dynamic>? ?? {};
    return Conversation(
      peerId: peer['id'] as int? ?? 0,
      peerName: peer['display_name'] as String? ?? peer['custom_id'] as String? ?? '用户${peer['id']}',
      lastMessage: last['content'] as String? ?? '',
      lastFromMe: _asBool(last['from_me']),
      lastTime: last['created_at'] as int? ?? 0,
      unread: j['unread'] as int? ?? 0,
    );
  }
}

class Message {
  final int id;
  final int fromId;
  final int toId;
  String content;
  final int createdAt;
  int readAt;
  Message({required this.id, required this.fromId, required this.toId, required this.content, required this.createdAt, this.readAt = 0});
  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'] as int? ?? 0,
        fromId: j['from_id'] as int? ?? 0,
        toId: j['to_id'] as int? ?? 0,
        content: j['content'] as String? ?? '',
        createdAt: j['created_at'] as int? ?? 0,
        readAt: j['read_at'] as int? ?? 0,
      );
}

class AppNotification {
  final int id;
  final String type;
  final Map<String, dynamic> payload;
  final int createdAt;
  final bool read;
  AppNotification({required this.id, required this.type, required this.payload, required this.createdAt, required this.read});
  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as int? ?? 0,
        type: j['type'] as String? ?? '',
        payload: j['payload'] as Map<String, dynamic>? ?? {},
        createdAt: j['created_at'] as int? ?? 0,
        read: j['read_at'] != null,
      );
  String get title {
    switch (type) {
      case 'like': return '收到点赞';
      case 'comment': return '收到评论';
      case 'security': return '安全提醒';
      case 'dm': return '新私信';
      default: return payload['title'] as String? ?? '社区通知';
    }
  }
  String get body => (payload['content'] as String?) ?? (payload['excerpt'] as String?) ?? '';
}

class GroupBrief {
  final int id;
  final String name;
  final String? avatar;
  GroupBrief({required this.id, required this.name, this.avatar});
  factory GroupBrief.fromJson(Map<String, dynamic> j) => GroupBrief(
        id: j['id'] as int? ?? 0,
        name: j['name'] as String? ?? '',
        avatar: j['avatar'] as String?,
      );
}

class Group {
  final int id;
  final String name;
  final String? description;
  final String? avatar;
  final int memberCount;
  final int createdAt;
  final bool joinApproval;
  final bool postsPublic;
  final String? myRole; // owner / admin / member / null(非成员)
  Group({
    required this.id,
    required this.name,
    this.description,
    this.avatar,
    this.memberCount = 0,
    this.createdAt = 0,
    this.joinApproval = false,
    this.postsPublic = false,
    this.myRole,
  });
  bool get isMember => myRole != null;
  bool get canManage => myRole == 'owner' || myRole == 'admin';
  factory Group.fromJson(Map<String, dynamic> j) => Group(
        id: j['id'] as int? ?? 0,
        name: j['name'] as String? ?? '',
        description: j['description'] as String?,
        avatar: j['avatar'] as String?,
        memberCount: j['member_count'] as int? ?? 0,
        createdAt: j['created_at'] as int? ?? 0,
        joinApproval: _asBool(j['join_approval']),
        postsPublic: _asBool(j['posts_public']),
        myRole: j['my_role'] as String?,
      );
}

class Post {
  final int id;
  User? author;
  GroupBrief? group;
  String content;
  List<String> images;
  int likeCount;
  int commentCount;
  bool liked;
  final int createdAt;
  final int updatedAt;
  final String status; // normal / pending / rejected
  final String visibility; // public / self / whitelist / blacklist
  List<int> visibleTo;
  List<int> hiddenFrom;
  Post({
    required this.id,
    this.author,
    this.group,
    required this.content,
    required this.images,
    this.likeCount = 0,
    this.commentCount = 0,
    this.liked = false,
    required this.createdAt,
    this.updatedAt = 0,
    this.status = 'normal',
    this.visibility = 'public',
    this.visibleTo = const [],
    this.hiddenFrom = const [],
  });
  factory Post.fromJson(Map<String, dynamic> j) => Post(
        id: j['id'] as int? ?? 0,
        author: j['author'] == null ? null : User.fromJson(j['author'] as Map<String, dynamic>),
        group: j['group'] == null ? null : GroupBrief.fromJson(j['group'] as Map<String, dynamic>),
        content: j['content'] as String? ?? '',
        images: (j['images'] as List?)?.map((e) => e as String).toList() ?? [],
        likeCount: j['like_count'] as int? ?? 0,
        commentCount: j['comment_count'] as int? ?? 0,
        liked: _asBool(j['liked']),
        createdAt: j['created_at'] as int? ?? 0,
        updatedAt: j['updated_at'] as int? ?? 0,
        status: j['status'] as String? ?? 'normal',
        visibility: j['visibility'] as String? ?? 'public',
        visibleTo: (j['visible_to'] as List?)?.map((e) => e as int).toList() ?? [],
        hiddenFrom: (j['hidden_from'] as List?)?.map((e) => e as int).toList() ?? [],
      );
}

class Comment {
  final int id;
  User? author;
  String content;
  final int createdAt;
  final String status;
  Comment({required this.id, this.author, required this.content, required this.createdAt, this.status = 'normal'});
  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id: j['id'] as int? ?? 0,
        author: j['author'] == null ? null : User.fromJson(j['author'] as Map<String, dynamic>),
        content: j['content'] as String? ?? '',
        createdAt: j['created_at'] as int? ?? 0,
        status: j['status'] as String? ?? 'normal',
      );
}

class GroupMessage {
  final int id;
  final int fromId;
  final String content;
  final int createdAt;
  final User? author;
  GroupMessage({required this.id, required this.fromId, required this.content, required this.createdAt, this.author});
  factory GroupMessage.fromJson(Map<String, dynamic> j) => GroupMessage(
        id: j['id'] as int? ?? 0,
        fromId: j['from_id'] as int? ?? j['author']?['id'] as int? ?? 0,
        content: j['content'] as String? ?? '',
        createdAt: j['created_at'] as int? ?? 0,
        author: j['author'] == null ? null : User.fromJson(j['author'] as Map<String, dynamic>),
      );
}

class Bottle {
  final int id;
  final String content;
  final String mood;
  final String status; // sea / picked / kept
  final User? sender;
  final int thrownAt;
  Bottle({required this.id, required this.content, required this.mood, this.status = 'sea', this.sender, this.thrownAt = 0});
  factory Bottle.fromJson(Map<String, dynamic> j) => Bottle(
        id: j['id'] as int? ?? 0,
        content: j['content'] as String? ?? '',
        mood: j['mood'] as String? ?? '普通',
        status: j['status'] as String? ?? 'sea',
        sender: j['sender'] == null ? null : User.fromJson(j['sender'] as Map<String, dynamic>),
        thrownAt: j['thrown_at'] as int? ?? 0,
      );
}

class BottleReply {
  final int id;
  final String content;
  final bool mine;
  final String role;
  final int createdAt;
  BottleReply({required this.id, required this.content, required this.mine, required this.role, required this.createdAt});
  factory BottleReply.fromJson(Map<String, dynamic> j) => BottleReply(
        id: j['id'] as int? ?? 0,
        content: j['content'] as String? ?? '',
        mine: _asBool(j['mine']),
        role: j['role'] as String? ?? '',
        createdAt: j['created_at'] as int? ?? 0,
      );
}

class Activity {
  final int id;
  final String title;
  final String content;
  final String phase; // upcoming / ongoing / ended
  final String startTime;
  final String endTime;
  final int signupCount;
  final bool signed;
  final List<User> signups;
  Activity({
    required this.id,
    required this.title,
    required this.content,
    required this.phase,
    required this.startTime,
    required this.endTime,
    this.signupCount = 0,
    this.signed = false,
    this.signups = const [],
  });
  factory Activity.fromJson(Map<String, dynamic> j) => Activity(
        id: j['id'] as int? ?? 0,
        title: j['title'] as String? ?? '',
        content: j['content'] as String? ?? '',
        phase: j['phase'] as String? ?? 'upcoming',
        startTime: j['start_time'] as String? ?? '',
        endTime: j['end_time'] as String? ?? '',
        signupCount: j['signup_count'] as int? ?? 0,
        signed: _asBool(j['signed']),
        signups: (j['signups'] as List?)?.map((e) => User.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      );
}

class Announcement {
  final int id;
  final String title;
  final String content;
  final bool pinned;
  final int createdAt;
  Announcement({required this.id, required this.title, required this.content, this.pinned = false, this.createdAt = 0});
  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        id: j['id'] as int? ?? 0,
        title: j['title'] as String? ?? '',
        content: j['content'] as String? ?? '',
        pinned: _asBool(j['pinned']),
        createdAt: j['created_at'] as int? ?? 0,
      );
}

class PointsHistory {
  final int id;
  final String reason;
  final int delta;
  final int createdAt;
  PointsHistory({required this.id, required this.reason, required this.delta, required this.createdAt});
  factory PointsHistory.fromJson(Map<String, dynamic> j) => PointsHistory(
        id: j['id'] as int? ?? 0,
        reason: j['reason'] as String? ?? '',
        delta: j['delta'] as int? ?? 0,
        createdAt: j['created_at'] as int? ?? 0,
      );
}

class SearchResult {
  final List<User> users;
  final List<Post> posts;
  final List<Group> groups;
  final List<Announcement> announcements;
  final List<Activity> activities;
  SearchResult({
    required this.users,
    required this.posts,
    required this.groups,
    required this.announcements,
    required this.activities,
  });
  int get total => users.length + posts.length + groups.length + announcements.length + activities.length;
  factory SearchResult.fromJson(Map<String, dynamic> j) => SearchResult(
        users: (j['users'] as List?)?.map((e) => User.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        posts: (j['posts'] as List?)?.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        groups: (j['groups'] as List?)?.map((e) => Group.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        announcements: (j['announcements'] as List?)?.map((e) => Announcement.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        activities: (j['activities'] as List?)?.map((e) => Activity.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      );
}

// ===================== 工具函数 =====================

/// 宽容布尔解析：兼容服务器返回的 true/false 与 SQLite 的 1/0
bool _asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  return false;
}

String formatTime(int ts) {
  if (ts == 0) return '';
  final ms = ts > 1e12 ? ts : ts * 1000;
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
  if (diff.inDays < 1) return '${diff.inHours} 小时前';
  if (diff.inDays < 7) return '${diff.inDays} 天前';
  return DateFormat('yyyy/MM/dd HH:mm').format(dt);
}

String formatDT(String s) {
  // 服务器 ISO 时间字符串 → 本地可读格式
  if (s.isEmpty) return '';
  try {
    final dt = DateTime.parse(s).toLocal();
    return DateFormat('yyyy/MM/dd HH:mm').format(dt);
  } catch (_) {
    return s;
  }
}

String activityTimeRange(String start, String end) {
  String one(String s) {
    if (s.isEmpty) return '';
    try {
      return DateFormat('MM/dd HH:mm').format(DateTime.parse(s).toLocal());
    } catch (_) {
      return s;
    }
  }
  return '${one(start)} ~ ${one(end)}';
}

// ===================== HTTP API =====================

class Api {
  static String? _token;
  static String? get token => _token;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
  }

  static Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  static Map<String, String> get _headers {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'User-Agent': 'MakaCommunity/1.0 (Android; Flutter)',
    };
    if (_token != null) h['Authorization'] = 'Bearer $_token';
    return h;
  }

  /// 全局复用的 HTTP 客户端：keep-alive 连接池，避免每次请求重复 TLS 握手（提速关键）
  static final http.Client _client = http.Client();

  /// 解析错误响应中的 error 字段
  static String _errMsg(http.Response res) {
    try {
      final m = json.decode(utf8.decode(res.bodyBytes));
      return m['error'] as String? ?? '请求失败 (${res.statusCode})';
    } catch (_) {
      return '请求失败 (${res.statusCode})';
    }
  }

  static Future<Map<String, dynamic>?> _get(String path) async {
    try {
      final res = await _client.get(Uri.parse('$BASE_URL$path'), headers: _headers).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) return json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {}
    return null;
  }

  static Future<(Map<String, dynamic>?, String?)> _send(String method, String path, [Map<String, dynamic>? body]) async {
    try {
      final uri = Uri.parse('$BASE_URL$path');
      late http.Response res;
      if (method == 'POST') {
        res = await _client.post(uri, headers: _headers, body: json.encode(body ?? {})).timeout(const Duration(seconds: 15));
      } else if (method == 'PUT') {
        res = await _client.put(uri, headers: _headers, body: json.encode(body ?? {})).timeout(const Duration(seconds: 15));
      } else {
        res = await _client.delete(uri, headers: _headers).timeout(const Duration(seconds: 15));
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

  // ---------- 认证 ----------

  /// 返回 (用户, 错误信息)，成功时错误为 null
  static Future<(User?, String?)> login(String account, String password) async {
    try {
      final res = await _client.post(
        Uri.parse('$BASE_URL/api/auth/login'),
        headers: _headers,
        body: json.encode({'account': account, 'password': password}),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        await saveToken(data['token']);
        return (User.fromJson(data['user']), null);
      }
      return (null, _errMsg(res));
    } catch (e) {
      return (null, '网络错误: $e');
    }
  }

  static Future<(User?, String?)> register(String displayName, String password, String email) async {
    final (data, err) = await _send('POST', '/api/auth/register', {
      'display_name': displayName,
      'password': password,
      'email': email,
      'agree': true,
    });
    if (err != null) return (null, err);
    await saveToken(data!['token'] as String);
    return (User.fromJson(data['user'] as Map<String, dynamic>), null);
  }

  static Future<User?> getMe() async {
    final data = await _get('/api/auth/me');
    if (data != null && data['user'] != null) return User.fromJson(data['user'] as Map<String, dynamic>);
    return null;
  }

  static Future<void> logout() async {
    await _send('POST', '/api/auth/logout');
    await clearToken();
  }

  static Future<String?> changePassword(String oldPwd, String newPwd) async {
    final (_, err) = await _send('POST', '/api/auth/change-password', {'old_password': oldPwd, 'new_password': newPwd});
    return err;
  }

  // ---------- 私信 ----------

  static Future<List<Conversation>> getConversations() async {
    final data = await _get('/api/dm/conversations');
    if (data != null) {
      final items = data['items'] as List? ?? [];
      return items.map((e) => Conversation.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  static Future<List<Message>> getMessages(int peerId) async {
    final data = await _get('/api/dm/with/$peerId');
    if (data != null) {
      final items = data['items'] as List? ?? [];
      return items.map((e) => Message.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  static Future<String?> sendMessage(int toId, String content) async {
    final (data, err) = await _send('POST', '/api/dm', {'to_id': toId, 'content': content});
    if (err != null) return err;
    return data?['id'] == null ? '发送失败' : null;
  }

  static Future<List<User>> searchUsers(String q) async {
    final data = await _get('/api/search/users?q=${Uri.encodeComponent(q)}');
    if (data != null) {
      final items = data['items'] as List? ?? [];
      return items.map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  // ---------- 通知 ----------

  static Future<List<AppNotification>> getNotifications() async {
    final data = await _get('/api/notifications');
    if (data != null) {
      final items = data['items'] as List? ?? [];
      return items.map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  static Future<void> markNotificationsRead() async {
    await _send('POST', '/api/notifications/read');
  }

  // ---------- 动态 ----------

  static Future<(List<Post>, bool)> getFeed({int? before, int? groupId, int? authorId}) async {
    var path = '/api/feed?limit=10';
    if (before != null) path += '&before=$before';
    if (groupId != null) path += '&group_id=$groupId';
    if (authorId != null) path += '&author_id=$authorId';
    final data = await _get(path);
    if (data != null) {
      final items = (data['items'] as List?)?.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList() ?? <Post>[];
      return (items, data['has_more'] == true);
    }
    return (<Post>[], false);
  }

  static Future<Post?> getPost(int id) async {
    final data = await _get('/api/posts/$id');
    if (data?['post'] != null) return Post.fromJson(data!['post'] as Map<String, dynamic>);
    return null;
  }

  static Future<List<Comment>> getComments(int postId) async {
    final data = await _get('/api/posts/$postId/comments');
    if (data != null) {
      return (data['items'] as List?)?.map((e) => Comment.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    }
    return [];
  }

  /// 发评论，返回 (审核状态 或 null, 错误)
  static Future<(String?, String?)> addComment(int postId, String content) async {
    final (data, err) = await _send('POST', '/api/posts/$postId/comments', {'content': content});
    if (err != null) return (null, err);
    return (data?['status'] as String? ?? 'normal', null);
  }

  static Future<String?> deleteComment(int id) async {
    final (_, err) = await _send('DELETE', '/api/comments/$id');
    return err;
  }

  static Future<bool> toggleLike(int postId) async {
    final (data, _) = await _send('POST', '/api/posts/$postId/like');
    return data?['liked'] == true;
  }

  /// 发动态，返回 (审核状态 或 null, 错误)
  static Future<(String?, String?)> createPost({
    required String content,
    List<String> images = const [],
    String visibility = 'public',
    int? groupId,
  }) async {
    final (data, err) = await _send('POST', '/api/posts', {
      'content': content,
      'images': images,
      'visibility': visibility,
      if (groupId != null) 'group_id': groupId,
    });
    if (err != null) return (null, err);
    return (data?['status'] as String? ?? 'normal', null);
  }

  static Future<String?> updatePost(int id, Map<String, dynamic> body) async {
    final (_, err) = await _send('PUT', '/api/posts/$id', body);
    return err;
  }

  static Future<String?> deletePost(int id) async {
    final (_, err) = await _send('DELETE', '/api/posts/$id');
    return err;
  }

  static Future<String?> report(String targetType, int targetId, String reason, String detail) async {
    final (_, err) = await _send('POST', '/api/reports', {
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
      'detail': detail,
    });
    return err;
  }

  // ---------- 上传 ----------

  /// 根据扩展名/XFile 上报的 MIME 推断图片类型，默认 jpeg（服务端白名单只收图片）
  static MediaType _imageMime(String filePath, String? hint) {
    if (hint != null && hint.startsWith('image/')) {
      final sub = hint.split('/').last.split(';').first.trim();
      if (['jpeg', 'png', 'gif', 'webp'].contains(sub)) return MediaType('image', sub);
    }
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.gif')) return MediaType('image', 'gif');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    return MediaType('image', 'jpeg');
  }

  static String _errFromBody(int status, String body) {
    try {
      final m = json.decode(body) as Map<String, dynamic>;
      return m['error'] as String? ?? '上传失败 ($status)';
    } catch (_) {
      return '上传失败 ($status)';
    }
  }

  /// 返回 (图片URL, 错误信息)，成功时错误为 null
  static Future<(String?, String?)> uploadImage(String filePath, {String? mime}) async {
    try {
      final ct = _imageMime(filePath, mime);
      final ext = ct.subtype == 'jpeg' ? 'jpg' : ct.subtype;
      final req = http.MultipartRequest('POST', Uri.parse('$BASE_URL/api/upload'))
        ..headers['Authorization'] = 'Bearer $_token'
        ..files.add(await http.MultipartFile.fromPath('file', filePath, contentType: ct, filename: 'upload_${DateTime.now().millisecondsSinceEpoch}.$ext'));
      final res = await _client.send(req).timeout(const Duration(seconds: 60));
      final body = await res.stream.bytesToString();
      if (res.statusCode == 200) {
        return (((json.decode(body) as Map<String, dynamic>)['url'] as String?), null);
      }
      return (null, _errFromBody(res.statusCode, body));
    } catch (e) {
      return (null, '网络错误: $e');
    }
  }

  /// 返回 (成功的URL列表, 错误信息)
  static Future<(List<String>, String?)> uploadImages(List<String> filePaths, {List<String?>? mimes}) async {
    try {
      final req = http.MultipartRequest('POST', Uri.parse('$BASE_URL/api/upload-multi'))
        ..headers['Authorization'] = 'Bearer $_token';
      for (var i = 0; i < filePaths.length; i++) {
        final p = filePaths[i];
        final ct = _imageMime(p, mimes?[i]);
        final ext = ct.subtype == 'jpeg' ? 'jpg' : ct.subtype;
        req.files.add(await http.MultipartFile.fromPath('files', p, contentType: ct, filename: 'upload_$i.$ext'));
      }
      final res = await _client.send(req).timeout(const Duration(seconds: 120));
      final body = await res.stream.bytesToString();
      if (res.statusCode == 200) {
        final urls = ((json.decode(body) as Map<String, dynamic>)['urls'] as List?) ?? [];
        return (urls.map((e) => e as String).toList(), null);
      }
      return (<String>[], _errFromBody(res.statusCode, body));
    } catch (e) {
      return (<String>[], '网络错误: $e');
    }
  }

  // ---------- 签到 / 积分 ----------

  static Future<bool> checkinStatus() async {
    final data = await _get('/api/checkin/status');
    return data?['checked_today'] == true;
  }

  /// 返回 (获得积分, 连签天数, 错误)
  static Future<(int, int, String?)> checkin() async {
    final (data, err) = await _send('POST', '/api/checkin');
    if (err != null) return (0, 0, err);
    return (data?['points'] as int? ?? 0, data?['streak'] as int? ?? 0, null);
  }

  static Future<List<PointsHistory>> getPointsHistory() async {
    final data = await _get('/api/points/history');
    if (data != null) {
      return (data['items'] as List?)?.map((e) => PointsHistory.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    }
    return [];
  }

  // ---------- 个人资料 ----------

  static Future<String?> updateProfile(Map<String, dynamic> body) async {
    final (_, err) = await _send('PUT', '/api/me/profile', body);
    return err;
  }

  static Future<String?> updateCustomId(String customId) async {
    final (_, err) = await _send('PUT', '/api/me/custom-id', {'custom_id': customId});
    return err;
  }

  static Future<String?> unlockTitle() async {
    final (_, err) = await _send('POST', '/api/me/title/unlock');
    return err;
  }

  static Future<String?> setTitle(String title) async {
    final (_, err) = await _send('PUT', '/api/me/title', {'title': title});
    return err;
  }

  // ---------- 用户主页 ----------

  static Future<(User?, List<Post>)> getUserProfile(int id) async {
    final data = await _get('/api/users/$id');
    if (data != null) {
      final user = data['user'] == null ? null : User.fromJson(data['user'] as Map<String, dynamic>);
      final posts = (data['posts'] as List?)?.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList() ?? [];
      return (user, posts);
    }
    return (null, <Post>[]);
  }

  // ---------- 全局搜索 ----------

  static Future<SearchResult?> searchAll(String q) async {
    final data = await _get('/api/search?q=${Uri.encodeComponent(q)}');
    if (data != null) return SearchResult.fromJson(data);
    return null;
  }

  // ---------- 公告 / 活动 ----------

  static Future<List<Announcement>> getAnnouncements() async {
    final data = await _get('/api/announcements');
    if (data != null) {
      return (data['items'] as List?)?.map((e) => Announcement.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    }
    return [];
  }

  static Future<List<Activity>> getActivities() async {
    final data = await _get('/api/activities');
    if (data != null) {
      return (data['items'] as List?)?.map((e) => Activity.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    }
    return [];
  }

  static Future<Activity?> getActivity(int id) async {
    final data = await _get('/api/activities/$id');
    if (data?['activity'] != null) return Activity.fromJson(data!['activity'] as Map<String, dynamic>);
    return null;
  }

  static Future<String?> signupActivity(int id) async {
    final (_, err) = await _send('POST', '/api/activities/$id/signup');
    return err;
  }

  // ---------- 群组 ----------

  static Future<List<Group>> getGroups(String? q) async {
    final data = await _get('/api/groups${q != null && q.isNotEmpty ? '?q=${Uri.encodeComponent(q)}' : ''}');
    if (data != null) {
      return (data['items'] as List?)?.map((e) => Group.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    }
    return [];
  }

  static Future<List<Group>> getMyGroups() async {
    final data = await _get('/api/groups/mine');
    if (data != null) {
      return (data['items'] as List?)?.map((e) => Group.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    }
    return [];
  }

  static Future<String?> createGroup(String name, String description, void Function(int id) onCreated) async {
    final (data, err) = await _send('POST', '/api/groups', {'name': name, 'description': description});
    if (err != null) return err;
    onCreated(data?['id'] as int? ?? 0);
    return null;
  }

  /// 返回 (群组, 成员列表, 待审数, 错误)
  static Future<(Group?, List<User>, int, String?)> getGroupDetail(int gid) async {
    final data = await _get('/api/groups/$gid');
    if (data != null) {
      final group = data['group'] == null ? null : Group.fromJson(data['group'] as Map<String, dynamic>);
      final members = (data['members'] as List?)?.map((e) => User.fromJson(e as Map<String, dynamic>)).toList() ?? [];
      return (group, members, data['pending_count'] as int? ?? 0, null);
    }
    return (null, <User>[], 0, '群组不存在或已解散');
  }

  /// 返回 (是否需审核, 错误)
  static Future<(bool, String?)> joinGroup(int gid) async {
    final (data, err) = await _send('POST', '/api/groups/$gid/join');
    if (err != null) return (false, err);
    return (data?['pending'] == true, null);
  }

  static Future<String?> leaveGroup(int gid) async {
    final (_, err) = await _send('POST', '/api/groups/$gid/leave');
    return err;
  }

  static Future<String?> saveGroupSettings(int gid, Map<String, dynamic> body) async {
    final (_, err) = await _send('PUT', '/api/groups/$gid/settings', body);
    return err;
  }

  static Future<String?> kickMember(int gid, int uid) async {
    final (_, err) = await _send('POST', '/api/groups/$gid/kick', {'user_id': uid});
    return err;
  }

  static Future<String?> setGroupAdmin(int gid, int uid, bool admin) async {
    final (_, err) = await _send('POST', '/api/groups/$gid/role', {'user_id': uid, 'admin': admin});
    return err;
  }

  static Future<String?> inviteMember(int gid, int uid) async {
    final (_, err) = await _send('POST', '/api/groups/$gid/invite', {'user_id': uid});
    return err;
  }

  static Future<List<User>> getGroupRequests(int gid) async {
    final data = await _get('/api/groups/$gid/requests');
    if (data != null) {
      return (data['items'] as List?)?.map((e) => User.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    }
    return [];
  }

  static Future<String?> handleGroupRequest(int gid, int uid, bool approve) async {
    final (_, err) = await _send('POST', '/api/groups/$gid/requests/$uid', {'approve': approve});
    return err;
  }

  static Future<List<GroupMessage>> getGroupChat(int gid) async {
    final data = await _get('/api/groups/$gid/chat');
    if (data != null) {
      return (data['items'] as List?)?.map((e) => GroupMessage.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    }
    return [];
  }

  static Future<String?> sendGroupChat(int gid, String content) async {
    final (_, err) = await _send('POST', '/api/groups/$gid/chat', {'content': content});
    return err;
  }

  // ---------- 漂流瓶 ----------

  static Future<String?> throwBottle(String content, String mood) async {
    final (_, err) = await _send('POST', '/api/bottles', {'content': content, 'mood': mood});
    return err;
  }

  static Future<Bottle?> pickBottle() async {
    final (data, _) = await _send('POST', '/api/bottles/pick');
    if (data?['bottle'] != null) return Bottle.fromJson(data!['bottle'] as Map<String, dynamic>);
    return null;
  }

  static Future<String?> keepBottle(int id, bool keep) async {
    final (_, err) = await _send('POST', '/api/bottles/$id/keep', {'keep': keep});
    return err;
  }

  static Future<(List<Bottle>, List<Bottle>)> getMyBottles() async {
    final data = await _get('/api/bottles/mine');
    if (data != null) {
      final thrown = (data['thrown'] as List?)?.map((e) => Bottle.fromJson(e as Map<String, dynamic>)).toList() ?? [];
      final picked = (data['picked'] as List?)?.map((e) => Bottle.fromJson(e as Map<String, dynamic>)).toList() ?? [];
      return (thrown, picked);
    }
    return (<Bottle>[], <Bottle>[]);
  }

  static Future<List<BottleReply>> getBottleReplies(int id) async {
    final data = await _get('/api/bottles/$id/replies');
    if (data != null) {
      return (data['items'] as List?)?.map((e) => BottleReply.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    }
    return [];
  }

  static Future<String?> replyBottle(int id, String content) async {
    final (_, err) = await _send('POST', '/api/bottles/$id/reply', {'content': content});
    return err;
  }
}

// ===================== Socket.IO 服务 =====================

class SocketService {
  static sio.Socket? _socket;
  static final _dmController = StreamController<Map<String, dynamic>>.broadcast();
  static final _sentController = StreamController<Map<String, dynamic>>.broadcast();
  static final _readController = StreamController<Map<String, dynamic>>.broadcast();
  static final _notifyController = StreamController<Map<String, dynamic>>.broadcast();
  static final _groupMsgController = StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get dmStream => _dmController.stream;
  static Stream<Map<String, dynamic>> get sentStream => _sentController.stream;
  static Stream<Map<String, dynamic>> get readStream => _readController.stream;
  static Stream<Map<String, dynamic>> get notifyStream => _notifyController.stream;
  static Stream<Map<String, dynamic>> get groupMsgStream => _groupMsgController.stream;

  static Map<String, dynamic> _asMap(dynamic data) =>
      data is String ? json.decode(data) as Map<String, dynamic> : (data as Map<String, dynamic>? ?? {});

  static void connect(String token) {
    if (_socket != null) return;
    // 服务器支持 cookie 中的 token，比 auth 字段更可靠
    _socket = sio.io(BASE_URL, sio.OptionBuilder()
        .setTransports(['websocket'])
        .setExtraHeaders({'cookie': 'token=$token'})
        .enableReconnection()
        .build());

    // 收到对方发来的新消息
    _socket!.on('dm:new', (data) => _dmController.add(_asMap(data)));
    // 自己发出的消息回执（含服务端真实 id）
    _socket!.on('dm:sent', (data) => _sentController.add(_asMap(data)));
    // 对方已读了我发的消息 {reader, ids}
    _socket!.on('dm:read', (data) => _readController.add(_asMap(data)));
    _socket!.on('notify:new', (data) => _notifyController.add(_asMap(data)));
    // 群聊消息
    _socket!.on('group:msg', (data) => _groupMsgController.add(_asMap(data)));
    _socket!.connect();
  }

  static void enterGroup(int gid) => _socket?.emit('group:enter', gid);
  static void leaveGroup(int gid) => _socket?.emit('group:leave', gid);

  static void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
