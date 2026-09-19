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

/// 动态媒体 URL 是否为视频（与服务端 EXT 映射一致：mp4/mov/m4v/webm）
bool isVideoPath(String? url) {
  if (url == null || url.isEmpty) return false;
  final u = url.toLowerCase().split('?').first;
  return u.endsWith('.mp4') || u.endsWith('.mov') ||
      u.endsWith('.m4v') || u.endsWith('.webm');
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

/// @ 候选用户（发布器）
class MentionCandidate {
  final int id;
  final String displayName;
  final String customId;
  final String avatar;
  MentionCandidate({required this.id, required this.displayName, this.customId = '', this.avatar = ''});
  factory MentionCandidate.fromJson(Map<String, dynamic> j) => MentionCandidate(
        id: j['id'] as int? ?? 0,
        displayName: j['display_name'] as String? ?? '',
        customId: j['custom_id'] as String? ?? '',
        avatar: j['avatar'] as String? ?? '',
      );
  User toUser() => User(id: id, displayName: displayName, customId: customId, avatar: avatar);
}

class Conversation {
  final int peerId;
  final String peerName;
  final String lastMessage;
  final String lastType;
  final bool lastFromMe;
  final int lastTime;
  final int unread;
  Conversation({
    required this.peerId,
    required this.peerName,
    required this.lastMessage,
    this.lastType = 'text',
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
      lastType: last['type'] as String? ?? 'text',
      lastFromMe: _asBool(last['from_me']),
      lastTime: last['created_at'] as int? ?? 0,
      unread: j['unread'] as int? ?? 0,
    );
  }

  /// 会话列表预览文本（富媒体显示占位）
  String get lastPreview {
    switch (lastType) {
      case 'image': return '[图片]';
      case 'voice': return '[语音]';
      case 'video': return '[视频]';
      default: return lastMessage;
    }
  }
}

class Message {
  final int id;
  final int fromId;
  final int toId;
  String content;
  final String type; // text/image/voice/video
  final int duration;
  final int createdAt;
  int readAt;
  Message({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.content,
    required this.createdAt,
    this.type = 'text',
    this.duration = 0,
    this.readAt = 0,
  });
  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'] as int? ?? 0,
        fromId: j['from_id'] as int? ?? 0,
        toId: j['to_id'] as int? ?? 0,
        content: j['content'] as String? ?? '',
        type: j['type'] as String? ?? 'text',
        duration: j['duration'] as int? ?? 0,
        createdAt: j['created_at'] as int? ?? 0,
        readAt: j['read_at'] as int? ?? 0,
      );
}

class AppNotification {
  final int id;
  final String type;
  final Map<String, dynamic> payload;
  final Map<String, dynamic>? target;
  final int createdAt;
  final bool read;
  AppNotification({required this.id, required this.type, required this.payload, this.target, required this.createdAt, required this.read});
  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as int? ?? 0,
        type: j['type'] as String? ?? '',
        payload: (j['payload'] as Map?)?.cast<String, dynamic>() ?? {},
        target: (j['target'] as Map?)?.cast<String, dynamic>(),
        createdAt: j['created_at'] as int? ?? 0,
        read: j['read_at'] != null,
      );
  String get title {
    switch (type) {
      case 'like': return '收到点赞';
      case 'comment': return '收到评论';
      case 'mention': return '有人提到了你';
      case 'security': return '安全提醒';
      case 'dm': return '新私信';
      case 'friend_request': return '好友申请';
      case 'friend_accept': return '好友申请已通过';
      case 'dm_request': return '消息申请';
      case 'dm_accept': return '私信申请已通过';
      case 'chat_invite': return '群聊邀请';
      case 'chat_kicked': return '被移出群聊';
      default: return payload['title'] as String? ?? '社区通知';
    }
  }

  String get body => (payload['content'] as String?) ?? (payload['excerpt'] as String?) ?? '';
}

