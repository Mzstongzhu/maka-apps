import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../api.dart';
import '../widgets/avatar.dart';
import '../widgets/video_viewer.dart';

/// 发动态（全屏）。groupId 非空时发到小社区，无可见范围选项。
class ComposerScreen extends StatefulWidget {
  final int? groupId;
  final String? prefillTag; // 从标签详情进入：预填 #标签
  const ComposerScreen({super.key, this.groupId, this.prefillTag});
  @override
  State<ComposerScreen> createState() => _ComposerScreenState();
}

class _ComposerScreenState extends State<ComposerScreen> {
  final _ctrl = TextEditingController();
  final List<String> _media = []; // /uploads/... 相对路径（图片或视频）
  String _vis = 'public';
  bool _uploading = false;
  String _uploadHint = '';
  bool _posting = false;

  // ---------- @ ----------
  bool _atMode = false;
  String _atQuery = '';
  List<MentionCandidate> _atItems = [];
  Timer? _atDebounce;
  final Map<int, String> _mentions = {}; // uid -> 显示名

  // ---------- # 标签 # ----------
  // 与服务端 TAG_RE 保持一致：中英文/数字/下划线，1-20 字
  static final _tagRe = RegExp(r'^[一-龥A-Za-z0-9_]{1,20}$');
  int? _tagStart; // 当前标签起始 # 的下标
  String _tagDraft = '';
  final List<String> _tags = [];
  static const _maxTags = 10;

  @override
  void initState() {
    super.initState();
    // 标签详情页"带标签发布"：预填 #标签 与待提交标签
    if (widget.prefillTag != null && widget.prefillTag!.isNotEmpty) {
      _ctrl.text = '#${widget.prefillTag}# ';
      _tags.add(widget.prefillTag!);
    }
    _ctrl.addListener(_onChanged);
  }

  String get _visLabel => switch (_vis) {
        'self' => '仅自己可见',
        'whitelist' => '仅部分人可见',
        'blacklist' => '部分人不可见',
        _ => '公开',
      };

  // ============================================================
  // @ 与 #标签# 输入解析
  // ============================================================
  void _onChanged() {
    final text = _ctrl.text;
    final pos = _ctrl.selection.baseOffset;
    if (pos < 0) {
      _exitAtMode();
      _resetTag();
      return;
    }
    final pre = text.substring(0, pos);

    // ---- @：光标前最后一个 @，其间无空白/无第二个 @ 即为提及态 ----
    final atIdx = pre.lastIndexOf('@');
    if (atIdx >= 0) {
      final seg = pre.substring(atIdx + 1);
      if (!seg.contains('@') && !RegExp(r'\s').hasMatch(seg)) {
        _enterAtMode(seg);
      } else {
        _exitAtMode();
      }
    } else {
      _exitAtMode();
    }

    // ---- #标签#：记录起始位，空格或第二个 # 闭合；比 lastIndexOf 更稳 ----
    if (_tagStart != null) {
      final start = _tagStart!;
      if (start >= text.length || text[start] != '#' || pos <= start) {
        _resetTag();
      } else {
        final seg = text.substring(start + 1, pos);
        final hashIdx = seg.indexOf('#');
        final spIdx = seg.indexOf(RegExp(r'\s'));
        if (hashIdx >= 0) {
          _commitTag(seg.substring(0, hashIdx));
          _resetTag();
        } else if (spIdx >= 0) {
          _commitTag(seg.substring(0, spIdx));
          _resetTag();
        } else {
          if (_tagDraft != seg) setState(() => _tagDraft = seg);
        }
      }
    } else {
      // 新输入的字符恰为 #（单字键入/候选词上屏，光标前一位）
      if (pos > 0 && text[pos - 1] == '#') {
        // # 前不能紧贴字母数字（避免 C# 之类误触发），但中文紧邻允许：今天#天气#
        final p = pos - 1;
        final prevOk = p == 0 || !RegExp(r'[A-Za-z0-9]').hasMatch(text[p - 1]);
        if (prevOk) {
          setState(() { _tagStart = pos - 1; _tagDraft = ''; });
        }
      }
    }

    if (mounted) setState(() {});
  }

