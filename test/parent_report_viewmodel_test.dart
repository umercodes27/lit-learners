import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/parent_report.dart';
import 'package:little_learners/repositories/parent_report_repository.dart';
import 'package:little_learners/viewmodels/parent_report_viewmodel.dart';

void main() {
  test('ParentReportViewModel loads parent report data', () async {
    final expectedReport = ParentReport(
      parentId: 'parent-1',
      childReports: const [],
      generatedAt: DateTime.utc(2026),
    );
    final viewModel = ParentReportViewModel(
      _FakeParentReportRepository(expectedReport),
    );

    await viewModel.loadReport('parent-1');

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.errorMessage, isNull);
    expect(viewModel.report, expectedReport);
  });
}

class _FakeParentReportRepository implements ParentReportRepository {
  const _FakeParentReportRepository(this._report);

  final ParentReport _report;

  @override
  Future<ParentReport> getReport(String parentId) async {
    return _report;
  }
}
