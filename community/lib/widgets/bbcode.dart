import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';

// 轻量 BBCode 渲染器，与网页端白名单一致：
// [url=..]..[/url] [url]..[/url] [img]..[/img] [b][i][u][s]
// [color=..] [size=..] [center] [quote] [hr]，以及裸链接自动识别。

class _Node {
  final String tag; // root/text/b/i/u/s/color/size/url/img/center/quote/hr
  final String attr;
  final String? text;
  final List<_Node> children = [];
  _Node({this.tag = 'text', this.attr = '', this.text});
}

final _tagRe = RegExp(r'\[(/?)(b|i|u|s|color|size|center|quote|hr|url|img)(?:=([^\]]*))?\]', caseSensitive: false);
final _urlRe = RegExp(r'https?://[^\s<]+');

List<_Node> _parse(String src) {
  final root = _Node(tag: 'root');
  final stack = <_Node>[root];
  void addText(String s) {
    if (s.isNotEmpty) stack.last.children.add(_Node(text: s));
  }

  var pos = 0;
  for (final m in _tagRe.allMatches(src)) {
    addText(src.substring(pos, m.start));
    pos = m.end;
    final closing = m.group(1) == '/';
    final tag = m.group(2)!.toLowerCase();
    final attr = m.group(3) ?? '';
    if (tag == 'hr') {
      stack.last.children.add(_Node(tag: 'hr'));
      continue;
    }
    if (!closing) {
      final node = _Node(tag: tag, attr: attr);
      stack.last.children.add(node);
      stack.add(node);
    } else {
      // 找到最近的同名未闭合标签，中间未闭合的一并闭合
      var idx = -1;
      for (var i = stack.length - 1; i >= 1; i--) {
        if (stack[i].tag == tag) { idx = i; break; }
      }
      if (idx > 0) stack.removeRange(idx, stack.length);
    }
  }
  addText(src.substring(pos));
  return root.children;
}

void _launch(String url) async {
  final u = Uri.tryParse(url);
  if (u != null && await canLaunchUrl(u)) {
    await launchUrl(u, mode: LaunchMode.externalApplication);
  }
}

String? _safeUrl(String? u) {
  final s = (u ?? '').trim();
  return RegExp(r'^https?://\S+$', caseSensitive: false).hasMatch(s) ? s : null;
}

Color? _colorOf(String name) {
  final n = name.trim();
  if (RegExp(r'^#[0-9a-fA-F]{3,8}$').hasMatch(n)) {
    var hex = n.substring(1);
    if (hex.length == 3) hex = hex.split('').map((c) => c + c).join();
    if (hex.length == 6) hex += 'FF';
    return Color(int.parse(hex.substring(0, 8), radix: 16));
  }
  const named = {
    'red': Color(0xFFEF4444), 'blue': Color(0xFF3B82F6), 'green': Color(0xFF22C55E),
    'orange': Color(0xFFF97316), 'purple': Color(0xFFA855F7), 'gray': Color(0xFF6B7280),
    'grey': Color(0xFF6B7280), 'black': Color(0xFF111827), 'white': Color(0xFFFFFFFF),
  };
  return named[n.toLowerCase()];
}

void _addTextWithLinks(String text, TextStyle style, List<InlineSpan> out) {
  var last = 0;
  for (final m in _urlRe.allMatches(text)) {
    if (m.start > last) out.add(TextSpan(text: text.substring(last, m.start), style: style));
    out.add(TextSpan(
      text: m.group(0),
      style: style.copyWith(color: Colors.blue, decoration: TextDecoration.underline),
      recognizer: TapGestureRecognizer()..onTap = () => _launch(m.group(0)!),
    ));
    last = m.end;
  }
  if (last < text.length) out.add(TextSpan(text: text.substring(last), style: style));
}

void _renderInline(List<_Node> nodes, TextStyle style, List<InlineSpan> out) {
  for (final n in nodes) {
    switch (n.tag) {
      case 'text':
        _addTextWithLinks(n.text ?? '', style, out);
      case 'b':
        _renderInline(n.children, style.copyWith(fontWeight: FontWeight.bold), out);
      case 'i':
        _renderInline(n.children, style.copyWith(fontStyle: FontStyle.italic), out);
      case 'u':
        _renderInline(n.children, style.copyWith(decoration: TextDecoration.underline), out);
      case 's':
        _renderInline(n.children, style.copyWith(decoration: TextDecoration.lineThrough), out);
      case 'color':
        final c = _colorOf(n.attr);
        _renderInline(n.children, c == null ? style : style.copyWith(color: c), out);
      case 'size':
        final px = int.tryParse(n.attr)?.clamp(10, 40) ?? 14;
        _renderInline(n.children, style.copyWith(fontSize: px.toDouble()), out);
      case 'url':
        final url = _safeUrl(n.attr) ?? _safeUrl(_plain(n.children));
        if (url != null) {
          final inner = <InlineSpan>[];
          _renderInline(n.children.isEmpty ? [_Node(text: url)] : n.children, style.copyWith(color: Colors.blue, decoration: TextDecoration.underline), inner);
          out.add(TextSpan(children: inner, recognizer: TapGestureRecognizer()..onTap = () => _launch(url)));
        } else {
          _renderInline(n.children, style, out);
        }
      default:
        _renderInline(n.children, style, out);
    }
  }
}

String _plain(List<_Node> nodes) => nodes.map((n) => n.text ?? _plain(n.children)).join();

/// 渲染为块级 Widget 列表
List<Widget> _renderBlocks(BuildContext context, List<_Node> nodes, TextStyle base) {
  final blocks = <Widget>[];
  final inline = <InlineSpan>[];

  void flush() {
    if (inline.isEmpty) return;
    blocks.add(Text.rich(TextSpan(children: List.of(inline))));
    inline.clear();
  }

  for (final n in nodes) {
    switch (n.tag) {
      case 'img':
        flush();
        final url = _safeUrl(n.attr) ?? _safeUrl(_plain(n.children));
        if (url != null) {
          blocks.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                absUrl(url),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ));
        }
      case 'center':
        flush();
        blocks.add(
          Align(
            alignment: Alignment.center,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: _renderBlocks(context, n.children, base),
            ),
          ),
        );
      case 'quote':
        flush();
        blocks.add(Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border(left: BorderSide(width: 3, color: Colors.grey.shade400)),
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _renderBlocks(context, n.children, base.copyWith(color: Colors.grey.shade600)),
          ),
        ));
      case 'hr':
        flush();
        blocks.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Divider(height: 1),
        ));
      default:
        _renderInline([n], base, inline);
    }
  }
  flush();
  return blocks;
}

/// BBCode → Widget
Widget renderBBCode(BuildContext context, String src, {TextStyle? style}) {
  final effective = style ?? DefaultTextStyle.of(context).style;
  if (src.trim().isEmpty) return const SizedBox.shrink();
  final blocks = _renderBlocks(context, _parse(src), effective);
  if (blocks.isEmpty) return const SizedBox.shrink();
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocks);
}
