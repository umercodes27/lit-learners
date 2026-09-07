import 'package:flutter/foundation.dart';

import '../core/utils/age_stage_helper.dart';
import '../models/learning_level.dart';
import '../models/learning_module.dart';
import '../models/parent_report.dart';
import '../repositories/content_repository.dart';
import '../repositories/parent_report_repository.dart';
import '../services/ai/llm_client.dart';
import '../services/content/activity_pack_loader.dart';
import '../services/content/activity_pack_stops.dart';
import '../services/content/module_activity_bridge.dart';
import '../services/insights/child_insights.dart';
import '../services/insights/child_insights_builder.dart';
import '../services/insights/progress_summary_service.dart';
import '../services/insights/progress_summary_store.dart';

class ParentReportViewModel extends ChangeNotifier {
  ParentReportViewModel(
    this._reportRepository, {
    ContentRepository? contentRepository,
    ProgressSummaryService? summaryService,
    ChildInsightsBuilder insightsBuilder = const ChildInsightsBuilder(),
  })  : _contentRepository = contentRepository,
        _summaryService = summaryService,
        _insightsBuilder = insightsBuilder;

  final ParentReportRepository _reportRepository;

  /// Both optional: the report still loads and renders its numbers without
  /// them. Insights need the curriculum to measure against, and summaries
  /// need a model — neither should be able to stop a parent seeing progress.
  final ContentRepository? _contentRepository;
  final ProgressSummaryService? _summaryService;
  final ChildInsightsBuilder _insightsBuilder;

  ParentReport? _report;
  bool _isLoading = false;
  String? _errorMessage;

  final Map<String, ChildInsights> _insights = {};
  final Map<String, ProgressSummary> _summaries = {};
  final Set<String> _generating = {};
  final Map<String, String> _summaryErrors = {};

  ParentReport? get report => _report;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ChildInsights? insightsFor(String childId) => _insights[childId];
  ProgressSummary? summaryFor(String childId) => _summaries[childId];
  bool isGeneratingFor(String childId) => _generating.contains(childId);
  String? summaryErrorFor(String childId) => _summaryErrors[childId];

  bool get canSummarise => _summaryService != null;

  Future<void> loadReport(String parentId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _report = await _reportRepository.getReport(parentId);
      await _buildInsights();
    } catch (error) {
      _errorMessage = 'Reports could not load. Please try again.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _buildInsights() async {
    final content = _contentRepository;
    final report = _report;
    if (content == null || report == null) return;

    _insights.clear();
    for (final child in report.childReports) {
      // Each child is measured against their own stage, so a younger sibling
      // is never shown as behind an older one.
      final stage = AgeStageHelper.stageForAge(child.profile.age);
      final modules = await content.getModulesForStage(stage);

      final levels = <LearningLevel>[];
      for (final module in modules) {
        levels.addAll(
          await content.getLevelsForModule(moduleId: module.id, stage: stage),
        );
      }
      levels.addAll(await _packLevels(
        modules: modules,
        age: child.profile.age,
        stage: stage,
      ));

      _insights[child.profile.id] = _insightsBuilder.build(
        report: child,
        modules: modules,
        levels: levels,
      );
    }

    await _loadCachedSummaries();
  }

  /// The age-pack levels this child plays, drawn the same way the level map
  /// draws them.
  ///
  /// The packs are a second content system: JSON bundled with the app rather
  /// than rows in the module tree. Finishing one still writes an ordinary
  /// progress row, keyed by the drawn level's id — so without this the report
  /// held real progress it could not attribute to anything, and a subject the
  /// child had been playing all week was reported as never started.
  ///
  /// A pack that will not load costs nothing here. The report is built from
  /// the seeded ladder either way, and a parent seeing slightly less is a far
  /// better failure than a parent seeing an error.
  Future<List<LearningLevel>> _packLevels({
    required List<LearningModule> modules,
    required int age,
    required int stage,
  }) async {
    final result = await ActivityPackLoader.forPath(
      ModuleActivityBridge.packPathFor(age),
    ).load(path: ModuleActivityBridge.packPathFor(age));

    final pack = result.pack;
    if (pack == null) return const [];

    final levels = <LearningLevel>[];
    for (final module in modules) {
      final key = ModuleActivityBridge.packModuleKeyFor(module.id);
      if (key == null) continue;

      final packModule = pack.moduleByKey(key);
      if (packModule == null) continue;

      levels.addAll(ActivityPackStops.levelsFor(
        packModule,
        moduleId: module.id,
        stage: stage,
      ));
    }
    return levels;
  }

  /// Only summaries that are still true of the child are restored. One
  /// written before three more lessons were finished would read as current
  /// and be wrong.
  Future<void> _loadCachedSummaries() async {
    final service = _summaryService;
    if (service == null) return;

    _summaries.clear();
    for (final entry in _insights.entries) {
      final cached = await service.cachedFor(entry.value);
      if (cached != null) _summaries[entry.key] = cached;
    }
  }

  /// Writes, or rewrites, one child's summary. Costs a model call, so it is
  /// always something a parent asked for rather than something that happens
  /// on opening the screen.
  Future<void> generateSummary(String childId) async {
    final service = _summaryService;
    final insights = _insights[childId];
    if (service == null || insights == null) return;
    if (_generating.contains(childId)) return;

    _generating.add(childId);
    _summaryErrors.remove(childId);
    notifyListeners();

    try {
      _summaries[childId] = await service.generate(insights);
    } on LlmException catch (error) {
      _summaryErrors[childId] = error.message;
    } catch (_) {
      _summaryErrors[childId] = 'The summary could not be written.';
    }

    _generating.remove(childId);
    notifyListeners();
  }

  void clearSummaryError(String childId) {
    if (_summaryErrors.remove(childId) != null) notifyListeners();
  }
}
