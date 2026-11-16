import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'app.dart';

const String supabaseUrl = 'https://jkbndifpcepnsjgmyrfr.supabase.co';
const String supabaseAnonKey = 'sb_publishable_tjoAjn0nSkhIIXYrRpB7Lw_8YPdMPxi';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (safely catch to avoid red crash screen)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init note: $e');
  }

  // Initialize Supabase
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase init note: $e');
  }

  runApp(
    const ProviderScope(
      child: ExamPrepApp(),
    ),
  );
}
