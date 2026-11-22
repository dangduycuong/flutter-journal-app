import 'package:material_ui/material_ui.dart';

import '../../core/utils/vietnamese_helper.dart';

class HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final int? maxLines;
  final TextOverflow overflow;

  const HighlightedText({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.highlightStyle,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final baseStyle = (style ?? const TextStyle(fontSize: 14)).copyWith(
      color: style?.color ?? textColor,
    );

    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty || text.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final normText = VietnameseHelper.removeDiacritics(text).toLowerCase();
    final normQuery = VietnameseHelper.removeDiacritics(cleanQuery)
        .toLowerCase();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultHighlightStyle =
        highlightStyle ??
        baseStyle.copyWith(
          backgroundColor: isDark
              ? Colors.amber.shade700.withValues(alpha: 0.45)
              : Colors.amber.shade300,
          color: isDark ? Colors.amber.shade100 : Colors.black,
          fontWeight: FontWeight.bold,
        );

    final List<TextSpan> spans = [];
    int start = 0;
    int indexOfMatch = normText.indexOf(normQuery, start);

    String displayText = text;
    String displayNormText = normText;
    if (maxLines != null && indexOfMatch > 60) {
      final cutOffset = indexOfMatch - 30;
      displayText = '...${text.substring(cutOffset)}';
      displayNormText = '...${normText.substring(cutOffset)}';
      indexOfMatch = displayNormText.indexOf(normQuery, 0);
    }

    while (indexOfMatch != -1) {
      if (indexOfMatch > start) {
        spans.add(TextSpan(text: displayText.substring(start, indexOfMatch)));
      }
      final endOfMatch = indexOfMatch + normQuery.length;
      spans.add(
        TextSpan(
          text: displayText.substring(indexOfMatch, endOfMatch),
          style: defaultHighlightStyle,
        ),
      );
      start = endOfMatch;
      indexOfMatch = displayNormText.indexOf(normQuery, start);
    }

    if (start < displayText.length) {
      spans.add(TextSpan(text: displayText.substring(start)));
    }

    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