/// 未读聚合：系统通知 / 私信 / 聊天群 / 消息申请
class UnreadCount {
  final int notify;
  final int dm;
  final int chat;
  final int dmRequest;
  final int total;
  UnreadCount({this.notify = 0, this.dm = 0, this.chat = 0, this.dmRequest = 0, this.total = 0});
  factory UnreadCount.fromJson(Map<String, dynamic> j) => UnreadCount(
        notify: j['notify'] as int? ?? 0,
        dm: j['dm'] as int? ?? 0,
        chat: j['chat'] as int? ?? 0,
        dmRequest: j['dm_request'] as int? ?? 0,
        total: j['total'] as int? ?? 0,
      );
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
  final List<PostMention> mentions; // 正文中 @ 的用户
  final List<String> tags; // 正文标签名
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
    this.mentions = const [],
    this.tags = const [],
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
        mentions: (j['mentions'] as List?)
                ?.map((e) => PostMention.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        tags: (j['tags'] as List?)?.map((e) => e as String).toList() ?? const [],
      );
}

/// 动态正文中 @ 的用户（精简信息，来自 decorate）
class PostMention {
  final int id;
  final String displayName;
  final String avatar;
  PostMention({required this.id, required this.displayName, this.avatar = ''});
  factory PostMention.fromJson(Map<String, dynamic> j) => PostMention(
        id: j['id'] as int? ?? 0,
        displayName: j['display_name'] as String? ?? '',
        avatar: j['avatar'] as String? ?? '',
      );
}

/// 标签详情头信息
class TagInfo {
  final int id;
  final String name;
  final int postCount;
  TagInfo({required this.id, required this.name, this.postCount = 0});
  factory TagInfo.fromJson(Map<String, dynamic> j) => TagInfo(
        id: j['id'] as int? ?? 0,
        name: j['name'] as String? ?? '',
        postCount: j['post_count'] as int? ?? 0,
      );
}

/// 好友申请（decorateReq：对端用户在 user 字段）
class FriendRequest {
  final int id;
  final String status; // pending / accepted / rejected / cancelled
  final String message;
  final int createdAt;
  final User user;
  FriendRequest({
    required this.id,
    this.status = 'pending',
    this.message = '',
    this.createdAt = 0,
    required this.user,
  });
  factory FriendRequest.fromJson(Map<String, dynamic> j) => FriendRequest(
        id: j['id'] as int? ?? 0,
        status: j['status'] as String? ?? 'pending',
        message: j['message'] as String? ?? '',
        createdAt: j['created_at'] as int? ?? 0,
        user: User.fromJson((j['user'] as Map?)?.cast<String, dynamic>() ?? const {}),
      );
}

/// 隐私设置四开关
class PrivacySettings {
  final bool allowStrangerMention; // 允许陌生人@我
  final bool allowStrangerFriend; // 允许陌生人加好友
  final bool dmConfirm; // 陌生人私信需我确认
  final bool friendAutoAccept; // 加好友无需我同意
  PrivacySettings({
    this.allowStrangerMention = true,
    this.allowStrangerFriend = true,
    this.dmConfirm = false,
    this.friendAutoAccept = false,
  });
  factory PrivacySettings.fromJson(Map<String, dynamic> j) => PrivacySettings(
        allowStrangerMention: _asBool(j['allow_stranger_mention']),
        allowStrangerFriend: _asBool(j['allow_stranger_friend']),
        dmConfirm: _asBool(j['dm_confirm']),
        friendAutoAccept: _asBool(j['friend_auto_accept']),
      );
}

/// 私信申请（陌生人首条消息进箱）
class DmRequest {
  final User user; // 对方（incoming=from / outgoing=to）
  final String lastMessage;
  final int createdAt;
  final int updatedAt;
  DmRequest({
    required this.user,
    this.lastMessage = '',
    this.createdAt = 0,
    this.updatedAt = 0,
  });
  factory DmRequest.fromJson(Map<String, dynamic> j) {
    final u = (j['from'] ?? j['to']) as Map?;
    return DmRequest(
      user: User.fromJson((u as Map<String, dynamic>?)?.cast<String, dynamic>() ?? const {}),
      lastMessage: j['last_message'] as String? ?? '',
      createdAt: j['created_at'] as int? ?? 0,
      updatedAt: j['updated_at'] as int? ?? 0,
    );
  }
}

// ---------- 聊天群组（纯聊天群） ----------

