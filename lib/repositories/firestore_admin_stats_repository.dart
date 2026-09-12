import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/seed_content.dart';
import '../models/admin_stats.dart';
import 'admin_stats_repository.dart';

/// Firestore-backed system metrics for the admin portal.
///
/// Requires the admin read grants in `firestore.rules`; without them every
/// query here fails with permission-denied, because parents may otherwise only
/// read their own documents.
class FirestoreAdminStatsRepository implements AdminStatsRepository {
  /// [firestore] must be Firestore on the *admin* app — see
  /// [AdminFirebaseApp]. Required rather than defaulted, because the default
  /// instance runs as the parent and every query here would be denied.
  const FirestoreAdminStatsRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  static const parentsCollection = 'parents';
  static const childProfilesCollection = 'childProfiles';
  static const modulesCollection = 'learningModules';
  static const levelsCollection = 'learningLevels';
  static const levelProgressCollection = 'levelProgress';

  final FirebaseFirestore _firestore;

  @override
  Future<AdminStats> loadStats() async {
    final parentCount =
        await _countOf(_firestore.collection(parentsCollection));
    final childCount =
        await _countOf(_firestore.collectionGroup(childProfilesCollection));

    final moduleDocs = await _firestore.collection(modulesCollection).get();
    final levelDocs = await _firestore.collection(levelsCollection).get();
    final progressDocs =
        await _firestore.collectionGroup(levelProgressCollection).get();

    // The database holds only what admins wrote: new content, and edited
    // copies of built-in content. Counting it alone reported "1 module, 1
    // level" for an app that ships eight modules, so the totals are the
    // built-in curriculum with the database laid over it, id by id — the same
    // merge a child's device performs.
    final moduleTitles = <String, String>{
      for (final module in seedModules) module.id: module.title,
    };
    for (final doc in moduleDocs.docs) {
      final data = doc.data();
      moduleTitles[doc.id] = (data['title'] as String?) ?? doc.id;
    }

    // Quiz questions live as an array on each level document, so the total has
    // to be summed client-side rather than aggregated.
    final quizzesByLevel = <String, int>{
      for (final level in seedLevels) level.id: level.quizQuestions.length,
    };
    for (final doc in levelDocs.docs) {
      final questions = doc.data()['quizQuestions'];
      quizzesByLevel[doc.id] = questions is Iterable ? questions.length : 0;
    }
    final quizCount = quizzesByLevel.values.fold<int>(0, (a, b) => a + b);

    return AdminStats(
      totalParentAccounts: parentCount,
      totalChildProfiles: childCount,
      totalQuizzes: quizCount,
      totalModules: moduleTitles.length,
      totalLevels: quizzesByLevel.length,
      completedLevelCount: progressDocs.docs
          .where((doc) => doc.data()['completed'] == true)
          .length,
      moduleUsage: _moduleUsageFrom(
        progressDocs: progressDocs.docs,
        moduleTitles: moduleTitles,
      ),
    );
  }

  @override
  Future<List<AdminParentAccountSummary>> loadParentAccounts() async {
    final parentDocs = await _firestore.collection(parentsCollection).get();
    final childDocs =
        await _firestore.collectionGroup(childProfilesCollection).get();

    // One collection-group read beats an N+1 subcollection count per parent.
    final childCounts = <String, int>{};
    for (final doc in childDocs.docs) {
      final parentId = doc.reference.parent.parent?.id;
      if (parentId == null) continue;
      childCounts[parentId] = (childCounts[parentId] ?? 0) + 1;
    }

    final summaries = parentDocs.docs.map((doc) {
      final data = doc.data();
      return AdminParentAccountSummary(
        parentId: doc.id,
        email: (data['email'] as String?) ?? '(no email on record)',
        childProfileCount: childCounts[doc.id] ?? 0,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      );
    }).toList();

    summaries.sort((a, b) {
      final left = a.createdAt;
      final right = b.createdAt;
      if (left == null && right == null) return a.email.compareTo(b.email);
      if (left == null) return 1;
      if (right == null) return -1;
      return right.compareTo(left);
    });
    return summaries;
  }

  List<AdminModuleUsage> _moduleUsageFrom({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> progressDocs,
    required Map<String, String> moduleTitles,
  }) {
    final attempted = <String, int>{};
    final completed = <String, int>{};
    final learners = <String, Set<String>>{};

    for (final doc in progressDocs) {
      final data = doc.data();
      final moduleId = (data['moduleId'] as String?) ?? '';
      if (moduleId.isEmpty) continue;

      attempted[moduleId] = (attempted[moduleId] ?? 0) + 1;
      if (data['completed'] == true) {
        completed[moduleId] = (completed[moduleId] ?? 0) + 1;
      }

      final childId =
          (data['childId'] as String?) ?? doc.reference.parent.parent?.id;
      if (childId != null && childId.isNotEmpty) {
        learners.putIfAbsent(moduleId, () => <String>{}).add(childId);
      }
    }

    final usage = attempted.keys.map((moduleId) {
      return AdminModuleUsage(
        moduleId: moduleId,
        moduleTitle: moduleTitles[moduleId] ?? moduleId,
        attemptedLevelCount: attempted[moduleId] ?? 0,
        completedLevelCount: completed[moduleId] ?? 0,
        learnersEngaged: learners[moduleId]?.length ?? 0,
      );
    }).toList();

    usage.sort(
      (a, b) => b.attemptedLevelCount.compareTo(a.attemptedLevelCount),
    );
    return usage;
  }

  Future<int> _countOf(Query<Map<String, dynamic>> query) async {
    final snapshot = await query.count().get();
    return snapshot.count ?? 0;
  }
}
