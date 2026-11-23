import 'package:flutter/material.dart';

/// External image on a phone or desktop app. The network client is not subject
/// to browser CORS, so a public address loads directly.
Widget buildExternalNoteImage(String url) {
  return Image.network(
    url,
    fit: BoxFit.contain,
    loadingBuilder: (context, child, progress) {
      if (progress == null) return child;
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
    },
    errorBuilder: (context, error, stackTrace) => const MissingNoteImage(),
  );
}

class MissingNoteImage extends StatelessWidget {
  const MissingNoteImage({super.key});

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
