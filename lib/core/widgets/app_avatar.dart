import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.imageUrl,
    this.size = 48,
    this.semanticLabel = 'Avatar',
  });

  final String? imageUrl;
  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasUrl = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return Semantics(
      label: semanticLabel,
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: scheme.secondary.withValues(alpha: 0.18),
        foregroundColor: scheme.onSurface,
        backgroundImage: hasUrl
            ? CachedNetworkImageProvider(imageUrl!.trim())
            : null,
        child: hasUrl ? null : Icon(Icons.person_outline, size: size * 0.5),
      ),
    );
  }
}
