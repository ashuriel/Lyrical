import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lyrical/app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase and dotenv initialization will be added in a later phase.
  runApp(const ProviderScope(child: LyricalApp()));
}
