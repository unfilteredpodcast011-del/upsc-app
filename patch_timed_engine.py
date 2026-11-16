import os

file_path = r"c:\Users\manoj\OneDrive\Documents\pgi\upsc\examprep\lib\features\tests\presentation\timed_engine_screen.dart"

with open(file_path, "r", encoding="utf-8") as f:
    text = f.read()

# 1. Add locale_controller.dart import if not present
locale_import = "import '../../../core/localization/locale_controller.dart';\n"
if locale_import not in text:
    text = locale_import + text

# 2. Fix session restart / timer bug so fresh unlock never says "time is up"
old_init = """      final now = DateTime.now();
      final elapsed = now.difference(session.startedAt).inSeconds;
      _totalDurationSeconds = session.allowedDurationSeconds;
      _secondsRemaining = _totalDurationSeconds - (elapsed > 0 ? elapsed : 0);

      if (_secondsRemaining <= 0) {
        _autoSubmit();
        return;
      }"""

new_init = """      final now = DateTime.now();
      final elapsed = now.difference(session.startedAt).inSeconds;
      _totalDurationSeconds = session.allowedDurationSeconds;

      // Ensure that if previous test attempt was finished or stale, we reset the timer fresh for this new unlock
      if (elapsed >= _totalDurationSeconds || elapsed < 0) {
        _secondsRemaining = _totalDurationSeconds;
      } else {
        _secondsRemaining = _totalDurationSeconds - elapsed;
      }

      if (_secondsRemaining <= 0) {
        _secondsRemaining = _totalDurationSeconds;
      }"""

text = text.replace(old_init, new_init)

# 3. Synchronize active language in real time
old_build_top = """  Widget build(BuildContext context) {
    if (_isLoading) {"""

new_build_top = """  Widget build(BuildContext context) {
    // Keep language in sync with app-wide selected locale
    final activeLocale = ref.watch(localeProvider).languageCode;
    _currentLanguage = activeLocale;

    if (_isLoading) {"""

text = text.replace(old_build_top, new_build_top)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(text)

print("SUCCESS: timed_engine_screen.dart updated with timer reset fix and dynamic language synchronization!")

