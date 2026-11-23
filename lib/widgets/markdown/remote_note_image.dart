import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:modu_reader/service/remote_library/note_images.dart';
import 'package:modu_reader/service/remote_library/webdav_library.dart';

import 'remote_note_image_view.dart'
    if (dart.library.html) 'remote_note_image_view_web.dart';

/// A picture inside a remote note.
///
/// A file on the same WebDAV server is downloaded with the signed-in account,
/// which is what a phone needs for images stored next to the note. Any other
/// http(s) address is loaded directly.
class RemoteNoteImage extends StatefulWidget {
  const RemoteNoteImage({
    super.key,
    required this.url,
    required this.noteUri,
    required this.library,
  });

  final String url;
  final Uri noteUri;
  final WebdavLibrary library;

  @override
  State<RemoteNoteImage> createState() => _RemoteNoteImageState();
}

class _RemoteNoteImageState extends State<RemoteNoteImage> {
  final CancelToken _cancel = CancelToken();
  Uint8List? _bytes;
  String? _external;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final inline = _decodeDataImage(widget.url);
    if (inline != null) {
      _bytes = inline;
      return;
    }
    final resolved = resolveNoteImage(widget.noteUri, widget.url);
    if (resolved == null) {
      _failed = true;
      return;
    }
    final target = resolved.removeFragment();
    if (widget.library.contains(target)) {
      _loadLibrary(target);
      return;
    }
    _external = target.toString();
  }

  Future<void> _loadLibrary(Uri uri) async {
    try {
      final bytes = await widget.library.readUri(uri, _cancel);
      if (!mounted || _cancel.isCancelled) return;
      setState(() => _bytes = bytes);
    } catch (_) {
      if (!mounted || _cancel.isCancelled) return;
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    if (!_cancel.isCancelled) _cancel.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const MissingNoteImage();
    final bytes = _bytes;
    if (bytes != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => const MissingNoteImage(),
        ),
      );
    }
    final external = _external;
    if (external != null) return buildExternalNoteImage(external);
    return const SizedBox(
      height: 72,
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

Uint8List? _decodeDataImage(String url) {
  if (!url.startsWith('data:image/')) return null;
  final comma = url.indexOf(',');
  if (comma < 0) return null;
  final meta = url.substring(0, comma);
  final payload = url.substring(comma + 1);
  if (payload.length > WebdavLibrary.maxInlineBytes) return null;
  try {
    if (meta.contains(';base64')) return base64Decode(payload);
    return Uint8List.fromList(utf8.encode(Uri.decodeComponent(payload)));
  } catch (_) {
    return null;
  }
}
