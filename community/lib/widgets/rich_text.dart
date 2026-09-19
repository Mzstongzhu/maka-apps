import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../api.dart';
import '../screens/user_profile_screen.dart';
import '../screens/tag_screen.dart';

/// 正文富文本：@用户（按 uid 跳主页）与 #标签#（跳标签详情）。
/// @ 以发布时 mentions 为准（改名后仍正确）；#标签# 已知标签优先，未知 #word# 兜底也可点。
class RichContent extends StatelessWidget {
  final String text;
  final List<PostMention> mentions;
  final List<String> tags;
  final TextStyle? style;
  const RichContent({
    super.key,
    required this.text,
    this.mentions = const [],
    this.tags = const [],
    this.style,
  });

  static final _wordCls = r'[一-龥A-Za-z0-9_]';

  @override
  Widget build(BuildContext context) {
    final base = style ?? const TextStyle(fontSize: 15, height: 1.45, color: Color(0xFF1F2937));
    final atStyle = base.copyWith(color: const Color(0xFF0D9488), fontWeight: FontWeight.w600);
    final tagStyle = base.copyWith(color: const Color(0xFF4F46E5), fontWeight: FontWeight.w600);

    // 名字更长的优先，避免 "@张三" 抢先匹配 "@张三丰"
    final mentionNames = mentions.map((m) => m.displayName).where((s) => s.isNotEmpty).toSet().toList()
      ..sort((a, b) => b.length - a.length);
    final tagNames = tags.where((s) => s.isNotEmpty).toSet().toList()..sort((a, b) => b.length - a.length);

    String esc(String s) => RegExp.escape(s);
    final mAlt = mentionNames.map(esc).join('|');
    final tAlt = tagNames.map(esc).join('|');

    final parts = <String>[
      if (tAlt.isNotEmpty) r'#(?<ctag>(?:' + tAlt + r'))#',
      r'#(?<gtag>' + _wordCls + r'{1,20})#',
      if (mAlt.isNotEmpty) r'@(?<mname>(?:' + mAlt + r'))(?!' + _wordCls + r')',
      if (tAlt.isNotEmpty) r'#(?<btag>(?:' + tAlt + r'))(?!' + _wordCls + r'#)',
    ];
    final hasCtag = tAlt.isNotEmpty, hasMname = mAlt.isNotEmpty, hasBtag = tAlt.isNotEmpty;
    final re = RegExp(parts.join('|'));

    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start), style: base));
      // namedGroup 对不存在的组名会抛 ArgumentError，必须先判断分支是否存在
      final mname = hasMname ? m.namedGroup('mname') : null;
      final tag = (hasCtag ? m.namedGroup('ctag') : null) ?? m.namedGroup('gtag') ?? (hasBtag ? m.namedGroup('btag') : null);
      if (mname != null) {
        final user = mentions.firstWhere(
          (u) => u.displayName == mname,
          orElse: () => PostMention(id: 0, displayName: mname),
        );
        spans.add(TextSpan(
          text: '@$mname',
          style: atStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              if (user.id != 0) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: user.id)));
              }
            },
        ));
      } else if (tag != null) {
        spans.add(TextSpan(
          text: m.group(0),
          style: tagStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => TagScreen(name: tag)));
            },
        ));
      } else {
        spans.add(TextSpan(text: m.group(0), style: base));
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last), style: base));

    return Text.rich(TextSpan(children: spans), style: base);
  }
}
