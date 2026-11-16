import 'dart:convert';
import 'package:flutter/services.dart';

class DailyQuote {
  final int day;
  final String quote;
  final String author;

  const DailyQuote({
    required this.day,
    required this.quote,
    required this.author,
  });

  factory DailyQuote.fromJson(Map<String, dynamic> json) {
    return DailyQuote(
      day: json['day'] as int? ?? 1,
      quote: json['quote'] as String? ?? 'Believe in yourself and all that you are.',
      author: json['author'] as String? ?? 'APJ Abdul Kalam',
    );
  }
}

class QuoteService {
  static List<DailyQuote>? _cachedQuotes;

  static Future<List<DailyQuote>> loadQuotes() async {
    if (_cachedQuotes != null && _cachedQuotes!.isNotEmpty) {
      return _cachedQuotes!;
    }
    try {
      final jsonString = await rootBundle.loadString('assets/data/daily_quotes.json');
      final List<dynamic> list = json.decode(jsonString);
      _cachedQuotes = list.map((e) => DailyQuote.fromJson(e as Map<String, dynamic>)).toList();
      return _cachedQuotes!;
    } catch (e) {
      // Fallback inspirational quote
      return [
        const DailyQuote(
          day: 1,
          quote: 'Arise, awake, and stop not until the goal is reached.',
          author: 'Swami Vivekananda',
        ),
      ];
    }
  }

  static Future<DailyQuote> getTodayQuote() async {
    final quotes = await loadQuotes();
    if (quotes.isEmpty) {
      return const DailyQuote(
        day: 1,
        quote: 'Difficulties in your life do not come to destroy you, but to help you realise your hidden potential.',
        author: 'Dr. A.P.J. Abdul Kalam',
      );
    }
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final dayOfYear = now.difference(startOfYear).inDays;
    final index = dayOfYear % quotes.length;
    return quotes[index];
  }
}

