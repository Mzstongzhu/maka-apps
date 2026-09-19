import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/version_service.dart';

/// 冷启动/手动检查更新。force 为大版本（不可关闭），否则可"以后再说/跳过此版本"
class UpdateDialog {
  static Future<void> openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> show(
    BuildContext context, {
    required RemoteVersion info,
    required bool force,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          icon: Icon(force ? Icons.system_security_update_warning : Icons.system_update,
              color: force ? Colors.red : null, size: 36),
          title: Text(force ? '必须更新到 ${info.version}' : '发现新版本 ${info.version}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (info.notes.isNotEmpty) Text(info.notes, style: const TextStyle(height: 1.5)),
              if (force) ...[
                const SizedBox(height: 12),
                const Text('当前版本已不再受支持，请立即更新后继续使用。', style: TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
          actions: [
            if (!force)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('以后再说'),
              ),
            if (!force)
              TextButton(
                onPressed: () async {
                  await VersionService.markSkipped(info);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: const Text('跳过此版本'),
              ),
            FilledButton(
              onPressed: () => openUrl(info.downloadUrl),
              child: const Text('立即更新'),
            ),
          ],
        ),
      ),
    );
  }

  /// 拉清单并按策略弹窗；无更新/断网/已跳过则静默。返回是否有更新（供"关于"页提示）
  static Future<bool> check(
    BuildContext context, {
    bool manual = false,
  }) async {
    const current = VersionService.currentVersion;
    final v = await VersionService.fetch();
    if (v == null || !VersionService.hasUpdate(current, v)) {
      if (manual && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('当前已是最新版本')));
      }
      return false;
    }
    final force = VersionService.isForced(current, v);
    if (!force && !manual && await VersionService.isSkipped(v)) return false;
    if (context.mounted) await show(context, info: v, force: force);
    return true;
  }
}
