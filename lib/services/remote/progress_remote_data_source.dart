import '../../models/progress.dart';

abstract class ProgressRemoteDataSource {
  Future<List<LevelProgress>> getProgressForChild(String childId);

  Future<void> upsertProgress(LevelProgress progress);
}

class InMemoryProgressRemoteDataSource implements ProgressRemoteDataSource {
  final Map<String, LevelProgress> _progressByKey = {};

  List<LevelProgress> get progress => List.unmodifiable(_progressByKey.values);

  @override
  Future<List<LevelProgress>> getProgressForChild(String childId) async {
    return _progressByKey.values
        .where((progress) => progress.childId == childId)
        .map((progress) => progress.copyWith(isSynced: true))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<void> upsertProgress(LevelProgress progress) async {
    _progressByKey[_key(progress.childId, progress.levelId)] =
        progress.copyWith(isSynced: true);
  }

  String _key(String childId, String levelId) => '$childId::$levelId';
}
