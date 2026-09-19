import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
import '../api.dart';

/// 消息发送回调（媒体已在组件内完成上传，content 对媒体为服务端 URL）
typedef ChatSendHandler = Future<String?> Function(String type, String content, int duration);

/// 统一聊天输入条：文本 + 相册/拍摄(图/视频) + 按住录音（≤60s，上滑取消）
class ChatInputBar extends StatefulWidget {
  final ChatSendHandler onSend;
  final bool enabled;
  const ChatInputBar({super.key, required this.onSend, this.enabled = true});
  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
  bool _recording = false;
  int _recSeconds = 0;
  bool _willCancel = false;
  final AudioRecorder _recorder = AudioRecorder();
  String? _recPath;

  static const int _maxRec = 60;

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    _input.clear();
    setState(() => _busy = true);
    final err = await widget.onSend('text', text, 0);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      _input.text = text;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      _focus.requestFocus();
    }
  }

  // ---------- 图片/视频 ----------

  Future<void> _showAttachSheet() async {
    showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择（图片/视频）'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(context, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('录制视频'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
          ],
        ),
      ),
    ).then((v) {
      if (v == 'gallery') _pickGallery();
      if (v == 'photo') _takePhoto();
      if (v == 'video') _takeVideo();
    });
  }

  Future<void> _pickGallery() async {
    final x = await ImagePicker().pickMedia(imageQuality: 85);
    if (x == null) return;
    final isVideo = x.mimeType?.startsWith('video/') == true ||
        x.path.toLowerCase().endsWith('.mp4') || x.path.toLowerCase().endsWith('.mov');
    await _processPicked(x, isVideo);
  }

  Future<void> _takePhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
    if (x != null) await _processPicked(x, false);
  }

  Future<void> _takeVideo() async {
    final x = await ImagePicker().pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 60));
    if (x != null) await _processPicked(x, true);
  }

  Future<void> _processPicked(XFile x, bool isVideo) async {
    final file = File(x.path);
    int size = 0;
    try { size = await file.length(); } catch (_) {}
    if (isVideo) {
      if (size > 50 * 1024 * 1024) {
        _warn('视频不能超过 50MB（当前 ${(size / 1048576).toStringAsFixed(1)}MB）');
        return;
      }
      final vc = VideoPlayerController.file(file);
      int seconds = 0;
      try {
        await vc.initialize();
        seconds = vc.value.duration.inSeconds;
      } catch (_) {}
      await vc.dispose();
      if (seconds > 60) {
        _warn('视频时长不能超过 60 秒（当前 ${seconds}s）');
        return;
      }
      await _uploadAndSend(file.path, 'video', 0);
    } else {
      if (size > 10 * 1024 * 1024) {
        _warn('图片不能超过 10MB（当前 ${(size / 1048576).toStringAsFixed(1)}MB）');
        return;
      }
      await _uploadAndSend(file.path, 'image', 0);
    }
  }

  Future<void> _uploadAndSend(String path, String type, int duration) async {
    setState(() => _busy = true);
    final (url, upErr) = type == 'image'
        ? await Api.uploadChatImageFile(path)
        : await Api.uploadChatMediaFile(path);
    if (!mounted) return;
    if (upErr != null || url == null) {
      setState(() => _busy = false);
      _warn(upErr ?? '上传失败');
      return;
    }
    final sendErr = await widget.onSend(type, url, duration);
    if (!mounted) return;
    setState(() => _busy = false);
    if (sendErr != null) _warn(sendErr);
  }

  void _warn(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------- 录音 ----------

  Future<void> _startRecord() async {
    if (_busy || _recording) return;
    final ok = await _recorder.hasPermission();
    if (!ok) {
      _warn('需要麦克风权限才能发送语音，请在系统设置中开启');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    try {
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 96000, sampleRate: 44100),
        path: path,
      );
    } catch (e) {
      _warn('录音启动失败');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _recording = true; _recSeconds = 0; _willCancel = false; _recPath = path;
    });
    _tick();
  }

  void _tick() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!_recording) return;
    setState(() => _recSeconds += 1);
    if (_recSeconds >= _maxRec) {
      _stopRecord(send: !_willCancel);
      return;
    }
    _tick();
  }

  void _onMoveUpdate(LongPressMoveUpdateDetails d) {
    // 相对起点上滑 80px 进入取消态
    final cancel = d.localOffsetFromOrigin.dy < -80;
    if (cancel != _willCancel) setState(() => _willCancel = cancel);
  }

  Future<void> _stopRecord({required bool send}) async {
    if (!_recording) return;
    setState(() => _recording = false);
    String? path;
    try { path = await _recorder.stop(); } catch (_) {}
    path ??= _recPath;
    final seconds = _recSeconds;
    if (!send || path == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已取消录音')));
      return;
    }
    if (seconds < 1) {
      _warn('说话时间太短');
      return;
    }
    setState(() => _busy = true);
    final (url, err) = await Api.uploadChatMediaFile(path);
    if (!mounted) return;
    if (err != null || url == null) {
      setState(() => _busy = false);
      _warn(err ?? '语音上传失败');
      return;
    }
    final sendErr = await widget.onSend('voice', url, seconds);
    if (!mounted) return;
    setState(() => _busy = false);
    if (sendErr != null) _warn(sendErr);
  }

  @override
  Widget build(BuildContext context) {
    final canType = widget.enabled && !_busy;
    final hasText = _input.text.trim().isNotEmpty;
    return Stack(
      children: [
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  tooltip: '相册 / 拍摄',
                  onPressed: canType ? _showAttachSheet : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _input,
                      focusNode: _focus,
                      enabled: canType,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: '输入消息…', border: InputBorder.none, isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                hasText
                    ? IconButton.filled(
                        onPressed: canType ? _sendText : null,
                        icon: _busy
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send),
                      )
                    : GestureDetector(
                        onLongPressStart: canType ? (_) => _startRecord() : null,
                        onLongPressEnd: canType ? (_) => _stopRecord(send: !_willCancel) : null,
                        onLongPressMoveUpdate: canType ? _onMoveUpdate : null,
                        child: IconButton.filled(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('按住麦克风说话，上滑取消')));
                          },
                          icon: const Icon(Icons.mic),
                        ),
                      ),
              ],
            ),
          ),
        ),
        if (_recording) _recordOverlay,
      ],
    );
  }

  Widget get _recordOverlay => Positioned.fill(
    child: IgnorePointer(
      child: Container(
        color: Colors.black38,
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_willCancel ? Icons.delete_outline : Icons.mic,
                  color: _willCancel ? Colors.redAccent : Colors.white, size: 44),
              const SizedBox(height: 10),
              Text(_willCancel ? '松开手指，取消发送' : '上滑取消，松开发送',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 6),
              Text('$_recSeconds″ / ${_maxRec}s',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    ),
  );
}
