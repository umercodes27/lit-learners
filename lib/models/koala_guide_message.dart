enum KoalaGuideAudience {
  child,
  parent,
}

enum KoalaGuideMood {
  neutral,
  encouraging,
  celebrating,
  thinking,
  parent,
}

enum KoalaGuideTrigger {
  dashboardWelcome,
  moduleIntro,
  activityStart,
  activityComplete,
  quizStart,
  quizRetry,
  levelComplete,
  lockedLevel,
  parentReport,
  reminderSetup,
  adminContent,
  authWelcome,
  profileSelection,
  parentalLock,
}

class KoalaGuideMessage {
  const KoalaGuideMessage({
    required this.id,
    required this.message,
    required this.trigger,
    required this.audience,
    this.parentTip,
    this.audioCueKey,
    this.moduleId,
    this.levelId,
    this.minStage,
    this.maxStage,
    this.mood = KoalaGuideMood.neutral,
    this.priority = 0,
  });

  final String id;
  final String message;
  final String? parentTip;
  final String? audioCueKey;
  final String? moduleId;
  final String? levelId;
  final int? minStage;
  final int? maxStage;
  final KoalaGuideTrigger trigger;
  final KoalaGuideAudience audience;
  final KoalaGuideMood mood;
  final int priority;

  bool matches(KoalaGuideRequest request) {
    if (trigger != request.trigger || audience != request.audience) {
      return false;
    }

    if (moduleId != null && moduleId != request.moduleId) {
      return false;
    }

    if (levelId != null && levelId != request.levelId) {
      return false;
    }

    if ((minStage != null || maxStage != null) && request.stage == null) {
      return false;
    }

    final stage = request.stage;
    if (stage != null && minStage != null && stage < minStage!) {
      return false;
    }
    if (stage != null && maxStage != null && stage > maxStage!) {
      return false;
    }

    return true;
  }

  int specificityFor(KoalaGuideRequest request) {
    var score = priority;
    if (levelId != null && levelId == request.levelId) score += 100;
    if (moduleId != null && moduleId == request.moduleId) score += 60;
    if (minStage != null || maxStage != null) score += 20;
    if (audioCueKey != null) score += 5;
    if (parentTip != null) score += 3;
    return score;
  }
}

class KoalaGuideRequest {
  const KoalaGuideRequest({
    required this.trigger,
    required this.audience,
    this.moduleId,
    this.levelId,
    this.stage,
    this.fallbackMessage,
    this.fallbackParentTip,
  });

  final KoalaGuideTrigger trigger;
  final KoalaGuideAudience audience;
  final String? moduleId;
  final String? levelId;
  final int? stage;
  final String? fallbackMessage;
  final String? fallbackParentTip;
}
