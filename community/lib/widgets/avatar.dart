import 'package:flutter/material.dart';
import '../api.dart';

/// 头像：有图显示网络图，无图用 id 调色板 + 首字
class MakaAvatar extends StatelessWidget {
  final User? user;
  final GroupBrief? group;
  final double size;
  const MakaAvatar({super.key, this.user, this.group, this.size = 40});

  static const _palette = [
    Color(0xFF60A5FA), Color(0xFFF472B6), Color(0xFF34D399), Color(0xFFFBBF24),
    Color(0xFFA78BFA), Color(0xFFF87171), Color(0xFF2DD4BF),
  ];

  @override
  Widget build(BuildContext context) {
    final id = user?.id ?? group?.id ?? 0;
    final name = group?.name ?? user?.label ?? '?';
    final color = _palette[id.abs() % _palette.length];
    final url = absUrl(user?.avatar ?? group?.avatar);
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: color,
      backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
      child: url.isEmpty ? Text(initial, style: TextStyle(color: Colors.white, fontSize: size * 0.42)) : null,
    );
  }
}
