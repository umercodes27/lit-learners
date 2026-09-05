import 'package:flutter/material.dart';

import '../../models/canvas_work.dart';
import '../../models/learning_level.dart';
import '../../models/parent_mark.dart';
import '../../models/video_lesson.dart';
import '../../views/admin/admin_content_page.dart';
import '../../views/admin/admin_dashboard_page.dart';
import '../../views/admin/admin_login_page.dart';
import '../../views/admin/admin_media_page.dart';
import '../../views/admin/admin_parent_accounts_page.dart';
import '../../views/admin/admin_progress_statistics_page.dart';
import '../../views/auth/forgot_password_page.dart';
import '../../views/auth/login_page.dart';
import '../../views/auth/signup_page.dart';
import '../../views/child_dashboard/home_page.dart';
import '../../views/child_dashboard/level_player_page.dart';
import '../../views/child_dashboard/module_levels_page.dart';
import '../../views/leaderboard/leaderboard_page.dart';
import '../../views/marking/parent_marking_page.dart';
import '../../views/notifications/notification_center_page.dart';
import '../../views/onboarding/manual_page.dart';
import '../../views/onboarding/onboarding_language_page.dart';
import '../../views/onboarding/readiness_test_page.dart';
import '../../views/profile/parental_lock_page.dart';
import '../../views/profile/child_selection_page.dart';
import '../../views/profile/parent_dashboard_page.dart';
import '../../views/profile/profile_create_edit_page.dart';
import '../../views/quiz/quiz_page.dart';
import '../../views/reminders/parent_reminders_page.dart';
import '../../views/reports/parent_reports_page.dart';
import '../../views/reward/celebration_page.dart';
import '../../views/splash/intro_splash_page.dart';
import '../../views/splash/splash_page.dart';
import '../../views/video/video_learning_page.dart';
import '../../views/video/video_player_page.dart';
import '../../widgets/play/play_route.dart';
import 'route_names.dart';

class CelebrationArgs {
  const CelebrationArgs({
    required this.moduleId,
    required this.levelTitle,
    required this.starsEarned,
    this.score,
  });

  final String moduleId;
  final String levelTitle;
  final int starsEarned;
  final int? score;
}

class QuizArgs {
  const QuizArgs({
    required this.levelId,
    this.parentMark,
  });

  final String levelId;

  /// The grade a parent already gave the canvas half of this level, carried
  /// into the quiz so the final mark reflects both halves instead of only the
  /// questions.
  final int? parentMark;
}

class ParentMarkingArgs {
  const ParentMarkingArgs({
    required this.level,
    required this.work,
  });

  final LearningLevel level;

  /// The finished pages to show the parent: one for a drawing level, one per
  /// letter for a tracing level.
  final List<CanvasWork> work;
}

class VideoPlayerArgs {
  const VideoPlayerArgs({
    required this.levelId,
    required this.lesson,
  });

  final String levelId;
  final VideoLesson lesson;
}

class ProfileEditArgs {
  const ProfileEditArgs({this.profileId, this.returnRoute});

  final String? profileId;

  /// Where saving lands. A parent editing from the dashboard belongs back on
  /// the dashboard, while the first profile of a brand new account belongs on
  /// the child selection screen; null means the dashboard.
  final String? returnRoute;
}

class ParentalLockArgs {
  const ParentalLockArgs({
    this.successRoute,
    this.successArguments,
  });

  /// Where to go once the challenge is solved. Leave it null to have the lock
  /// pop `true` instead, which is what a caller wants when it has more to do
  /// after the parent is verified rather than a screen to hand off to.
  final String? successRoute;
  final Object? successArguments;
}

class AppRouter {
  const AppRouter._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    // Routes that hand a value back to whoever pushed them have to be built
    // with a matching route type: `Navigator.pushNamed<T>` casts what this
    // returns to `Route<T>`, and a `Route<void>` fails that cast.
    if (settings.name == RouteNames.parentalLock) {
      return PlayPageRoute<bool>(
        settings: settings,
        builder: (_) => ParentalLockPage(
          args: settings.arguments as ParentalLockArgs? ??
              const ParentalLockArgs(),
        ),
      );
    }
    if (settings.name == RouteNames.parentMarking) {
      return PlayPageRoute<ParentMark>(
        settings: settings,
        builder: (_) => ParentMarkingPage(
          args: settings.arguments! as ParentMarkingArgs,
        ),
      );
    }

    return PlayPageRoute<void>(
      settings: settings,
      builder: (_) => switch (settings.name) {
        RouteNames.intro => const IntroSplashPage(),
        RouteNames.splash => const SplashPage(),
        RouteNames.login => const LoginPage(),
        RouteNames.signup => const SignupPage(),
        RouteNames.forgotPassword => const ForgotPasswordPage(),
        RouteNames.onboardingManual => const ManualPage(),
        RouteNames.onboardingLanguage => const OnboardingLanguagePage(),
        RouteNames.onboardingTest => const ReadinessTestPage(),
        RouteNames.adminLogin => const AdminLoginPage(),
        RouteNames.adminDashboard => const AdminDashboardPage(),
        RouteNames.adminContent => const AdminContentPage(),
        RouteNames.adminParentAccounts => const AdminParentAccountsPage(),
        RouteNames.adminProgressStatistics =>
          const AdminProgressStatisticsPage(),
        RouteNames.adminMedia => const AdminMediaPage(),
        RouteNames.parentDashboard => const ParentDashboardPage(),
        RouteNames.childSelection => const ChildSelectionPage(),
        RouteNames.profileEdit => ProfileCreateEditPage(
            args: settings.arguments as ProfileEditArgs?,
          ),
        RouteNames.parentReports => const ParentReportsPage(),
        RouteNames.parentReminders => const ParentRemindersPage(),
        RouteNames.parentNotifications => const NotificationCenterPage(),
        RouteNames.leaderboard => const LeaderboardPage(),
        RouteNames.childHome => const HomePage(),
        RouteNames.moduleLevels => ModuleLevelsPage(
            moduleId: settings.arguments! as String,
          ),
        RouteNames.levelPlayer => LevelPlayerPage(
            levelId: settings.arguments! as String,
          ),
        RouteNames.quiz => QuizPage(
            args: settings.arguments! as QuizArgs,
          ),
        RouteNames.celebration => CelebrationPage(
            args: settings.arguments! as CelebrationArgs,
          ),
        RouteNames.videoLearning => VideoLearningPage(
            moduleId: settings.arguments! as String,
          ),
        RouteNames.videoPlayer => VideoPlayerPage(
            args: settings.arguments! as VideoPlayerArgs,
          ),
        _ => const SplashPage(),
      },
    );
  }
}
