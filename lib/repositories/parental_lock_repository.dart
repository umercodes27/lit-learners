import 'dart:math';

class LockChallenge {
  const LockChallenge({
    required this.prompt,
    required this.answer,
  });

  final String prompt;
  final int answer;
}

abstract class ParentalLockRepository {
  Future<LockChallenge> createChallenge();
  Future<bool> verifyAnswer({
    required LockChallenge challenge,
    required String answer,
  });
}

class InMemoryParentalLockRepository implements ParentalLockRepository {
  final Random _random = Random(7);

  @override
  Future<LockChallenge> createChallenge() async {
    final left = _random.nextInt(6) + 2;
    final right = _random.nextInt(5) + 1;
    return LockChallenge(
      prompt: '$left + $right = ?',
      answer: left + right,
    );
  }

  @override
  Future<bool> verifyAnswer({
    required LockChallenge challenge,
    required String answer,
  }) async {
    return int.tryParse(answer.trim()) == challenge.answer;
  }
}
