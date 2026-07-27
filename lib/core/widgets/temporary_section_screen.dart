import 'package:flutter/material.dart';

/// Simple temporary screen used while feature UIs are not built yet.
class TemporarySectionScreen extends StatelessWidget {
  const TemporarySectionScreen({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(description, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}
