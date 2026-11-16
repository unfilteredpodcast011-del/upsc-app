import 'package:cloud_firestore/cloud_firestore.dart';
import '../../tests/domain/question_model.dart';
import '../../tests/domain/test_model.dart';
import '../domain/admin_stats_model.dart';

class AdminRepository {
  final FirebaseFirestore _firestore;

  AdminRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Batch upload questions to Firestore
  Future<int> batchUploadQuestions(List<QuestionModel> questions) async {
    int count = 0;
    // Firestore batch limit is 500 operations
    const batchSize = 400;
    for (int i = 0; i < questions.length; i += batchSize) {
      final batch = _firestore.batch();
      final chunk = questions.sublist(
        i,
        i + batchSize > questions.length ? questions.length : i + batchSize,
      );

      for (final q in chunk) {
        final ref = _firestore.collection('questions').doc(q.id);
        batch.set(ref, q.toMap(), SetOptions(merge: true));
        count++;
      }
      await batch.commit();
    }
    return count;
  }

  /// Rollback/Delete an entire batch of uploaded questions
  Future<int> rollbackBatch(String batchId) async {
    final query = await _firestore
        .collection('questions')
        .where('uploadBatchId', isEqualTo: batchId)
        .get();

    int deleted = 0;
    final batch = _firestore.batch();
    for (final doc in query.docs) {
      batch.delete(doc.reference);
      deleted++;
    }
    await batch.commit();
    return deleted;
  }

  /// Add or update a single question
  Future<void> saveSingleQuestion(QuestionModel question) async {
    await _firestore
        .collection('questions')
        .doc(question.id)
        .set(question.toMap(), SetOptions(merge: true));
  }

  /// Delete a single question
  Future<void> deleteQuestion(String questionId) async {
    await _firestore.collection('questions').doc(questionId).delete();
  }

  /// Stream of all questions for admin table/list
  Stream<List<QuestionModel>> streamAllQuestions({String? examFilter}) {
    Query query = _firestore.collection('questions').orderBy('uploadedAt', descending: true);
    if (examFilter != null && examFilter != 'ALL') {
      query = query.where('exam', isEqualTo: examFilter);
    }
    return query.limit(100).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return QuestionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// Fetch dashboard metrics (questions, users, payments, attempts)
  Future<AdminStatsModel> getAdminStats() async {
    try {
      final questionsSnap = await _firestore.collection('questions').count().get();
      final usersSnap = await _firestore.collection('users').count().get();
      final paymentsSnap = await _firestore.collection('payments').where('status', isEqualTo: 'captured').get();
      final attemptsSnap = await _firestore.collection('test_sessions').count().get();

      double totalRevenueRs = 0.0;
      for (final doc in paymentsSnap.docs) {
        final amountPaise = (doc.data()['amountPaise'] as num?)?.toInt() ?? 100;
        totalRevenueRs += amountPaise / 100.0;
      }

      // Group questions by subject
      final allQuestions = await _firestore.collection('questions').limit(500).get();
      final subjectMap = <String, int>{};
      for (final doc in allQuestions.docs) {
        final subj = doc.data()['subject']?.toString() ?? 'General';
        subjectMap[subj] = (subjectMap[subj] ?? 0) + 1;
      }

      return AdminStatsModel(
        totalQuestions: questionsSnap.count ?? 0,
        totalUsers: usersSnap.count ?? 0,
        totalPayments: paymentsSnap.docs.length,
        totalRevenueRs: totalRevenueRs,
        totalAttempts: attemptsSnap.count ?? 0,
        subjectCounts: subjectMap,
      );
    } catch (e) {
      return AdminStatsModel.empty();
    }
  }

  /// Build Daily Test immediately for today if admin clicks "Publish Today's Test"
  Future<TestModel> buildDailyTestForToday(String exam) async {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final questionsSnap = await _firestore
        .collection('questions')
        .where('exam', isEqualTo: exam)
        .where('publishDate', isEqualTo: todayStr)
        .where('status', isEqualTo: 'published')
        .limit(20)
        .get();

    List<String> qIds = questionsSnap.docs.map((d) => d.id).toList();

    // If fewer than 10 scheduled for today, fallback to recent published questions
    if (qIds.length < 5) {
      final recent = await _firestore
          .collection('questions')
          .where('exam', isEqualTo: exam)
          .where('status', isEqualTo: 'published')
          .limit(15)
          .get();
      qIds = recent.docs.map((d) => d.id).toList();
    }

    final testId = 'daily_${exam.toLowerCase()}_${todayStr.replaceAll('-', '')}';
    final dailyTest = TestModel(
      id: testId,
      title: 'Daily $exam Practice - $todayStr',
      type: 'daily',
      exam: exam,
      subject: 'Daily Mock',
      questionCount: qIds.length,
      questionIds: qIds,
      defaultDurationSeconds: qIds.length * 60, // 1 min per question
      priceInPaise: 100, // Rs. 1
      publishDate: todayStr,
      isLive: true,
    );

    await _firestore
        .collection('tests')
        .doc(testId)
        .set(dailyTest.toMap(), SetOptions(merge: true));

    return dailyTest;
  }
}

