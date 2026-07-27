import 'package:flutter/material.dart';
import 'package:lyrical/core/constants/app_strings.dart';
import 'package:lyrical/core/widgets/temporary_section_screen.dart';

class PublishScreen extends StatelessWidget {
  const PublishScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TemporarySectionScreen(
      title: AppStrings.publishTitle,
      description: AppStrings.publishDescription,
    );
  }
}
