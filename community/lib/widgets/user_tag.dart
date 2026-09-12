import 'package:flutter/material.dart';
import '../api.dart';
import 'avatar.dart';

/// 昵称 + 官方徽章 + 头衔，副标题可选（时间等）
class UserTag extends StatelessWidget {
  final User? user;
  final String? sub;
  final VoidCallback? onTap;
  const UserTag({super.key, this.user, this.sub, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  user?.label ?? '未知用户',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              if (user?.officialBadge == true) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                  child: Text('官方', style: TextStyle(fontSize: 10, color: cs.primary)),
                ),
              ],
              if (user?.title != null && (user!.title as String).isNotEmpty) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(4)),
                  child: Text(user!.title!, style: const TextStyle(fontSize: 10, color: Color(0xFF92400E))),
                ),
              ],
            ],
          ),
          if (sub != null && sub!.isNotEmpty)
            Text(sub!, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }
}

/// 用户行：头像 + UserTag
class UserRow extends StatelessWidget {
  final User user;
  final String? sub;
  final VoidCallback? onTap;
  final List<Widget> trailing;
  const UserRow({super.key, required this.user, this.sub, this.onTap, this.trailing = const []});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            MakaAvatar(user: user, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: UserTag(user: user, sub: sub, onTap: onTap),
            ),
            ...trailing,
          ],
        ),
      ),
    );
  }
}
