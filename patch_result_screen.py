import os

file_path = r"c:\Users\manoj\OneDrive\Documents\pgi\upsc\examprep\lib\features\tests\presentation\result_screen.dart"

with open(file_path, "r", encoding="utf-8") as f:
    text = f.read()

# 1. Update questions restoration from cache to preserve all translations or map into current language
old_q_mapping = """        if (cachedQuestions != null) {
          final List<dynamic> qList = jsonDecode(cachedQuestions);
          questions = qList.map((m) {
            final opts = (m['options'] as Map<String, dynamic>?)?.map(
                  (k, v) => MapEntry(k, v.toString()),
                ) ??
                {};
            return QuestionModel(
              id: m['id'] ?? '',
              exam: m['exam'] ?? 'UPSC',
              subject: m['subject'] ?? 'General Studies',
              topic: m['topic'] ?? '',
              ncertChapter: '',
              difficulty: 'medium',
              publishDate: '2026-11-16',
              correctAnswer: m['correct_answer'] ?? 'A',
              normalizedText: m['question'] ?? '',
              translations: {
                'en': QuestionTranslation(
                  question: m['question'] ?? '',
                  options: opts,
                  explanation: m['explanation'] ?? '',
                ),
              },
            );
          }).toList();
        }"""

new_q_mapping = """        if (cachedQuestions != null) {
          final List<dynamic> qList = jsonDecode(cachedQuestions);
          questions = qList.map((m) {
            final opts = (m['options'] as Map<String, dynamic>?)?.map(
                  (k, v) => MapEntry(k, v.toString()),
                ) ??
                {};
            final qText = m['question'] ?? '';
            final exp = m['explanation'] ?? '';
            return QuestionModel(
              id: m['id'] ?? '',
              exam: m['exam'] ?? 'UPSC',
              subject: m['subject'] ?? 'General Studies',
              topic: m['topic'] ?? '',
              ncertChapter: '',
              difficulty: 'medium',
              publishDate: '2026-11-16',
              correctAnswer: m['correct_answer'] ?? 'A',
              normalizedText: qText,
              translations: {
                'en': QuestionTranslation(question: qText, options: opts, explanation: exp),
                'ta': QuestionTranslation(question: qText, options: opts, explanation: exp),
                'hi': QuestionTranslation(question: qText, options: opts, explanation: exp),
              },
            );
          }).toList();
        }"""

text = text.replace(old_q_mapping, new_q_mapping)

# 2. Replace hardcoded 'en' in options and question rendering with _appLanguage
text = text.replace("final options = q.getLocalizedOptions('en');", "final options = q.getLocalizedOptions(_appLanguage);")
text = text.replace("q.getLocalizedQuestion('en')", "q.getLocalizedQuestion(_appLanguage)")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(text)

print("SUCCESS: result_screen.dart patched to render in student's preferred language!")