class ChatGroup {
  final int id;
  String name;
  String avatar;
  final int ownerId;
  bool joinByNumber;
  final int lastMsgAt;
  final String lastPreview;
  final int unread;
  final int memberCount;
  ChatGroup({
    required this.id,
    required this.name,
    this.avatar = '',
    this.ownerId = 0,
    this.joinByNumber = false,
    this.lastMsgAt = 0,
    this.lastPreview = '',
    this.unread = 0,
    this.memberCount = 0,
  });
  factory ChatGroup.fromJson(Map<String, dynamic> j) => ChatGroup(
        id: j['id'] as int? ?? 0,
        name: j['name'] as String? ?? '',
        avatar: j['avatar'] as String? ?? '',
        ownerId: j['owner_id'] as int? ?? 0,
        joinByNumber: j['join_by_number'] == true,
        lastMsgAt: j['last_msg_at'] as int? ?? 0,
        lastPreview: j['last_preview'] as String? ?? '',
        unread: j['unread'] as int? ?? 0,
        memberCount: j['member_count'] as int? ?? 0,
      );
}

class ChatGroupMember {
  final User user;
  final String role; // owner / member
  final int joinedAt;
  ChatGroupMember({required this.user, this.role = 'member', this.joinedAt = 0});
  bool get isOwner => role == 'owner';
}

class ChatGroupDetail {
  final ChatGroup group;
  final String myRole; // owner / member
  final List<ChatGroupMember> members;
  ChatGroupDetail({required this.group, this.myRole = 'member', required this.members});
  bool get iAmOwner => myRole == 'owner';
  factory ChatGroupDetail.fromJson(Map<String, dynamic> data) {
    final g = data['group'] as Map<String, dynamic>? ?? const {};
    return ChatGroupDetail(
      group: ChatGroup.fromJson({
        ...g,
        'member_count': ((data['members'] as List?)?.length ?? g['member_count'] ?? 0),
      }),
      myRole: data['my_role'] as String? ?? 'member',
      members: ((data['members'] as List?) ?? const [])
          .map((e) {
            final m = e as Map<String, dynamic>;
            return ChatGroupMember(
              user: User.fromJson(m),
              role: m['role'] as String? ?? 'member',
              joinedAt: m['joined_at'] as int? ?? 0,
            );
          })
          .toList(),
    );
  }
}

