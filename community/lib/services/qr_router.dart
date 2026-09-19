import 'package:flutter/material.dart';
import '../screens/post_detail_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/group_detail_screen.dart';
import '../screens/tag_screen.dart';

/// 扫码识别结果。仅本站链接可解析。
class MakaQrTarget {
  final String kind; // post / user / group / tag
  final int? id;
  final String? tag;
  const MakaQrTarget.post(int this.id) : kind = 'post', tag = null;
  const MakaQrTarget.user(int this.id) : kind = 'user', tag = null;
  const MakaQrTarget.group(int this.id) : kind = 'group', tag = null;
  const MakaQrTarget.tag(String this.tag) : kind = 'tag', id = null;
}

/// 仅识别 makazs.xyz / www.makazs.xyz 的 http(s) 链接；其余一律返回 null。
MakaQrTarget? parseMakaQr(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return null;
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  final host = uri.host.toLowerCase();
  if (host != 'makazs.xyz' && host != 'www.makazs.xyz') return null;

  final seg = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (seg.isEmpty) return null;
  final head = seg[0];
  final tail = seg.length > 1 ? seg[1] : '';

  int? idOf(String s) => int.tryParse(s);

  switch (head) {
    case 'p':
      final id = idOf(tail);
      return id != null ? MakaQrTarget.post(id) : null;
    case 'u':
      final id = idOf(tail);
      return id != null ? MakaQrTarget.user(id) : null;
    case 'g':
      final id = idOf(tail);
      return id != null ? MakaQrTarget.group(id) : null;
    case 'tag':
    case 'tags':
      final name = tail.trim();
      return name.isNotEmpty ? MakaQrTarget.tag(name) : null;
  }
  return null;
}

/// 处理扫码/相册识别到的原始内容：非玛卡链接提示并拒绝。
Future<void> handleScanned(BuildContext context, String raw) async {
  final target = parseMakaQr(raw);
  if (target == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('非玛卡链接，已忽略')),
    );
    return;
  }
  Widget page;
  switch (target.kind) {
    case 'post':
      page = PostDetailScreen(postId: target.id!);
      break;
    case 'user':
      page = UserProfileScreen(userId: target.id!);
      break;
    case 'group':
      page = GroupDetailScreen(groupId: target.id!);
      break;
    case 'tag':
      page = TagScreen(name: target.tag!);
      break;
    default:
      return;
  }
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}
