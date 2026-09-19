import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';

/// 版本清单中某一端（社区/管理面板）的信息
class RemoteVersion {
  final String version;
  final int build;
  final String url;
  final String iosUrl;
  final bool major;
  final String minSupported;
  final String notes;
  RemoteVersion({
    required this.version,
    required this.build,
    required this.url,
    required this.iosUrl,
    required this.major,
    required this.minSupported,
    required this.notes,
  });
  factory RemoteVersion.fromJson(Map<String, dynamic> j) => RemoteVersion(
        version: j['version'] as String? ?? '',
        build: j['build'] as int? ?? 0,
        url: j['url'] as String? ?? '',
        iosUrl: j['ios_url'] as String? ?? '',
        major: j['major'] == true,
        minSupported: j['min_supported'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
      );
  String get downloadUrl => absUrl(url);
}

class VersionService {
  /// 当前 APP 版本（与 pubspec.yaml version 保持一致）
  static const currentVersion = '0.26.9';

  /// 语义版本比较：a>b 返回 1，相等 0，a<b -1
  static int compare(String a, String b) {
    List<int> parts(String s) => s.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
    final pa = parts(a), pb = parts(b);
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x > y ? 1 : -1;
    }
    return 0;
  }

  static Future<RemoteVersion?> fetch({String segment = 'community'}) async {
    try {
      final res = await http
          .get(Uri.parse('$BASE_URL/downloads/version.json'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final root = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final seg = root[segment] as Map<String, dynamic>?;
      if (seg == null) return null;
      return RemoteVersion.fromJson(seg);
    } catch (_) {
      return null; // 断网/超时静默
    }
  }

  /// 是否需要更新
  static bool hasUpdate(String current, RemoteVersion v) => compare(current, v.version) < 0;

  /// 是否强制（major 标记或当前版本低于最低支持）
  static bool isForced(String current, RemoteVersion v) =>
      v.major || (v.minSupported.isNotEmpty && compare(current, v.minSupported) < 0);

  static Future<bool> isSkipped(String segment, RemoteVersion v) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('skip_version_$segment') == v.version;
  }

  static Future<void> markSkipped(String segment, RemoteVersion v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('skip_version_$segment', v.version);
  }
}
