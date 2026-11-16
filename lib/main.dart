import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

const String supabaseUrl = 'https://jkbndifpcepnsjgmyrfr.supabase.co';
const String supabaseAnonKey = 'sb_publishable_tjoAjn0nSkhIIXYrRpB7Lw_8YPdMPxi';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase initialize error: $e');
  }

  runApp(
    const ProviderScope(
      child: ExamPrepApp(),
    ),
  );
}
