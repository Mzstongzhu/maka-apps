import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import '../admin_api.dart';

/// 举报消息的取证快照展示（文本/图片/语音/视频）
class MessageSnapshotView extends StatelessWidget {
  final Map<String, dynamic> snapshot;
  const MessageSnapshotView({super.key, required this.snapshot});

  static String mediaUrl(String c) {
    if (c.startsWith('http')) return c;
    return '$BASE_URL${c.startsWith('/') ? '' : '/'}$c';
  }

  static String _fmt(int ms) {
    if (ms <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int x) => x.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    final kind = s['kind'] as String? ?? '';
    final type = (s['type'] as String?) ?? 'text';
    final content = (s['content'] as String?) ?? '';
    final duration = (s['duration'] as num?)?.toInt() ?? 0;
    final from = s['from'] as Map<String, dynamic>?;
    final to = s['to'] as Map<String, dynamic>?;
    final group = s['group'] as Map<String, dynamic>?;

    final String scene;
    if (kind == 'dm_message') {
      scene = '私信：${from?['display_name'] ?? '?'} → ${to?['display_name'] ?? '?'}';
    } else {
      scene = '${kind == 'chat_message' ? '聊天群' : '小社区'}：${group?['name'] ?? '?'}';
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(child: Text('取证快照 · $scene', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '消息 #${s['message_id']}${duration > 0 ? ' · 时长 ${duration}s' : ''}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          Text(
            '发送于 ${_fmt((s['created_at'] as num?)?.toInt() ?? 0)} · 取证于 ${_fmt((s['captured_at'] as num?)?.toInt() ?? 0)}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const Divider(height: 14),
          if (type == 'image')
            _SnapshotImage(url: mediaUrl(content))
          else if (type == 'voice')
            _VoiceTile(url: mediaUrl(content), duration: duration)
          else if (type == 'video')
            _SnapshotVideo(url: mediaUrl(content))
          else
            SelectableText(
              content.isEmpty ? '（空内容）' : content,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
        ],
      ),
    );
  }
}

// ---------------- 图片 ----------------
class _SnapshotImage extends StatelessWidget {
  final String url;
  const _SnapshotImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
          body: Center(child: InteractiveViewer(child: Image.network(url))),
        ),
      )),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 240),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(url, fit: BoxFit.cover, errorBuilder: (c, e, st) =>
              const Padding(padding: EdgeInsets.all(8), child: Text('图片加载失败', style: TextStyle(color: Colors.red, fontSize: 12)))),
        ),
      ),
    );
  }
}

// ---------------- 语音 ----------------
class _VoiceTile extends StatefulWidget {
  final String url;
  final int duration;
  const _VoiceTile({required this.url, required this.duration});

  @override
  State<_VoiceTile> createState() => _VoiceTileState();
}

class _VoiceTileState extends State<_VoiceTile> {
  static final AudioPlayer _player = AudioPlayer();
  static _VoiceTileState? _active;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  Future<void> _toggle() async {
    if (_active != null && _active != this) {
      await _active!._stopInternal();
    }
    if (_playing) {
      await _stopInternal();
      return;
    }
    _active = this;
    await _player.play(UrlSource(widget.url));
    if (mounted) setState(() => _playing = true);
  }

  Future<void> _stopInternal() async {
    await _player.stop();
    if (mounted) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    final secs = widget.duration > 0 ? widget.duration : 0;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: _toggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_playing ? Icons.stop : Icons.play_arrow, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text('语音消息${secs > 0 ? ' · $secs 秒' : ''}', style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ---------------- 视频 ----------------
class _SnapshotVideo extends StatefulWidget {
  final String url;
  const _SnapshotVideo({required this.url});

  @override
  State<_SnapshotVideo> createState() => _SnapshotVideoState();
}

class _SnapshotVideoState extends State<_SnapshotVideo> {
  VideoPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await c.initialize();
      c.setLooping(false);
      if (!mounted) return;
      setState(() => _controller = c);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(10),
        color: Colors.white,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off, size: 18, color: Colors.red),
            SizedBox(width: 6),
            Text('视频消息（无法加载预览）', style: TextStyle(fontSize: 12, color: Colors.red)),
          ],
        ),
      );
    }
    if (_controller == null) {
      return const SizedBox(
        height: 90,
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _FullScreenVideo(controller: _controller!),
      )),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(aspectRatio: _controller!.value.aspectRatio, child: VideoPlayer(_controller!)),
              Container(color: Colors.black26),
              const Icon(Icons.play_circle_fill, size: 46, color: Colors.white),
              Positioned(
                left: 8,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                  child: const Text('视频消息 · 点击播放', style: TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullScreenVideo extends StatefulWidget {
  final VideoPlayerController controller;
  const _FullScreenVideo({required this.controller});

  @override
  State<_FullScreenVideo> createState() => _FullScreenVideoState();
}

class _FullScreenVideoState extends State<_FullScreenVideo> {
  @override
  void initState() {
    super.initState();
    widget.controller.play();
  }

  @override
  void dispose() {
    widget.controller.pause();
    widget.controller.seekTo(Duration.zero);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(
        child: AspectRatio(
          aspectRatio: widget.controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              VideoPlayer(widget.controller),
              VideoProgressIndicator(widget.controller, allowScrubbing: true,
                  colors: const VideoProgressColors(playedColor: Colors.redAccent)),
              Positioned(
                right: 12,
                bottom: 24,
                child: FloatingActionButton(
                  mini: true,
                  onPressed: () => setState(() {
                    widget.controller.value.isPlaying ? widget.controller.pause() : widget.controller.play();
                  }),
                  child: Icon(widget.controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