  void _enterAtMode(String q) {
    if (_atMode && _atQuery == q) return;
    _atMode = true;
    _atQuery = q;
    _atDebounce?.cancel();
    _atDebounce = Timer(q.isEmpty ? Duration.zero : const Duration(milliseconds: 200), () async {
      final items = await Api.getMentionSuggestions(q);
      if (!mounted || !_atMode || _atQuery != q) return;
      setState(() => _atItems = items);
    });
  }

  void _exitAtMode() {
    if (!_atMode) return;
    _atDebounce?.cancel();
    _atMode = false;
    _atQuery = '';
    _atItems = [];
  }

  void _pickMention(MentionCandidate u) {
    final text = _ctrl.text;
    final pos = _ctrl.selection.baseOffset;
    final pre = text.substring(0, pos < 0 ? text.length : pos);
    final at = pre.lastIndexOf('@');
    if (at < 0) return;
    final insert = '@${u.displayName} ';
    final newText = text.substring(0, at) + insert + text.substring(pos);
    final caret = at + insert.length;
    _ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: caret),
    );
    _mentions[u.id] = u.displayName;
    _exitAtMode();
    setState(() {});
  }

  void _commitTag(String name) {
    if (name.isEmpty) return; // 孤立的 # 字符，静默忽略
    if (!_tagRe.hasMatch(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('标签「$name」无效：需为 1-20 个中英文、数字或下划线'), duration: const Duration(seconds: 2)),
      );
      return;
    }
    if (_tags.length >= _maxTags && !_tags.contains(name)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('每条动态最多 $_maxTags 个标签'), duration: const Duration(seconds: 2)));
      return;
    }
    if (!_tags.contains(name)) {
      setState(() => _tags.add(name));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('已添加标签 #$name#'),
        duration: const Duration(milliseconds: 1200),
      ));
    }
  }

  void _resetTag() {
    if (_tagStart == null && _tagDraft.isEmpty) return;
    _tagStart = null;
    _tagDraft = '';
  }

  void _removeTag(String name) {
    // 同步删除正文中的 #name# 或 "#name " 片段
    var text = _ctrl.text;
    final closed = '#$name#';
    final spaced = '$name ';
    final i1 = text.indexOf(closed);
    if (i1 >= 0) text = text.replaceFirst(closed, name);
    final i2 = text.indexOf('#$spaced');
    if (i2 >= 0) text = text.replaceFirst('#$spaced', spaced);
    _ctrl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: _ctrl.selection.baseOffset.clamp(0, text.length)),
    );
    setState(() => _tags.remove(name));
  }

  Future<void> _pickMedia() async {
    if (_uploading) return;
    if (_media.length >= 9) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('最多 9 个图片/视频')));
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选图片（可多选）'),
              onTap: () => Navigator.pop(context, 'images'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('从相册选视频'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(context, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.video_call_outlined),
              title: const Text('录制视频（最长 60 秒）'),
              onTap: () => Navigator.pop(context, 'record'),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;
    try {
      if (action == 'images') {
        final pics = await ImagePicker().pickMultiImage(imageQuality: 85);
        if (pics.isNotEmpty) await _uploadImages(pics.take(9 - _media.length).toList());
      } else if (action == 'video' || action == 'record') {
        final x = await ImagePicker().pickVideo(
          source: action == 'record' ? ImageSource.camera : ImageSource.gallery,
          maxDuration: const Duration(seconds: 60),
        );
        if (x != null) await _uploadVideo(x);
      } else {
        final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
        if (x != null) await _uploadImages([x]);
      }
    } catch (e) {
      if (mounted) {
        setState(() { _uploading = false; _uploadHint = ''; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }

  Future<void> _uploadImages(List<XFile> pics) async {
    setState(() { _uploading = true; _uploadHint = '图片上传中…'; });
    final (urls, err) = await Api.uploadImages(
      pics.map((e) => e.path).toList(),
      mimes: pics.map((e) => e.mimeType).toList(),
    );
    if (!mounted) return;
    setState(() { _uploading = false; _uploadHint = ''; });
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('图片上传失败：$err')));
      return;
    }
    setState(() => _media.addAll(urls));
    if (urls.length < pics.length) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${pics.length - urls.length} 张图片上传失败')));
    }
  }

  Future<void> _uploadVideo(XFile x) async {
    final file = File(x.path);
    int size = 0;
    try { size = await file.length(); } catch (_) {}
    if (size > 50 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('视频不能超过 50MB（当前 ${(size / 1048576).toStringAsFixed(1)}MB）')));
      return;
    }
    final vc = VideoPlayerController.file(file);
    int seconds = 0;
    try {
      await vc.initialize();
      seconds = vc.value.duration.inSeconds;
    } catch (_) {
    } finally {
      await vc.dispose();
    }
    if (seconds > 60) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('视频时长不能超过 60 秒（当前 ${seconds}s）')));
      return;
    }
    setState(() { _uploading = true; _uploadHint = '视频上传中…'; });
    final (url, err) = await Api.uploadChatMediaFile(x.path, mime: x.mimeType);
    if (!mounted) return;
    setState(() { _uploading = false; _uploadHint = ''; });
    if (err != null || url == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? '视频上传失败')));
      return;
    }
    setState(() => _media.add(url));
  }

  Future<void> _submit() async {
    if (_posting) return;
    final content = _ctrl.text.trim();
    if (content.isEmpty && _media.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('说点什么吧')));
      return;
    }
    // 兜底：从正文提取 #name# 闭合标签（兼容粘贴/光标外编辑），与已提交标签合并
    final reHashes = RegExp(r'#([一-龥A-Za-z0-9_]{1,20})#');
    for (final m in reHashes.allMatches(_ctrl.text)) {
      final n = m.group(1)!;
      if (!_tags.contains(n) && _tags.length < _maxTags) _tags.add(n);
    }
    // @ 仅保留正文中仍存在 @显示名 的，避免删文后误通知
    final mentionIds = _mentions.entries
        .where((e) => _ctrl.text.contains('@${e.value}'))
        .map((e) => e.key)
        .toList();
    setState(() => _posting = true);
    final (status, err) = await Api.createPost(
      content: content,
      images: _media,
      visibility: widget.groupId == null ? _vis : 'public',
      groupId: widget.groupId,
      mentions: mentionIds,
      tags: _tags,
    );
    if (!mounted) return;
    setState(() => _posting = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (status == 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('内容已提交机器审核，通过后公开显示')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('发布成功')));
    }
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _atDebounce?.cancel();
    _ctrl.removeListener(_onChanged);
    _ctrl.dispose();
    super.dispose();
  }

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final isGroup = widget.groupId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isGroup ? '发到小社区' : '发动态'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilledButton(onPressed: _posting ? null : _submit, child: _posting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('发布')),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                maxLength: 5000,
                decoration: InputDecoration(
                  hintText: isGroup ? '分享点什么到小社区吧… 输入 @ 提到好友，# 添加标签' : '分享此刻的想法… 输入 @ 提到好友，# 添加标签',
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
            ),
            // @ 候选浮层（最近聊天置顶，服务端排序）
            if (_atMode) _mentionPanel(),
            // 标签输入态提示
            if (_tagStart != null) _tagDraftBar(),
            // 已添加标签 / 已提及用户
            if (_tags.isNotEmpty || _mentions.isNotEmpty) _chipsRow(),
            if (_media.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _media.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 96, height: 96,
                          child: isVideoPath(_media[i])
                              ? VideoThumb(url: _media[i], cover: true, showDuration: false)
                              : Image.network(absUrl(_media[i]), fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _media.removeAt(i)),
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            padding: const EdgeInsets.all(3),
                            child: const Icon(Icons.close, size: 13, color: Colors.white),
                          ),
                        ),
                      ),
                      if (isVideoPath(_media[i]))
                        const Positioned(
                          left: 6, bottom: 5,
                          child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 22),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _uploading ? null : _pickMedia,
                  icon: _uploading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.perm_media_outlined, size: 18),
                  label: Text(_uploading
                      ? _uploadHint
                      : '图片/视频 ${_media.isEmpty ? '' : '${_media.length}/9'}'),
                ),
                if (!isGroup) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final v = await showVisPicker(context, _vis);
                      if (v != null) setState(() => _vis = v);
                    },
                    icon: Icon(_vis == 'public' ? Icons.public : Icons.lock_outline, size: 18),
                    label: Text(_visLabel),
                  ),
                ],
                const Spacer(),
                Text('${_ctrl.text.length}/5000', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mentionPanel() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      height: 248,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(_atQuery.isEmpty ? '最近聊天' : '匹配用户', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ),
          const Divider(height: 1),
          Expanded(
            child: _atItems.isEmpty
                ? const Center(child: Text('没有匹配的用户', style: TextStyle(color: Colors.grey, fontSize: 13)))
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _atItems.length,
                    itemBuilder: (_, i) {
                      final u = _atItems[i];
                      return ListTile(
                        dense: true,
                        leading: MakaAvatar(user: u.toUser(), size: 36),
                        title: Text(u.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: u.customId.isEmpty ? null : Text('@${u.customId}', maxLines: 1, style: const TextStyle(fontSize: 11)),
                        onTap: () => _pickMention(u),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tagDraftBar() {
    final valid = _tagDraft.isEmpty || _tagRe.hasMatch(_tagDraft);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (valid ? Colors.indigo : Colors.red).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.tag, size: 16),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _tagDraft.isEmpty ? '输入标签内容，按空格或再输一个 # 完成' : '#${_tagDraft}#',
              style: TextStyle(fontSize: 13, color: valid ? Colors.indigo.shade800 : Colors.red),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(valid ? '空格 / # 完成' : '1-20 个中英文、数字或下划线',
              style: TextStyle(fontSize: 11, color: valid ? Colors.grey[600] : Colors.red)),
        ],
      ),
    );
  }

  Widget _chipsRow() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final t in _tags)
            Chip(
              label: Text('#$t#', style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
              onDeleted: () => _removeTag(t),
              deleteIcon: const Icon(Icons.cancel, size: 16),
              backgroundColor: Colors.indigo.withValues(alpha: 0.08),
            ),
          for (final e in _mentions.entries)
            Chip(
              label: Text('@${e.value}', style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
              onDeleted: () => setState(() => _mentions.remove(e.key)),
              deleteIcon: const Icon(Icons.cancel, size: 16),
              backgroundColor: Colors.teal.withValues(alpha: 0.08),
            ),
        ],
      ),
    );
  }
}

/// 可见范围选择（与网页四选项一致）
Future<String?> showVisPicker(BuildContext context, String current) async {
  const options = [
    ('public', '公开', '所有人可见'),
    ('self', '仅自己可见', '只有自己能看到这条动态'),
    ('whitelist', '仅谁可见', '仅指定用户可见，发布后可随时修改'),
    ('blacklist', '谁不可见', '指定用户不可见，发布后可随时修改'),
  ];
  return showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: options
            .map((o) => ListTile(
                  leading: Icon(switch (o.$1) {
                    'public' => Icons.public,
                    'self' => Icons.lock,
                    'whitelist' => Icons.group,
                    _ => Icons.visibility_off,
                  }),
                  title: Text(o.$2),
                  subtitle: Text(o.$3, style: const TextStyle(fontSize: 12)),
                  trailing: current == o.$1 ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(ctx, o.$1),
                ))
            .toList(),
      ),
    ),
  );
}
