import 'package:flutter/material.dart';

import '../../models/video_lesson.dart';
import '../../views/admin/admin_content_page.dart';
import '../../views/admin/admin_dashboard_page.dart';
import '../../views/auth/forgot_password_page.dart';
import '../../views/auth/login_page.dart';
import '../../views/auth/signup_page.dart';
import '../../views/child_dashboard/home_page.dart';
import '../../views/child_dashboard/level_player_page.dart';
import '../../views/child_dashboard/module_levels_page.dart';
import '../../views/leaderboard/leaderboard_page.dart';
import '../../views/onboarding/manual_page.dart';
import '../../views/onboarding/readiness_test_page.dart';
import '../../views/profile/parental_lock_page.dart';
import '../../views/profile/profile_create_edit_page.dart';
import '../../views/profile/profile_selection_page.dart';
import '../../views/quiz/quiz_page.dart';
import '../../views/reminders/parent_reminders_page.dart';
import '../../views/reports/parent_reports_page.dart';
import '../../views/reward/celebration_page.dart';
import '../../views/splash/splash_page.dart';
import '../../views/video/video_learning_page.dart';
import '../../views/video/video_player_page.dart';
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

class VideoPlayerArgs {
  const VideoPlayerArgs({
    required this.levelId,
    required this.lesson,
  });

  final String levelId;
  final VideoLesson lesson;
}

class ProfileEditArgs {
  const ProfileEditArgs({this.profileId});

  final String? profileId;
}

class ParentalLockArgs {
  const ParentalLockArgs({
    required this.successRoute,
    this.successArguments,
  });

  final String successRoute;
  final Object? successArguments;
}

class AppRouter {
  const AppRouter._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => switch (settings.name) {
        RouteNames.splash => const SplashPage(),
        RouteNames.login => const LoginPage(),
        RouteNames.signup => const SignupPage(),
        RouteNames.forgotPassword => const ForgotPasswordPage(),
        RouteNames.onboardingManual => const ManualPage(),
        RouteNames.onboardingTest => const ReadinessTestPage(),
        RouteNames.adminDashboard => const AdminDashboardPage(),
        RouteNames.adminContent => const AdminContentPage(),
        RouteNames.profiles => const ProfileSelectionPage(),
        RouteNames.profileEdit => ProfileCreateEditPage(
            args: settings.arguments as ProfileEditArgs?,
          ),
        RouteNames.parentReports => const ParentReportsPage(),
        RouteNames.parentReminders => const ParentRemindersPage(),
        RouteNames.leaderboard => const LeaderboardPage(),
        RouteNames.parentalLock => ParentalLockPage(
            args: settings.arguments! as ParentalLockArgs,
          ),
        RouteNames.childHome => const HomePage(),
        RouteNames.moduleLevels => ModuleLevelsPage(
            moduleId: settings.arguments! as String,
          ),
        RouteNames.levelPlayer => LevelPlayerPage(
            levelId: settings.arguments! as String,
          ),
        RouteNames.quiz => QuizPage(
            levelId: settings.arguments! as String,
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
