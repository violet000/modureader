import 'dart:js_interop';

import 'package:flutter/material.dart';

/// External image in a browser, including a phone browser.
///
/// An HTML image can paint a cross-origin picture. [Image.network] fetches
/// through XHR and the picture stays blank when the host does not send CORS
/// headers.
Widget buildExternalNoteImage(String url) => _WebNoteImage(url: url);

class _WebNoteImage extends StatefulWidget {
  const _WebNoteImage({required this.url});

  final String url;

  @override
  State<_WebNoteImage> createState() => _WebNoteImageState();
}

class _WebNoteImageState extends State<_WebNoteImage> {
  double? _ratio;
  bool _failed = false;
  bool _attached = false;

  void _onCreated(Object element) {
    if (_attached) return;
    _attached = true;
    final image = _DomImage(element as JSObject);
    image.alt = '';
    image.style.width = '100%';
    image.style.height = '100%';
    image.style.objectFit = 'contain';
    image.addEventListener(
      'load',
      ((JSObject _) {
        final width = image.naturalWidth;
        final height = image.naturalHeight;
        if (!mounted || width <= 0 || height <= 0) return;
        setState(() => _ratio = width / height);
      }).toJS,
    );
    image.addEventListener(
      'error',
      ((JSObject _) {
        if (!mounted) return;
        setState(() => _failed = true);
      }).toJS,
    );
    image.src = widget.url;
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const _MissingNoteImage();
    final ratio = _ratio;
    final height = ratio == null
        ? 160.0
        : (MediaQuery.sizeOf(context).width / ratio).clamp(48.0, 720.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: HtmlElementView.fromTagName(
          key: ValueKey(widget.url),
          tagName: 'img',
          onElementCreated: _onCreated,
        ),
      ),
    );
  }
}

extension type _DomImage(JSObject _) implements JSObject {
  external set src(String value);
  external set alt(String value);
  external _DomStyle get style;
  external int get naturalWidth;
  external int get naturalHeight;
  external void addEventListener(String type, JSFunction listener);
}

extension type _DomStyle(JSObject _) implements JSObject {
  external set width(String value);
  external set height(String value);
  external set objectFit(String value);
}

class MissingNoteImage extends StatelessWidget {
  const MissingNoteImage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MissingNoteImage();
  }
}

class _MissingNoteImage extends StatelessWidget {
  const _MissingNoteImage();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Icon(
        Icons.broken_image_outlined,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}
