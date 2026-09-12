import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api.dart';

/// 发动态（全屏）。groupId 非空时发到群组，无可见范围选项。
class ComposerScreen extends StatefulWidget {
  final int? groupId;
  const ComposerScreen({super.key, this.groupId});
  @override
  State<ComposerScreen> createState() => _ComposerScreenState();
}

class _ComposerScreenState extends State<ComposerScreen> {
  final _ctrl = TextEditingController();
  final List<String> _images = []; // /uploads/... 相对路径
  final List<String> _localPaths = []; // 待上传的本地图
  String _vis = 'public';
  bool _uploading = false;
  bool _posting = false;

  String get _visLabel => switch (_vis) {
        'self' => '仅自己可见',
        'whitelist' => '仅部分人可见',
        'blacklist' => '部分人不可见',
        _ => '公开',
      };

  Future<void> _pickImages() async {
    if (_uploading || _images.length + _localPaths.length >= 9) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('最多 9 张图片')));
      return;
    }
    List<XFile> pics;
    try {
      final picker = ImagePicker();
      pics = await picker.pickMultiImage(imageQuality: 85);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('打开相册失败: $e')));
      return;
    }
    if (pics.isEmpty) return;
    final selected = pics.take(9 - _images.length).toList();
    setState(() => _uploading = true);
    final (urls, err) = await Api.uploadImages(
      selected.map((e) => e.path).toList(),
      mimes: selected.map((e) => e.mimeType).toList(),
    );
    if (!mounted) return;
    setState(() => _uploading = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('图片上传失败：$err')));
      return;
    }
    setState(() => _images.addAll(urls));
    if (urls.length < selected.length) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${selected.length - urls.length} 张图片上传失败')));
    }
  }

  Future<void> _submit() async {
    if (_posting) return;
    if (_ctrl.text.trim().isEmpty && _images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('说点什么吧')));
      return;
    }
    setState(() => _posting = true);
    final (status, err) = await Api.createPost(
      content: _ctrl.text.trim(),
      images: _images,
      visibility: widget.groupId == null ? _vis : 'public',
      groupId: widget.groupId,
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
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGroup = widget.groupId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isGroup ? '发到群组' : '发动态'),
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
                  hintText: isGroup ? '分享点什么到群组吧…' : '分享此刻的想法…',
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
            ),
            if (_images.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(absUrl(_images[i]), width: 96, height: 96, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _images.removeAt(i)),
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            padding: const EdgeInsets.all(3),
                            child: const Icon(Icons.close, size: 13, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _uploading ? null : _pickImages,
                  icon: _uploading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.image_outlined, size: 18),
                  label: Text(_uploading ? '上传中…' : '图片 ${_images.isEmpty ? '' : '${_images.length}/9'}'),
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
