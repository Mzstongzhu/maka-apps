import 'package:flutter/material.dart';
import '../api.dart';
import 'avatar.dart';
import 'user_tag.dart';
import 'report_sheet.dart';
import 'visibility_editor.dart';

/// 全屏图片查看器
Future<void> showImageViewer(BuildContext context, String url) async {
  await showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => GestureDetector(
      onTap: () => Navigator.pop(context),
      child: InteractiveViewer(
        maxScale: 4,
        child: Center(child: Image.network(url, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 48))),
      ),
    ),
  );
}

String _visText(String v) => switch (v) {
      'self' => '仅自己可见',
      'whitelist' => '仅部分人可见',
      'blacklist' => '部分人不可见',
      _ => '公开',
    };

/// 动态卡片（列表 / 详情通用）
class PostCard extends StatefulWidget {
  final Post post;
  final int myId;
  final bool myIsAdmin;
  final VoidCallback? onChanged; // 内容变化（编辑/可见性/点赞）后由父级刷新
  final VoidCallback? onRemoved;
  final VoidCallback? onOpenComments;
  const PostCard({
    super.key,
    required this.post,
    required this.myId,
    this.myIsAdmin = false,
    this.onChanged,
    this.onRemoved,
    this.onOpenComments,
  });
  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool get isMine => widget.post.author?.id == widget.myId;

  Future<void> _toggleLike() async {
    final liked = await Api.toggleLike(widget.post.id);
    if (!mounted) return;
    setState(() {
      widget.post.liked = liked;
      widget.post.likeCount += liked ? 1 : -1;
    });
  }

  Future<void> _delete({bool admin = false}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(admin ? '管理员删除' : '删除动态'),
        content: const Text('确定删除这条动态吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    final err = await Api.deletePost(widget.post.id);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除')));
      widget.onRemoved?.call();
    }
  }

  Future<void> _edit() async {
    final ctrl = TextEditingController(text: widget.post.content);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑内容'),
        content: TextField(controller: ctrl, maxLines: 5, maxLength: 5000),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok != true) return;
    final text = ctrl.text.trim();
    if (text.isEmpty) return;
    final err = await Api.updatePost(widget.post.id, {'content': text});
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      setState(() => widget.post.content = text);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
      widget.onChanged?.call();
    }
  }

  Future<void> _menu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMine) ...[
              ListTile(leading: const Icon(Icons.visibility_outlined), title: Text('可见范围：${_visText(widget.post.visibility)}'), onTap: () => Navigator.pop(ctx, 'vis')),
              ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('编辑内容'), onTap: () => Navigator.pop(ctx, 'edit')),
            ],
            if (!isMine)
              ListTile(leading: const Icon(Icons.flag_outlined), title: const Text('举报'), onTap: () => Navigator.pop(ctx, 'report')),
            if (!isMine && widget.myIsAdmin)
              ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red), title: const Text('管理员删除', style: TextStyle(color: Colors.red)), onTap: () => Navigator.pop(ctx, 'adminDel')),
            if (isMine)
              ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red), title: const Text('删除', style: TextStyle(color: Colors.red)), onTap: () => Navigator.pop(ctx, 'del')),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit': _edit();
      case 'del': _delete();
      case 'adminDel': _delete(admin: true);
      case 'report': showReportSheet(context, 'post', widget.post.id);
      case 'vis':
        final saved = await showVisibilityEditor(context, widget.post);
        if (saved) widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final cs = Theme.of(context).colorScheme;
    final edited = p.updatedAt > p.createdAt;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MakaAvatar(user: p.author, size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: UserTag(user: p.author, sub: '${formatTime(p.createdAt)}${edited ? ' · 已编辑' : ''}'),
                ),
                if (p.group != null)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(5)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.groups, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 3),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 90),
                          child: Text(p.group!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        ),
                      ],
                    ),
                  ),
                if (p.status == 'pending')
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text('审核中', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  )
                else if (p.status == 'rejected')
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text('未通过审核', style: TextStyle(fontSize: 11, color: Colors.red)),
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.more_horiz, size: 20),
                  onPressed: _menu,
                ),
              ],
            ),
            if (p.content.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8, bottom: p.images.isEmpty ? 4 : 8),
                child: Text(p.content, style: const TextStyle(fontSize: 15, height: 1.45)),
              ),
            if (p.images.isNotEmpty) _imageGrid(p.images),
            const SizedBox(height: 6),
            Row(
              children: [
                InkWell(
                  onTap: _toggleLike,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        Icon(p.liked ? Icons.favorite : Icons.favorite_border, size: 18, color: p.liked ? Colors.red : Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(p.likeCount > 0 ? '${p.likeCount}' : '', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: widget.onOpenComments,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(p.commentCount > 0 ? '${p.commentCount}' : '', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Text('#${p.author?.id ?? ''}', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                if (isMine && p.visibility != 'public')
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(Icons.lock_outline, size: 13, color: cs.primary.withValues(alpha: 0.5)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageGrid(List<String> images) {
    final urls = images.map((e) => absUrl(e)).toList();
    final count = urls.length.clamp(1, 9);
    final cross = count == 1 ? 1 : (count <= 4 ? 2 : 3);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cross,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: count == 1 ? (16 / 10) : 1,
        ),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => showImageViewer(context, urls[i]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(urls[i], fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image))),
          ),
        ),
      ),
    );
  }
}
