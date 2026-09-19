import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../api.dart';
import '../widgets/avatar.dart';

/// 动态分享海报：离屏 RepaintBoundary 绘制 → PNG → 系统分享。
/// 二维码（右下）与文案均指向 https://makazs.xyz/p/{id}/
Future<void> sharePost(BuildContext context, Post p) async {
  final link = 'https://makazs.xyz/p/${p.id}/';
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 14),
          Text('正在生成海报…'),
        ]),
      ),
    )),
  ));

  try {
    // 首图预加载（仅取图片；视频不出现在海报中）
    String? imgPath;
    for (final u in p.images) {
      if (!isVideoPath(u)) { imgPath = u; break; }
    }
    ImageProvider? imgProvider;
    if (imgPath != null) {
      imgProvider = NetworkImage(absUrl(imgPath));
      final stream = imgProvider.resolve(const ImageConfiguration());
      final ready = Completer<void>();
      var failed = false;
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (_, __) { if (!ready.isCompleted) ready.complete(); },
        onError: (e, st) { failed = true; if (!ready.isCompleted) ready.complete(); },
      );
      stream.addListener(listener);
      await ready.future.timeout(const Duration(seconds: 8), onTimeout: () {});
      stream.removeListener(listener);
      // 加载失败时降级为无图海报
      if (failed) imgProvider = null;
    }

    final poster = SharePoster(post: p, link: link, image: imgProvider);
    final size = Size(360, posterHeightFor(p, imgProvider != null));
    final image = await _captureOffscreen(context, size, poster);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('海报编码失败');

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/poster_${p.id}_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes.buffer.asUint8List());

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    await Share.shareXFiles([XFile(file.path)], text: 'From the CbM  $link');
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    // 海报失败则降级为纯链接分享
    try {
      await Share.share('From the CbM  $link');
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('分享失败：$e')));
    }
  }
}

/// 海报高度随正文行数自适应（正文区约 20 个 14px 字/行，行高 23）。
double posterHeightFor(Post p, bool hasImage) {
  const base = 268; // 品牌头+分隔线+作者+底部 From/二维码+间距
  final text = p.content.isEmpty ? '（仅图片/视频动态）' : p.content;
  final estLines = (text.runes.length / 20).ceil();
  final maxLines = hasImage ? 7 : 14;
  final lines = estLines.clamp(1, maxLines);
  final h = base + lines * 23 + (hasImage ? 150 : 0);
  return h.clamp(320, 560).toDouble();
}

/// 将固定尺寸的组件放到屏幕外 Overlay 中正常绘制，再用 RepaintBoundary 截图。
Future<ui.Image> _captureOffscreen(BuildContext context, Size size, Widget child) {
  final key = GlobalKey();
  final completer = Completer<ui.Image>();
  late OverlayEntry entry;
  var frames = 0;
  entry = OverlayEntry(builder: (_) => Positioned(
        left: -10000,
        top: 0,
        child: RepaintBoundary(key: key, child: SizedBox.fromSize(size: size, child: child)),
      ));
  Overlay.of(context).insert(entry);

  void tick(Duration _) {
    frames += 1;
    if (frames < 2) {
      WidgetsBinding.instance.addPostFrameCallback(tick);
      return;
    }
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    boundary.toImage(pixelRatio: 3).then((img) {
      entry.remove();
      completer.complete(img);
    }).catchError((Object e) {
      entry.remove();
      completer.completeError(e);
    });
  }

  WidgetsBinding.instance.addPostFrameCallback(tick);
  return completer.future;
}

class SharePoster extends StatelessWidget {
  final Post post;
  final String link;
  final ImageProvider? image;
  const SharePoster({required this.post, required this.link, required this.image});

  String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final author = post.author;
    return Material(
      color: Colors.white,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE9E9F2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.graphic_eq, color: Theme.of(context).colorScheme.primary, size: 26),
                const SizedBox(width: 8),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('玛卡之声', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF22223B))),
                    Text('Community of Maka', style: TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 0.5)),
                  ],
                ),
              ],
            ),
            const Divider(height: 22, color: Color(0xFFEEEEF4)),
            Row(
              children: [
                if (author != null) MakaAvatar(user: author, size: 38) else const SizedBox(width: 38, height: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(author?.displayName ?? '玛卡用户',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF22223B))),
                      Text(_date(post.createdAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      post.content.isEmpty ? '（仅图片/视频动态）' : post.content,
                      maxLines: image != null ? 7 : 14,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, height: 1.55, color: Color(0xFF333344)),
                    ),
                  ),
                  if (image != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image(image: image!, width: double.infinity, height: 140, fit: BoxFit.cover),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('From the CbM',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF22223B))),
                      const SizedBox(height: 4),
                      Text(link, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                      const SizedBox(height: 2),
                      const Text('扫码查看这条动态', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE3E3EC)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: QrImageView(
                    data: link,
                    size: 92,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.all(6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
