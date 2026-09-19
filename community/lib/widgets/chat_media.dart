import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import '../api.dart';

/// 气泡内消息内容：text/image/voice/video，三类会话共用
class ChatMediaContent extends StatelessWidget {
  final String type;
  final String content;
  final int duration;
  final bool fromMe;
  const ChatMediaContent({
    super.key,
    required this.type,
    required this.content,
    this.duration = 0,
    required this.fromMe,
  });

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case 'image':
        return _ImageThumb(url: content);
      case 'voice':
        return VoiceBar(url: content, seconds: duration, fromMe: fromMe);
      case 'video':
        return _VideoThumb(url: content);
      default:
        return Text(content, style: TextStyle(color: fromMe ? Colors.white : null, fontSize: 15));
    }
  }
}

// ---------- 图片 ----------

class _ImageThumb extends StatelessWidget {
  final String url;
  const _ImageThumb({required this.url});
  @override
  Widget build(BuildContext context) {
    final u = absUrl(url);
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => _ImageFullScreen(url: u))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          u,
          width: 180,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 180, height: 120, color: Colors.black12,
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
    );
  }
}

class _ImageFullScreen extends StatelessWidget {
  final String url;
  const _ImageFullScreen({required this.url});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8, maxScale: 4,
          child: Image.network(url),
        ),
      ),
    );
  }
}

// ---------- 语音 ----------

class VoiceBar extends StatefulWidget {
  final String url;
  final int seconds;
  final bool fromMe;
  const VoiceBar({super.key, required this.url, required this.seconds, required this.fromMe});
  @override
  State<VoiceBar> createState() => _VoiceBarState();
}

// 全局同时只播一条
AudioPlayer? _voicePlayer;
_VoiceBarState? _voiceState;

class _VoiceBarState extends State<VoiceBar> {
  bool _playing = false;
  int _posMs = 0;
  int _totalMs = 0;

  @override
  void initState() {
    super.initState();
    _totalMs = (widget.seconds > 0 ? widget.seconds : 1) * 1000;
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _voicePlayer?.pause();
      return;
    }
    // 切到本条：停掉旧的
    if (_voiceState != null && _voiceState != this) {
      await _voicePlayer?.stop();
      _voicePlayer?.dispose();
      _voiceState?._reset();
      _voicePlayer = null;
    }
    _voicePlayer ??= AudioPlayer();
    _voiceState = this;
    final player = _voicePlayer!;
    player.onPositionChanged.listen((d) {
      if (mounted && _voicePlayer == player) setState(() => _posMs = d.inMilliseconds);
    });
    player.onDurationChanged.listen((d) {
      if (mounted && d.inMilliseconds > 0 && _voicePlayer == player) setState(() => _totalMs = d.inMilliseconds);
    });
    player.onPlayerComplete.listen((_) {
      if (mounted && _voicePlayer == player) {
        setState(() { _playing = false; _posMs = 0; });
      }
    });
    try {
      await player.play(UrlSource(absUrl(widget.url)));
      if (mounted) setState(() => _playing = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('语音播放失败')));
      }
    }
  }

  void _reset() {
    if (mounted) setState(() { _playing = false; _posMs = 0; });
  }

  @override
  void dispose() {
    if (_voiceState == this) {
      _voicePlayer?.dispose();
      _voicePlayer = null;
      _voiceState = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shownSec = (_totalMs / 1000).ceil().clamp(1, 3600);
    final progress = _totalMs > 0 ? (_posMs / _totalMs).clamp(0.0, 1.0) : 0.0;
    final iconColor = widget.fromMe ? Colors.white : Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: _toggle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_playing ? Icons.stop_rounded : Icons.play_arrow_rounded, color: iconColor, size: 28),
          const SizedBox(width: 8),
          SizedBox(
            width: shownSec.clamp(1, 60) * 2.4 + 24,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: (widget.fromMe ? Colors.white : Theme.of(context).colorScheme.primary)
                        .withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                  FractionallySizedBox(
                    widthFactor: _playing ? progress.toDouble() : 0,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: widget.fromMe ? Colors.white : Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
            ),
          ),
          const SizedBox(width: 8),
          Text('$shownSec″',
              style: TextStyle(color: widget.fromMe ? Colors.white : Colors.black87, fontSize: 13)),
        ],
      ),
    );
  }
}

// ---------- 视频 ----------

class _VideoThumb extends StatefulWidget {
  final String url;
  const _VideoThumb({required this.url});
  @override
  State<_VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<_VideoThumb> {
  VideoPlayerController? _ctrl;
  bool _ready = false;
  String? _err;

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
      await c.seekTo(Duration.zero);
      await c.pause();
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_err != null || !_ready || _ctrl == null) {
      return GestureDetector(
        onTap: () => _openFull(),
        child: Container(
          width: 180, height: 120,
          color: Colors.black12,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_circle_fill, size: 40, color: Colors.white70),
              const SizedBox(height: 4),
              Text(_err != null ? '点击直接播放' : '视频加载中…',
                  style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: _openFull,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 180,
          child: AspectRatio(
            aspectRatio: _ctrl!.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_ctrl!),
                const Icon(Icons.play_circle_fill, size: 44, color: Colors.white70),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openFull() {
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => _VideoFullScreen(url: widget.url)));
  }
}

class _VideoFullScreen extends StatefulWidget {
  final String url;
  const _VideoFullScreen({required this.url});
  @override
  State<_VideoFullScreen> createState() => _VideoFullScreenState();
}

class _VideoFullScreenState extends State<_VideoFullScreen> {
  late final VideoPlayerController _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(absUrl(widget.url)));
    _ctrl.initialize().then((_) {
      if (mounted) setState(() => _ready = true);
      _ctrl.play();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: !_ready
            ? const CircularProgressIndicator()
            : AspectRatio(aspectRatio: _ctrl.value.aspectRatio, child: VideoPlayer(_ctrl)),
      ),
      floatingActionButton: !_ready ? null : FloatingActionButton(
        onPressed: () => setState(() {
          _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play();
        }),
        child: Icon(_ctrl.value.isPlaying ? Icons.pause : Icons.play_arrow),
      ),
    );
  }
}
