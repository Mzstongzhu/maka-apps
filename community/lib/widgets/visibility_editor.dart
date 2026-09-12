import 'package:flutter/material.dart';
import '../api.dart';

/// 动态可见范围编辑（与网页端 VisibilityEditor 对齐）
Future<bool> showVisibilityEditor(BuildContext context, Post post) async {
  var vis = post.visibility;
  final list = (vis == 'whitelist' ? post.visibleTo : vis == 'blacklist' ? post.hiddenFrom : <int>[]).toList();
  final input = TextEditingController();
  List<User> results = [];
  var saved = false;

  const options = [
    ('public', '公开', '所有人可见'),
    ('self', '仅自己可见', '只有自己能看到这条动态'),
    ('whitelist', '仅谁可见', '仅指定用户可见'),
    ('blacklist', '谁不可见', '指定用户不可见，其他人可见'),
  ];

  Future<void> doSearch(StateSetter setSheet) async {
    final q = input.text.trim();
    if (q.isEmpty) return;
    final users = await Api.searchUsers(q);
    setSheet(() => results = users);
  }

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('谁可以看到这条动态？', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...options.map((o) => InkWell(
                  onTap: () => setSheet(() => vis = o.$1),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: vis == o.$1 ? Theme.of(ctx).colorScheme.primary : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                      color: vis == o.$1 ? Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.06) : null,
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(o.$2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                        Text(o.$3, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                )),
            if (vis == 'whitelist' || vis == 'blacklist') ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: input,
                      decoration: const InputDecoration(
                        hintText: '识别码 / 自定义ID / 昵称',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => doSearch(setSheet),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(onPressed: () => doSearch(setSheet), child: const Text('搜索')),
                ],
              ),
              if (results.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: results.length,
                    itemBuilder: (_, i) {
                      final u = results[i];
                      return ListTile(
                        dense: true,
                        title: Text(u.label, style: const TextStyle(fontSize: 14)),
                        subtitle: Text('#${u.id} ${u.customId != null ? '@${u.customId}' : ''}', style: const TextStyle(fontSize: 11)),
                        onTap: () => setSheet(() {
                          if (!list.contains(u.id)) list.add(u.id);
                          input.clear();
                          results = [];
                        }),
                      );
                    },
                  ),
                ),
              if (list.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: list
                        .map((id) => InputChip(
                              label: Text('#$id', style: const TextStyle(fontSize: 12)),
                              onDeleted: () => setSheet(() => list.remove(id)),
                            ))
                        .toList(),
                  ),
                ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消'))),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      final err = await Api.updatePost(post.id, {
                        'visibility': vis,
                        'visible_to': vis == 'whitelist' ? list : [],
                        'hidden_from': vis == 'blacklist' ? list : [],
                      });
                      if (!ctx.mounted) return;
                      if (err != null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(err)));
                      } else {
                        saved = true;
                        Navigator.pop(ctx);
                      }
                    },
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return saved;
}
