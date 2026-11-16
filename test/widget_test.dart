import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:examprep/app.dart';
import 'package:examprep/core/router/app_router.dart';
import 'package:examprep/features/tests/presentation/test_list_screen.dart';
import 'package:examprep/features/tests/data/test_repository.dart';
import 'package:examprep/features/tests/domain/test_model.dart';
import 'package:examprep/features/tests/domain/question_model.dart';

class MockTestRepository extends Fake implements TestRepository {
  @override
  Stream<List<TestModel>> streamLiveTests(String exam) => Stream.value([]);

  @override
  Future<TestModel?> getTestById(String testId) async => null;

  @override
  Future<List<QuestionModel>> getQuestionsForTest(List<String> questionIds) async => [];

  @override
  Future<bool> isTestUnlocked({required String userId, required String testId}) async => true;

  @override
  Future<List<Map<String, dynamic>>> getWritingSubmissions(String userId) async => [];
}

void main() {
  testWidgets('ExamPrepApp compiles and mounts properly with Onboarding Screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingCheckProvider.overrideWith((ref) => false),
          testRepoProvider.overrideWithValue(MockTestRepository()),
        ],
        child: const ExamPrepApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Student Profile Registration'), findsOneWidget);
    expect(find.text('Welcome to ExamPrep!'), findsOneWidget);
    expect(find.text('Which Exam are you preparing for? *'), findsOneWidget);
  });
}