class ChatMessage {
  final int id;
  final int groupId;
  final int fromId;
  final String type; // text / image / voice / video
  final String content;
  final int duration; // 语音秒数
  final int createdAt;
  final User? from;
  ChatMessage({
    required this.id,
    this.groupId = 0,
    this.fromId = 0,
    this.type = 'text',
    this.content = '',
    this.duration = 0,
    this.createdAt = 0,
    this.from,
  });
  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as int? ?? 0,
        groupId: j['group_id'] as int? ?? 0,
        fromId: j['from_id'] as int? ?? j['from']?['id'] as int? ?? 0,
        type: j['type'] as String? ?? 'text',
        content: j['content'] as String? ?? '',
        duration: j['duration'] as int? ?? 0,
        createdAt: j['created_at'] as int? ?? 0,
        from: j['from'] == null ? null : User.fromJson(j['from'] as Map<String, dynamic>),
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
  final String type;
  final int duration;
  final int createdAt;
  final User? author;
  GroupMessage({
    required this.id,
    required this.fromId,
    required this.content,
    required this.createdAt,
    this.type = 'text',
    this.duration = 0,
    this.author,
  });
  factory GroupMessage.fromJson(Map<String, dynamic> j) => GroupMessage(
        id: j['id'] as int? ?? 0,
        fromId: j['from_id'] as int? ?? j['author']?['id'] as int? ?? 0,
        content: j['content'] as String? ?? '',
        type: j['type'] as String? ?? 'text',
        duration: j['duration'] as int? ?? 0,
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

  static Future<String?> sendMessage(int toId, String content,
      {String type = 'text', int duration = 0}) async {
    final (data, err) = await _send('POST', '/api/dm', {
      'to_id': toId, 'content': content,
      if (type != 'text') 'type': type,
      if (duration > 0) 'duration': duration,
    });
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

  /// 一次拉取全部未读聚合（notify/dm/chat/dm_request/total）
  static Future<UnreadCount> getUnreadCount() async {
    final data = await _get('/api/unread-count');
    if (data != null) return UnreadCount.fromJson(data);
    return UnreadCount();
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

  /// 标签详情 + 该标签下动态流（sort: new / hot）
  static Future<(TagInfo?, List<Post>, bool)> getTagDetail(String name,
      {String sort = 'new', int before = 0}) async {
    var path = '/api/tags/${Uri.encodeComponent(name)}?sort=$sort&limit=10';
    if (sort == 'new' && before > 0) path += '&before=$before';
    final data = await _get(path);
    if (data?['tag'] == null) return (null, <Post>[], false);
    final tag = TagInfo.fromJson(data!['tag'] as Map<String, dynamic>);
    final items = (data['items'] as List?)?.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList() ?? <Post>[];
    return (tag, items, data['has_more'] == true);
  }

  /// 热门标签
  static Future<List<TagInfo>> getHotTags({int limit = 20}) async {
    final data = await _get('/api/tags/hot?limit=$limit');
    return (data?['items'] as List?)?.map((e) => TagInfo.fromJson(e as Map<String, dynamic>)).toList() ?? [];
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
    List<int> mentions = const [],
    List<String> tags = const [],
  }) async {
    final (data, err) = await _send('POST', '/api/posts', {
      'content': content,
      'images': images,
      'visibility': visibility,
      if (groupId != null) 'group_id': groupId,
      'mentions': mentions,
      'tags': tags,
    });
    if (err != null) return (null, err);
    return (data?['status'] as String? ?? 'normal', null);
  }

  /// @ 候选用户（服务端：最近聊天置顶，其后模糊匹配；已过滤禁止陌生人@的用户）
  static Future<List<MentionCandidate>> getMentionSuggestions(String q) async {
    final path = q.isEmpty
        ? '/api/mention/suggestions'
        : '/api/mention/suggestions?q=${Uri.encodeQueryComponent(q)}';
    final data = await _get(path);
    final items = (data?['items'] as List?) ?? const [];
    return items.map((j) => MentionCandidate.fromJson(j as Map<String, dynamic>)).toList();
  }

  // ===================== 好友系统 =====================

  /// 发起好友申请。返回 (关系状态 friends/pending, 申请 id?, 错误?)
  static Future<(String, int?, String?)> sendFriendRequest(int uid, {String message = ''}) async {
    final (data, err) = await _send('POST', '/api/friends/request/$uid', {'message': message});
    if (err != null) return ('none', null, err);
    return (data?['status'] as String? ?? 'pending', data?['id'] as int?, null);
  }

  static Future<String?> _friendAction(String path, {String method = 'POST'}) async {
    final (_, err) = await _send(method, path, const {});
    return err;
  }

  static Future<String?> acceptFriend(int requestId) => _friendAction('/api/friends/accept/$requestId');
  static Future<String?> rejectFriend(int requestId) => _friendAction('/api/friends/reject/$requestId');
  static Future<String?> cancelFriend(int requestId) => _friendAction('/api/friends/cancel/$requestId');
  static Future<String?> removeFriend(int uid) => _friendAction('/api/friends/$uid', method: 'DELETE');

  static Future<List<User>> getFriends() async {
    final data = await _get('/api/friends');
    return (data?['items'] as List?)?.map((e) => User.fromJson(e as Map<String, dynamic>)).toList() ?? [];
  }

  static Future<List<FriendRequest>> _friendRequests(String path) async {
    final data = await _get(path);
    return (data?['items'] as List?)
            ?.map((e) => FriendRequest.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
  }

  static Future<List<FriendRequest>> getIncomingFriends() => _friendRequests('/api/friends/requests/incoming');
  static Future<List<FriendRequest>> getOutgoingFriends() => _friendRequests('/api/friends/requests/outgoing');

  /// 与某用户的关系：none / pending_out / pending_in / friends
  static Future<String> friendStatus(int uid) async {
    final data = await _get('/api/friends/status/$uid');
    return data?['status'] as String? ?? 'none';
  }

  // ===================== 隐私设置 =====================

  /// 读取我的隐私设置
  static Future<PrivacySettings> getPrivacy() async {
    final data = await _get('/api/me/privacy');
    return PrivacySettings.fromJson((data?['privacy'] as Map?)?.cast<String, dynamic>() ?? const {});
  }

  /// 更新部分隐私开关，返回更新后的完整设置
  static Future<(PrivacySettings?, String?)> updatePrivacy(Map<String, bool> patch) async {
    final (data, err) = await _send('PUT', '/api/me/privacy', patch);
    if (err != null) return (null, err);
    return (PrivacySettings.fromJson((data?['privacy'] as Map?)?.cast<String, dynamic>() ?? const {}), null);
  }

  // ===================== 私信申请箱 =====================

  static Future<List<DmRequest>> _dmRequests(String path) async {
    final data = await _get(path);
    return (data?['items'] as List?)?.map((e) => DmRequest.fromJson(e as Map<String, dynamic>)).toList() ?? [];
  }

  /// 收到的陌生人私信申请
  static Future<List<DmRequest>> getDmRequests() => _dmRequests('/api/dm/requests');

  /// 我发出、等待对方确认的申请
  static Future<List<DmRequest>> getDmRequestsOutgoing() => _dmRequests('/api/dm/requests/outgoing');

  /// 同意：申请语作为首条私信落库，对方收到 dm_accept
  static Future<String?> acceptDmRequest(int fromUid) async {
    final (_, err) = await _send('POST', '/api/dm/requests/$fromUid/accept', const {});
    return err;
  }

  static Future<String?> ignoreDmRequest(int fromUid) async {
    final (_, err) = await _send('POST', '/api/dm/requests/$fromUid/ignore', const {});
    return err;
  }

  // ===================== 聊天群组（纯聊天群） =====================

  /// 创建聊天群
  static Future<(int? id, String? err)> createChatGroup(String name, List<int> memberIds) async {
    final (data, err) = await _send('POST', '/api/chats', {'name': name, 'member_ids': memberIds});
    if (err != null) return (null, err);
    return ((data?['id'] as num?)?.toInt(), null);
  }

  /// 我加入的聊天群（含最后消息预览与未读数）
  static Future<List<ChatGroup>> getChatGroups() async {
    final data = await _get('/api/chats');
    return (data?['items'] as List?)?.map((e) => ChatGroup.fromJson(e as Map<String, dynamic>)).toList() ?? [];
  }

  /// 群资料 + 成员
  static Future<ChatGroupDetail?> getChatGroup(int id) async {
    final data = await _get('/api/chats/$id');
    return data == null ? null : ChatGroupDetail.fromJson(data);
  }

  /// 修改群资料（群主）：可改 name / join_by_number
  static Future<String?> updateChatGroup(int id, Map<String, dynamic> patch) async {
    final (_, err) = await _send('PUT', '/api/chats/$id', patch);
    return err;
  }

  /// 邀请成员（直接入群）
  static Future<(List<int> joined, String? err)> inviteToChat(int id, List<int> userIds) async {
    final (data, err) = await _send('POST', '/api/chats/$id/invite', {'user_ids': userIds});
    if (err != null) return (<int>[], err);
    final joined = ((data?['joined'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
    return (joined, null);
  }

  /// 凭群号加入（需群开放 join_by_number）
  static Future<String?> joinChatByNumber(int groupId) async {
    final (_, err) = await _send('POST', '/api/chats/join-by-number', {'group_id': groupId});
    return err;
  }

  /// 踢人（群主）
  static Future<String?> kickFromChat(int id, int uid) async {
    final (_, err) = await _send('POST', '/api/chats/$id/kick/$uid', const {});
    return err;
  }

  /// 退群；群主退群且仅剩自己时群解散
  static Future<(bool dissolved, String? err)> leaveChat(int id) async {
    final (data, err) = await _send('POST', '/api/chats/$id/leave', const {});
    if (err != null) return (false, err);
    return (data?['dissolved'] == true, null);
  }

  /// 群消息历史（拉取即更新已读位）
  static Future<List<ChatMessage>> getChatMessages(int id, {int before = 0}) async {
    final data = await _get('/api/chats/$id/messages${before > 0 ? '?before=$before' : ''}');
    return (data?['items'] as List?)?.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList() ?? [];
  }

  /// 发送群消息
  static Future<(int? id, String? err)> sendChatMessage(int id, {
    required String type, required String content, int duration = 0,
  }) async {
    final (data, err) = await _send('POST', '/api/chats/$id/messages',
        {'type': type, 'content': content, if (duration > 0) 'duration': duration});
    if (err != null) return (null, err);
    return ((data?['id'] as num?)?.toInt(), null);
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

  /// 聊天图片（≤10MB），返回 (url, err)
  static Future<(String?, String?)> uploadChatImageFile(String filePath, {String? mime}) async {
    try {
      final ct = _imageMime(filePath, mime);
      final ext = ct.subtype == 'jpeg' ? 'jpg' : ct.subtype;
      final req = http.MultipartRequest('POST', Uri.parse('$BASE_URL/api/upload/chat-image'))
        ..headers['Authorization'] = 'Bearer $_token'
        ..files.add(await http.MultipartFile.fromPath('file', filePath,
            contentType: ct, filename: 'chat_${DateTime.now().millisecondsSinceEpoch}.$ext'));
      final res = await _client.send(req).timeout(const Duration(seconds: 90));
      final body = await res.stream.bytesToString();
      if (res.statusCode == 200) {
        return (((json.decode(body) as Map<String, dynamic>)['url'] as String?), null);
      }
      return (null, _errFromBody(res.statusCode, body));
    } catch (e) {
      return (null, '网络错误: $e');
    }
  }

  /// 聊天媒体（图片/视频/语音，≤50MB），返回 (url, err)
  static Future<(String?, String?)> uploadChatMediaFile(String filePath, {String? mime}) async {
    try {
      final ct = mime != null
          ? MediaType.parse(mime)
          : (filePath.toLowerCase().endsWith('.m4a')
              ? MediaType('audio', 'mp4')
              : (filePath.toLowerCase().endsWith('.aac')
                  ? MediaType('audio', 'aac')
                  : _imageMime(filePath, mime)));
      final ext = ct.type == 'image'
          ? (ct.subtype == 'jpeg' ? 'jpg' : ct.subtype)
          : (ct.type == 'video' ? ct.subtype : ct.subtype);
      final req = http.MultipartRequest('POST', Uri.parse('$BASE_URL/api/upload/media'))
        ..headers['Authorization'] = 'Bearer $_token'
        ..files.add(await http.MultipartFile.fromPath('file', filePath,
            contentType: ct, filename: 'media_${DateTime.now().millisecondsSinceEpoch}.$ext'));
      final res = await _client.send(req).timeout(const Duration(seconds: 120));
      final body = await res.stream.bytesToString();
      if (res.statusCode == 200) {
        return (((json.decode(body) as Map<String, dynamic>)['url'] as String?), null);
      }
      return (null, _errFromBody(res.statusCode, body));
    } catch (e) {
      return (null, '网络错误: $e');
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

  // ---------- 小社区 ----------

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

  /// 返回 (小社区, 成员列表, 待审数, 错误)
  static Future<(Group?, List<User>, int, String?)> getGroupDetail(int gid) async {
    final data = await _get('/api/groups/$gid');
    if (data != null) {
      final group = data['group'] == null ? null : Group.fromJson(data['group'] as Map<String, dynamic>);
      final members = (data['members'] as List?)?.map((e) => User.fromJson(e as Map<String, dynamic>)).toList() ?? [];
      return (group, members, data['pending_count'] as int? ?? 0, null);
    }
    return (null, <User>[], 0, '小社区不存在或已解散');
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

  static Future<String?> sendGroupChat(int gid, String content,
      {String type = 'text', int duration = 0}) async {
    final (_, err) = await _send('POST', '/api/groups/$gid/chat', {
      'content': content,
      if (type != 'text') 'type': type,
      if (duration > 0) 'duration': duration,
    });
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
  static final _chatMsgController = StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get dmStream => _dmController.stream;
  static Stream<Map<String, dynamic>> get sentStream => _sentController.stream;
  static Stream<Map<String, dynamic>> get readStream => _readController.stream;
  static Stream<Map<String, dynamic>> get notifyStream => _notifyController.stream;
  static Stream<Map<String, dynamic>> get groupMsgStream => _groupMsgController.stream;
  static Stream<Map<String, dynamic>> get chatMsgStream => _chatMsgController.stream;

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
    // 群聊消息（小社区）
    _socket!.on('group:msg', (data) => _groupMsgController.add(_asMap(data)));
    // 聊天群组消息
    _socket!.on('chat:msg', (data) => _chatMsgController.add(_asMap(data)));
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
