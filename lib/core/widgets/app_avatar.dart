import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.imageUrl,
    this.localBytes,
    this.size = 48,
    this.isLoading = false,
    this.semanticLabel = 'Avatar',
  });

  final String? imageUrl;
  final Uint8List? localBytes;
  final double size;
  final bool isLoading;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasLocal = localBytes != null && localBytes!.isNotEmpty;
    final hasUrl = imageUrl != null && imageUrl!.trim().isNotEmpty;

    ImageProvider? provider;
    if (hasLocal) {
      provider = MemoryImage(localBytes!);
    } else if (hasUrl) {
      provider = CachedNetworkImageProvider(imageUrl!.trim());
    }

    return Semantics(
      label: semanticLabel,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: size / 2,
            backgroundColor: scheme.secondary.withValues(alpha: 0.18),
            foregroundColor: scheme.onSurface,
            backgroundImage: provider,
            child: provider == null
                ? Icon(Icons.person_outline, size: size * 0.5)
                : null,
          ),
          if (isLoading)
            SizedBox(
              width: size,
              height: size,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
