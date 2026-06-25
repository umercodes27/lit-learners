import 'package:flutter/foundation.dart';

import '../models/parent_report.dart';
import '../repositories/parent_report_repository.dart';

class ParentReportViewModel extends ChangeNotifier {
  ParentReportViewModel(this._reportRepository);

  final ParentReportRepository _reportRepository;

  ParentReport? _report;
  bool _isLoading = false;
  String? _errorMessage;

  ParentReport? get report => _report;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadReport(String parentId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _report = await _reportRepository.getReport(parentId);
    } catch (error) {
      _errorMessage = 'Reports could not load. Please try again.';
    }

    _isLoading = false;
    notifyListeners();
  }
}
