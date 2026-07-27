import 'package:flutter/material.dart';
import 'package:lyrical/core/constants/app_strings.dart';
import 'package:lyrical/core/widgets/temporary_section_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TemporarySectionScreen(
      title: AppStrings.profileTitle,
      description: AppStrings.profileDescription,
    );
  }
}
