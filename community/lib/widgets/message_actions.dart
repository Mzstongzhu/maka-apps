import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'report_sheet.dart';

/// 聊天气泡长按菜单：复制文字 / 举报消息（dm_message / chat_message / group_message）
Future<void> showMessageActions(
  BuildContext context, {
  required bool canReport,
  required bool canCopy,
  required String reportType,
  required int messageId,
  String? text,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canCopy)
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('复制文字'),
              onTap: () => Navigator.pop(ctx, 'copy'),
            ),
          if (canReport)
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.redAccent),
              title: const Text('举报消息', style: TextStyle(color: Colors.redAccent)),
              onTap: () => Navigator.pop(ctx, 'report'),
            ),
          if (!canReport && !canCopy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Text('暂无可执行操作', style: TextStyle(color: Colors.grey)),
            ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  if (action == 'copy' && text != null) {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制')));
    }
  } else if (action == 'report') {
    await showReportSheet(context, reportType, messageId);
  }
}
