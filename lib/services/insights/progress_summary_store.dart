import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../local/db_helper.dart';
import '../local/db_schema.dart';

/// A written-out summary of one child's progress, and the state of that
/// child's progress when it was written.
class ProgressSummary {
  const ProgressSummary({
    required this.childId,
    required this.fingerprint,
    required this.summary,
    required this.suggestions,
    required this.generatedAt,
  });

  final String childId;

  /// What the progress looked like when this was written. A summary whose
  /// fingerprint no longer matches is out of date and must not be shown as
  /// though it were current.
  final String fingerprint;

  final String summary;
  final List<String> suggestions;
  final DateTime generatedAt;

  bool matches(String currentFingerprint) => fingerprint == currentFingerprint;

  Map<String, Object?> toMap() => {
        'childId': childId,
        'fingerprint': fingerprint,
        'summary': summary,
        'suggestions': suggestions,
        'generatedAt': generatedAt.toIso8601String(),
      };

  static ProgressSummary? fromMap(Map<String, Object?> map) {
    final childId = map['childId'];
    final fingerprint = map['fingerprint'];
    final summary = map['summary'];
    if (childId is! String || fingerprint is! String || summary is! String) {
      return null;
    }
    return ProgressSummary(
      childId: childId,
      fingerprint: fingerprint,
      summary: summary,
      suggestions: [
        for (final item in (map['suggestions'] as List? ?? const []))
          if (item is String) item,
      ],
      generatedAt:
          DateTime.tryParse(map['generatedAt'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

abstract class ProgressSummaryStore {
  Future<ProgressSummary?> read(String childId);
  Future<void> write(ProgressSummary summary);
  Future<void> clear(String childId);
}

class InMemoryProgressSummaryStore implements ProgressSummaryStore {
  final Map<String, ProgressSummary> _summaries = {};

  @override
  Future<ProgressSummary?> read(String childId) async => _summaries[childId];

  @override
  Future<void> write(ProgressSummary summary) async {
    _summaries[summary.childId] = summary;
  }

  @override
  Future<void> clear(String childId) async {
    _summaries.remove(childId);
  }
}

/// Keeps each child's last summary in the `appMeta` table.
///
/// Cached because generating one costs money and takes seconds, and a parent
/// opening the report three times in an evening has not changed anything
/// about their child in between.
///
/// Every failure here is swallowed. A cache that cannot be read is a summary
/// that gets written again; a cache that cannot be written is a summary that
/// gets written again next time. Neither is worth an error in front of a
/// parent looking at their child's progress.
class LocalProgressSummaryStore implements ProgressSummaryStore {
  LocalProgressSummaryStore({required LocalDbHelper dbHelper})
      : _dbHelper = dbHelper;

  final LocalDbHelper _dbHelper;

  String _keyFor(String childId) => 'aiProgressSummary:$childId';

  @override
  Future<ProgressSummary?> read(String childId) async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        LocalDbSchema.appMeta,
        where: 'metaKey = ?',
        whereArgs: [_keyFor(childId)],
        limit: 1,
      );
      if (rows.isEmpty) return null;

      final decoded = jsonDecode(rows.first['metaValue'] as String);
      if (decoded is! Map<String, Object?>) return null;
      return ProgressSummary.fromMap(decoded);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(ProgressSummary summary) async {
    try {
      final db = await _dbHelper.database;
      await db.insert(
        LocalDbSchema.appMeta,
        {
          'metaKey': _keyFor(summary.childId),
          'metaValue': jsonEncode(summary.toMap()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } on Object {
      // Losing the cache costs one more call, not a broken screen.
    }
  }

  @override
  Future<void> clear(String childId) async {
    try {
      final db = await _dbHelper.database;
      await db.delete(
        LocalDbSchema.appMeta,
        where: 'metaKey = ?',
        whereArgs: [_keyFor(childId)],
      );
    } on Object {
      // As above.
    }
  }
}
