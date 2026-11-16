import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:examprep/app.dart';
import 'package:examprep/features/auth/presentation/auth_controller.dart';
import 'package:examprep/features/auth/domain/user_model.dart';
import 'package:examprep/features/tests/presentation/test_list_screen.dart';
import 'package:examprep/features/tests/data/test_repository.dart';
import 'package:examprep/features/tests/domain/test_model.dart';

class MockAuthController extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthController {
  MockAuthController() : super(const AsyncValue.data(null));

  @override
  Future<void> signInWithEmail(String email, String password) async {}

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    required String targetExam,
  }) async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {}
}

class FakeTestRepository extends Fake implements TestRepository {
  @override
  Stream<List<TestModel>> streamLiveTests(String exam) {
    return Stream.value([
      TestModel(
        id: 'test_upsc_sample',
        title: 'Daily UPSC Mock Test',
        type: 'daily',
        exam: 'UPSC',
        subject: 'General Studies',
        questionCount: 20,
        questionIds: ['q1', 'q2'],
        publishDate: '2026-11-14',
      ),
    ]);
  }
}

void main() {
  testWidgets('ExamPrepApp compiles and mounts properly with auth override', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
          userProfileProvider.overrideWith((ref) => Stream.value(null)),
          authControllerProvider.overrideWith(
            (ref) => MockAuthController(),
          ),
          testRepoProvider.overrideWithValue(FakeTestRepository()),
        ],
        child: const ExamPrepApp(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('ExamPrep'), findsWidgets);
    expect(find.text('UPSC & TNPSC Timed Practice Engine'), findsOneWidget);
  });
}
