import 'package:flutter/material.dart';
import 'package:lyrical/core/constants/app_strings.dart';
import 'package:lyrical/core/widgets/temporary_section_screen.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TemporarySectionScreen(
      title: AppStrings.searchTitle,
      description: AppStrings.searchDescription,
    );
  }
}
