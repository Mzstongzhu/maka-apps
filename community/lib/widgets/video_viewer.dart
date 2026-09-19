import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../api.dart';

/// 视频缩略（首帧 + 播放角标）。cover=true 时按容器裁切铺满。
class VideoThumb extends StatefulWidget {
  final String url;
  final bool cover;
  final bool showDuration;
  final VoidCallback? onTap;
  const VideoThumb({
    super.key,
    required this.url,
    this.cover = false,
    this.showDuration = true,
    this.onTap,
  });
  @override
  State<VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<VideoThumb> {
  VideoPlayerController? _ctrl;
  bool _ready = false;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(absUrl(widget.url)));
    _ctrl = c;
    try {
      await c.initialize();
      if (!mounted) { await c.dispose(); return; }
      setState(() {
        _ready = true;
        _seconds = c.value.duration.inSeconds;
      });
    } catch (_) {
      if (mounted) setState(() {}); // 失败仍显示可点击占位
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black87),
        if (_ready && _ctrl != null)
          widget.cover
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _ctrl!.value.size.width,
                    height: _ctrl!.value.size.height,
                    child: VideoPlayer(_ctrl!),
                  ),
                )
              : Center(
                  child: AspectRatio(
                    aspectRatio: _ctrl!.value.aspectRatio,
                    child: VideoPlayer(_ctrl!),
                  ),
                ),
        const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 42)),
        if (widget.showDuration && _seconds > 0)
          Positioned(
            left: 6, bottom: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('${_seconds}s',
                  style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ),
      ],
    );
    return GestureDetector(
      onTap: widget.onTap ?? () => openVideoFullScreen(context, widget.url),
      child: view,
    );
  }
}

/// 全屏播放（自动播放，可暂停；横屏视频自动横屏）
Future<void> openVideoFullScreen(BuildContext context, String url) async {
  await Navigator.push(context, MaterialPageRoute(
    builder: (_) => _VideoFullScreen(url: url),
    fullscreenDialog: true,
  ));
}

class _VideoFullScreen extends StatefulWidget {
  final String url;
  const _VideoFullScreen({required this.url});
  @override
  State<_VideoFullScreen> createState() => _VideoFullScreenState();
}

class _VideoFullScreenState extends State<_VideoFullScreen> {
  VideoPlayerController? _ctrl;
  bool _ready = false;
  bool _err = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(absUrl(widget.url)));
    _ctrl = c;
    try {
      await c.initialize();
      if (!mounted) { await c.dispose(); return; }
      if (c.value.aspectRatio > 1) {
        await SystemChrome.setPreferredOrientations(
            [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      }
      setState(() => _ready = true);
      await c.play();
    } catch (_) {
      if (mounted) setState(() => _err = true);
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    SystemChrome.setPreferredOrientations([]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _err
                  ? const Center(child: Text('视频播放失败，请稍后再试',
                      style: TextStyle(color: Colors.white70)))
                  : !_ready
                      ? const Center(child: CircularProgressIndicator())
                      : GestureDetector(
                          onTap: () => setState(() {
                            final c = _ctrl!;
                            c.value.isPlaying ? c.pause() : c.play();
                          }),
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: _ctrl!.value.aspectRatio,
                              child: VideoPlayer(_ctrl!),
                            ),
                          ),
                        ),
            ),
            Positioned(
              top: 8, left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            if (_ready)
              Positioned(
                bottom: 16, right: 16,
                child: FloatingActionButton(
                  onPressed: () => setState(() {
                    final c = _ctrl!;
                    c.value.isPlaying ? c.pause() : c.play();
                  }),
                  child: Icon(_ctrl!.value.isPlaying ? Icons.pause : Icons.play_arrow),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
