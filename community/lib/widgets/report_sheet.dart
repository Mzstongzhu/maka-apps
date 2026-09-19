import 'package:flutter/material.dart';
import '../api.dart';

/// 举报弹窗（动态 / 用户 / 评论 / 消息：dm_message、chat_message、group_message）
Future<void> showReportSheet(BuildContext context, String targetType, int targetId) async {
  const reasons = ['违法违规', '色情低俗', '人身攻击', '广告骚扰', '侵权', '其他'];
  String reason = reasons[0];
  final detail = TextEditingController();
  var done = false;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: done
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 40),
                  const SizedBox(height: 10),
                  const Text('举报已提交', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('感谢你维护社区环境，管理员会尽快核查处理。',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('好的')),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('举报', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('如发现违规内容或行为，请向我们举报，管理员会尽快处理。',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  const SizedBox(height: 14),
                  const Text('举报理由', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: reasons
                        .map((r) => ChoiceChip(
                              label: Text(r),
                              selected: reason == r,
                              onSelected: (_) => setSheet(() => reason = r),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: detail,
                    maxLength: 500,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '补充说明（选填）',
                      hintText: '可补充具体情况，方便管理员核查',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            final err = await Api.report(targetType, targetId, reason, detail.text.trim());
                            if (!ctx.mounted) return;
                            if (err != null) {
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(err)));
                            } else {
                              setSheet(() => done = true);
                            }
                          },
                          child: const Text('提交举报'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    ),
  );
}
