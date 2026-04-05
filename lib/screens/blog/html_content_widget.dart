import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/smart_image.dart';

/// Lightweight HTML content renderer for blog posts.
/// Handles common tags: p, br, strong, em, b, i, u, h1-h4, ul, ol, li,
/// blockquote, img, a (displayed inline), pre/code.
class HtmlContentWidget extends StatelessWidget {
  final String html;

  const HtmlContentWidget({super.key, required this.html});

  @override
  Widget build(BuildContext context) {
    final widgets = _parseHtml(html);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  List<Widget> _parseHtml(String html) {
    final widgets = <Widget>[];

    // Split by block-level tags
    // Regex to find <img ...> tags, <h1-4>...</h1-4>, <blockquote>...</blockquote>,
    // <ul>...</ul>, <ol>...</ol>, <pre>...</pre>, <p>...</p>
    final blockPattern = RegExp(
      r'<(img)\s[^>]*/?>|<(h[1-4])[^>]*>([\s\S]*?)</\2>|<(blockquote)[^>]*>([\s\S]*?)</blockquote>|<(ul)[^>]*>([\s\S]*?)</ul>|<(ol)[^>]*>([\s\S]*?)</ol>|<(pre)[^>]*>([\s\S]*?)</pre>|<(p)[^>]*>([\s\S]*?)</p>',
      caseSensitive: false,
    );

    int lastEnd = 0;
    for (final match in blockPattern.allMatches(html)) {
      // Text between blocks
      if (match.start > lastEnd) {
        final between = html.substring(lastEnd, match.start).trim();
        if (between.isNotEmpty) {
          final cleaned = _stripTags(between).trim();
          if (cleaned.isNotEmpty) {
            widgets.add(Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildRichText(cleaned, fontSize: 15),
            ));
          }
        }
      }
      lastEnd = match.end;

      final fullMatch = match.group(0)!;

      // img
      if (match.group(1) != null) {
        final srcMatch = RegExp(r'src="([^"]*)"').firstMatch(fullMatch);
        if (srcMatch != null) {
          final src = srcMatch.group(1)!;
          widgets.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SmartImage(
                url: src,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ));
        }
        continue;
      }

      // h1-h4
      if (match.group(2) != null) {
        final tag = match.group(2)!.toLowerCase();
        final content = _stripTags(match.group(3) ?? '').trim();
        if (content.isEmpty) continue;
        final fontSize = switch (tag) {
          'h1' => 24.0,
          'h2' => 20.0,
          'h3' => 18.0,
          _ => 16.0,
        };
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(content,
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ));
        continue;
      }

      // blockquote
      if (match.group(4) != null) {
        final content = _stripTags(match.group(5) ?? '').trim();
        if (content.isEmpty) continue;
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.primary, width: 3),
              ),
              color: const Color(0xFFF8FAFC),
            ),
            child: Text(content,
                style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary,
                    height: 1.6)),
          ),
        ));
        continue;
      }

      // ul
      if (match.group(6) != null) {
        final items = _extractListItems(match.group(7) ?? '');
        for (final item in items) {
          widgets.add(Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  ',
                    style: TextStyle(fontSize: 15, color: AppColors.textPrimary)),
                Expanded(child: _buildRichText(item, fontSize: 15)),
              ],
            ),
          ));
        }
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // ol
      if (match.group(8) != null) {
        final items = _extractListItems(match.group(9) ?? '');
        for (int i = 0; i < items.length; i++) {
          widgets.add(Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${i + 1}. ',
                    style: const TextStyle(
                        fontSize: 15, color: AppColors.textPrimary)),
                Expanded(child: _buildRichText(items[i], fontSize: 15)),
              ],
            ),
          ));
        }
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // pre
      if (match.group(10) != null) {
        final content = _stripTags(match.group(11) ?? '').trim();
        if (content.isEmpty) continue;
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(content,
                style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    color: Color(0xFFE2E8F0),
                    height: 1.5)),
          ),
        ));
        continue;
      }

      // p
      if (match.group(12) != null) {
        final rawContent = match.group(13) ?? '';
        // Check for img inside p
        final imgMatch = RegExp(r'<img\s[^>]*src="([^"]*)"[^>]*/?>',
                caseSensitive: false)
            .firstMatch(rawContent);
        if (imgMatch != null) {
          widgets.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SmartImage(
                url: imgMatch.group(1)!,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ));
        }
        final textContent = _stripTags(rawContent).trim();
        if (textContent.isNotEmpty) {
          widgets.add(Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildRichText(textContent, fontSize: 15),
          ));
        }
        continue;
      }
    }

    // Remaining text after last block
    if (lastEnd < html.length) {
      final remaining = _stripTags(html.substring(lastEnd)).trim();
      if (remaining.isNotEmpty) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildRichText(remaining, fontSize: 15),
        ));
      }
    }

    return widgets;
  }

  List<String> _extractListItems(String html) {
    final items = <String>[];
    final liPattern = RegExp(r'<li[^>]*>([\s\S]*?)</li>', caseSensitive: false);
    for (final match in liPattern.allMatches(html)) {
      final text = _stripTags(match.group(1) ?? '').trim();
      if (text.isNotEmpty) items.add(text);
    }
    return items;
  }

  Widget _buildRichText(String text, {double fontSize = 15}) {
    // Handle <br> as newlines, decode entities
    final processed = text
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');

    return Text(
      processed,
      style: TextStyle(
        fontSize: fontSize,
        height: 1.7,
        color: AppColors.textPrimary,
      ),
    );
  }

  String _stripTags(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
  }
}
