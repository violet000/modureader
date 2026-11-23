import 'dart:convert';
import 'dart:typed_data';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:path/path.dart' as p;

const dictionaryResourceLimit = 32 * 1024 * 1024;

String dictionaryResourcePath(String path) {
  final normalized =
      path.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
  if (normalized.isEmpty ||
      normalized.contains(':') ||
      normalized.contains('\u0000') ||
      normalized.split('/').contains('..')) {
    throw const DictionaryFailure('resource');
  }
  return p.posix.normalize(normalized);
}

const dictionaryResourceTypes = {
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
  '.mp3': 'audio/mpeg',
  '.wav': 'audio/wav',
  '.ogg': 'audio/ogg',
  '.m4a': 'audio/mp4',
  '.aac': 'audio/aac',
  '.css': 'text/css',
  '.js': 'text/javascript',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
};

class DictionaryFailure implements Exception {
  const DictionaryFailure(this.code);
  final String code;
  @override
  String toString() => 'DictionaryFailure($code)';
}

class LocalDictionary {
  const LocalDictionary(
      this.id, this.name, this.format, this.count, this.enabled);
  final String id, name, format;
  final int count;
  final bool enabled;
}

class DictionaryEntry {
  const DictionaryEntry(this.dictionary, this.word, this.definition,
      {this.dictionaryId,
      this.sourceUri,
      this.license,
      this.licenseUri,
      this.html,
      this.attribution});
  final String dictionary, word, definition;
  final String? dictionaryId, license, attribution;
  final Uri? sourceUri, licenseUri;
  final String? html;
}

/// Convert untrusted dictionary markup to text, retaining paragraph boundaries.
/// No web view, scripts, CSS, external images, URLs or resource loads are used.
String dictionaryPlainText(String source) {
  final document = html.parseFragment(source);
  document
      .querySelectorAll('script,style,iframe,object,embed,svg,head')
      .forEach((element) => element.remove());
  final out = StringBuffer();
  const blocks = {'p', 'div', 'br', 'li', 'tr', 'h1', 'h2', 'h3', 'h4', 'hr'};
  void visit(dom.Node node) {
    if (node is dom.Text) out.write(node.text);
    if (node is dom.Element && blocks.contains(node.localName)) out.writeln();
    for (final child in node.nodes) {
      visit(child);
    }
    if (node is dom.Element && blocks.contains(node.localName)) out.writeln();
  }

  visit(document);
  return out
      .toString()
      .replaceAll('\u0000', '')
      .replaceAll(RegExp(r'\n[ \t]*\n(?:[ \t]*\n)+'), '\n\n')
      .trim();
}

String starDictDefinition(Uint8List bytes, String? sequence) {
  var at = 0;
  final parts = <String>[];
  var field = 0;
  while (at < bytes.length) {
    final type = sequence == null
        ? String.fromCharCode(bytes[at++])
        : (field < sequence.length ? sequence[field] : '');
    if (!RegExp(r'^[a-zA-Z]$').hasMatch(type)) {
      throw const DictionaryFailure('format');
    }
    final binary = type == type.toUpperCase();
    final last = sequence != null && field == sequence.length - 1;
    int end;
    if (last) {
      end = bytes.length;
    } else if (binary) {
      if (at + 4 > bytes.length) throw const DictionaryFailure('format');
      final length = ByteData.sublistView(bytes).getUint32(at);
      at += 4;
      end = at + length;
    } else {
      end = bytes.indexOf(0, at);
    }
    if (end < at || end > bytes.length) throw const DictionaryFailure('format');
    if (!binary) {
      if (!{'m', 't', 'y', 'h', 'g', 'x', 'k', 'w', 'n', 'r'}.contains(type)) {
        throw const DictionaryFailure('type');
      }
      final text = utf8.decode(bytes.sublist(at, end));
      if (type != 'r') {
        parts.add({'h', 'g', 'x', 'k'}.contains(type)
            ? dictionaryPlainText(text)
            : text);
      }
    }
    at = end + (!last && !binary ? 1 : 0);
    field++;
  }
  if (sequence != null && field != sequence.length) {
    throw const DictionaryFailure('format');
  }
  return parts.join('\n').replaceAll('\u0000', '').trim();
}
