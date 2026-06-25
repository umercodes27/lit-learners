import 'dart:async';

import 'package:flutter/foundation.dart';

import '../repositories/parental_lock_repository.dart';

class ParentalLockViewModel extends ChangeNotifier {
  ParentalLockViewModel(this._lockRepository);

  final ParentalLockRepository _lockRepository;

  LockChallenge? _challenge;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;
  String? _errorMessage;
  Timer? _cooldownTimer;

  LockChallenge? get challenge => _challenge;
  int get failedAttempts => _failedAttempts;
  DateTime? get lockedUntil => _lockedUntil;
  String? get errorMessage => _errorMessage;
  bool get isLocked {
    final lockedUntil = _lockedUntil;
    if (lockedUntil == null) return false;
    return DateTime.now().isBefore(lockedUntil);
  }

  Future<void> loadChallenge() async {
    _challenge = await _lockRepository.createChallenge();
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> verify(String answer) async {
    final challenge = _challenge;
    if (challenge == null) return false;

    if (isLocked) {
      _errorMessage = 'Please wait before trying again.';
      notifyListeners();
      return false;
    }

    final passed = await _lockRepository.verifyAnswer(
      challenge: challenge,
      answer: answer,
    );
    if (passed) {
      _failedAttempts = 0;
      _lockedUntil = null;
      _errorMessage = null;
      notifyListeners();
      return true;
    }

    _failedAttempts += 1;
    if (_failedAttempts >= 3) {
      final lockedUntil = DateTime.now().add(const Duration(seconds: 30));
      _lockedUntil = lockedUntil;
      _failedAttempts = 0;
      _errorMessage = 'Too many tries. Try again in 30 seconds.';
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer(const Duration(seconds: 30), () {
        if (_lockedUntil == lockedUntil) {
          _errorMessage = null;
          notifyListeners();
        }
      });
    } else {
      _errorMessage = 'That answer is not correct.';
    }
    _challenge = await _lockRepository.createChallenge();
    notifyListeners();
    return false;
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }
}
