/// Turn Yuque-style HTML in a note into markdown the reader can display.
///
/// Escaped tags such as `&lt;font&gt;` are restored first. Headings, links,
/// emphasis and images become markdown. Remaining tags are removed and their
/// text is kept. Markdown images already in the note are left in place.
String readableRemoteNote(String source) {
  var text = source;
  if (text.contains('&lt;')) {
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }
  text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  text = text.replaceAllMapped(
    RegExp(r'<img\b[^>]*>', caseSensitive: false),
    (match) {
      final tag = match.group(0) ?? '';
      final src = _attr(tag, 'src');
      if (src == null || src.isEmpty) return '';
      final alt = (_attr(tag, 'alt') ?? '').replaceAll(RegExp(r'[\[\]]'), '');
      final safe = src
          .replaceAll(' ', '%20')
          .replaceAll('(', '%28')
          .replaceAll(')', '%29');
      return '\n![$alt]($safe)\n';
    },
  );
  text = text.replaceAllMapped(
    RegExp(
      '<a\\b[^>]*href\\s*=\\s*(?:"([^"]*)"|\'([^\']*)\')[^>]*>(.*?)</a>',
      caseSensitive: false,
      dotAll: true,
    ),
    (match) {
      final href = (match.group(1) ?? match.group(2) ?? '').trim();
      final label = _plain(match.group(3) ?? '');
      if (href.isEmpty) return label;
      return '[$label]($href)';
    },
  );
  for (var level = 1; level <= 6; level++) {
    text = text.replaceAllMapped(
      RegExp('<h$level\\b[^>]*>(.*?)</h$level>',
          caseSensitive: false, dotAll: true),
      (match) => '\n${'#' * level} ${_plain(match.group(1) ?? '')}\n',
    );
  }
  text = text.replaceAllMapped(
    RegExp(r'<(strong|b)\b[^>]*>(.*?)</\1>', caseSensitive: false, dotAll: true),
    (match) => '**${match.group(2) ?? ''}**',
  );
  text = text.replaceAllMapped(
    RegExp(r'<(em|i)\b[^>]*>(.*?)</\1>', caseSensitive: false, dotAll: true),
    (match) => '*${match.group(2) ?? ''}*',
  );
  text = text.replaceAllMapped(
    RegExp(r'<pre\b[^>]*>(.*?)</pre>', caseSensitive: false, dotAll: true),
    (match) => '\n```\n${_plain(match.group(1) ?? '')}\n```\n',
  );
  text = text.replaceAllMapped(
    RegExp(r'<code\b[^>]*>(.*?)</code>', caseSensitive: false, dotAll: true),
    (match) => '`${match.group(1) ?? ''}`',
  );
  text = text.replaceAll(RegExp(r'<li\b[^>]*>', caseSensitive: false), '\n- ');
  text = text.replaceAll(
      RegExp(r'<blockquote\b[^>]*>', caseSensitive: false), '\n> ');
  text = text.replaceAll(
    RegExp(r'</(p|div|li|ul|ol|blockquote|tr|section|article)\s*>',
        caseSensitive: false),
    '\n',
  );
  text = text.replaceAll(RegExp(r'</?[A-Za-z][^>]*>'), '');
  return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

String _plain(String value) =>
    value.replaceAll(RegExp(r'</?[A-Za-z][^>]*>'), '').trim();

String? _attr(String tag, String name) {
  final match = RegExp(
    '$name\\s*=\\s*(?:"([^"]*)"|\'([^\']*)\')',
    caseSensitive: false,
  ).firstMatch(tag);
  final value = match?.group(1) ?? match?.group(2);
  if (value == null) return null;
  return value
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .trim();
}

/// Resolve an image address against the note file.
///
/// Absolute http(s) addresses are returned as-is. A relative address is
/// resolved against the note, so `photo.png` next to `note.md` stays on the
/// same WebDAV server. Anything else cannot be loaded.
Uri? resolveNoteImage(Uri noteUri, String raw) {
  final value = raw.trim();
  if (value.isEmpty || value.startsWith('data:')) return null;
  if (value.contains(RegExp(r'[\x00-\x20\x7f]'))) return null;
  final parsed = Uri.tryParse(value);
  if (parsed == null) return null;
  if (parsed.hasScheme) {
    if (parsed.scheme != 'http' && parsed.scheme != 'https') return null;
    if (parsed.userInfo.isNotEmpty || parsed.host.isEmpty) return null;
    return parsed;
  }
  if (value.startsWith('//')) return null;
  return noteUri.resolve(value);
}
