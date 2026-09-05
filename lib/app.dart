import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/routing/app_router.dart';
import 'core/routing/route_names.dart';
import 'core/theme/app_scroll_behavior.dart';
import 'core/theme/app_theme.dart';
import 'repositories/admin_auth_repository.dart';
import 'repositories/admin_authorization_repository.dart';
import 'repositories/admin_content_repository.dart';
import 'repositories/admin_koala_guide_repository.dart';
import 'repositories/admin_stats_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/firebase_admin_auth_repository.dart';
import 'repositories/firestore_admin_stats_repository.dart';
import 'repositories/local_admin_stats_repository.dart';
import 'repositories/child_profile_repository.dart';
import 'repositories/content_repository.dart';
import 'repositories/firestore_admin_content_repository.dart';
import 'repositories/firestore_admin_koala_guide_repository.dart';
import 'repositories/firestore_media_asset_repository.dart';
import 'repositories/firebase_auth_repository.dart';
import 'repositories/koala_guide_repository.dart';
import 'repositories/leaderboard_repository.dart';
import 'repositories/firestore_onboarding_repository.dart';
import 'repositories/firestore_learning_reminder_repository.dart';
import 'repositories/learning_reminder_repository.dart';
import 'repositories/media_asset_repository.dart';
import 'repositories/notification_delivery_repository.dart';
import 'repositories/onboarding_repository.dart';
import 'repositories/parental_lock_repository.dart';
import 'repositories/parent_report_repository.dart';
import 'repositories/progress_repository.dart';
import 'services/firebase/admin_firebase_app.dart';
import 'services/firebase/firebase_auth_service.dart';
import 'services/firebase/firestore_child_profile_remote_data_source.dart';
import 'services/firebase/firestore_content_remote_data_source.dart';
import 'services/firebase/firestore_koala_guide_remote_data_source.dart';
import 'services/firebase/firestore_leaderboard_remote_data_source.dart';
import 'services/firebase/firestore_notification_delivery_remote_data_source.dart';
import 'services/firebase/firestore_progress_remote_data_source.dart';
import 'services/firebase/parent_firestore_service.dart';
import 'services/local/child_profile_dao.dart';
import 'services/local/content_dao.dart';
import 'services/local/db_helper.dart';
import 'services/local/progress_dao.dart';
import 'services/local/sync_outbox_dao.dart';
import 'services/notifications/local_notification_service.dart';
import 'services/audio/audioplayers_sound_controller.dart';
import 'services/audio/koala_audio_player.dart';
import 'services/audio/sound_controller.dart';
import 'services/audio/sound_settings_store.dart';
import 'services/remote/child_profile_remote_data_source.dart';
import 'services/remote/content_remote_data_source.dart';
import 'services/remote/koala_guide_remote_data_source.dart';
import 'services/remote/leaderboard_remote_data_source.dart';
import 'services/remote/notification_delivery_remote_data_source.dart';
import 'services/remote/progress_remote_data_source.dart';
import 'services/sync/backend_sync_coordinator.dart';
import 'services/sync/content_sync_service.dart';
import 'services/sync/koala_guide_sync_service.dart';
import 'services/sync/leaderboard_sync_service.dart';
import 'services/sync/progress_sync_service.dart';
import 'services/sync/sync_service.dart';
import 'services/sync/sync_orchestrator.dart';
import 'services/storage/media_storage_data_source.dart';
import 'viewmodels/active_child_session.dart';
import 'viewmodels/admin_auth_viewmodel.dart';
import 'viewmodels/admin_content_viewmodel.dart';
import 'viewmodels/admin_media_viewmodel.dart';
import 'viewmodels/admin_stats_viewmodel.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/leaderboard_viewmodel.dart';
import 'viewmodels/learning_viewmodel.dart';
import 'viewmodels/learning_reminder_viewmodel.dart';
import 'viewmodels/notification_viewmodel.dart';
import 'viewmodels/onboarding_viewmodel.dart';
import 'viewmodels/parental_lock_viewmodel.dart';
import 'viewmodels/parent_report_viewmodel.dart';
import 'viewmodels/profile_viewmodel.dart';

bool get _firebaseEnabled => AppConfig.useFirebase && Firebase.apps.isNotEmpty;

/// flutter_local_notifications only ships an Android and iOS implementation
/// that this app targets; anywhere else the no-op keeps the wiring identical.
bool get _supportsLocalNotifications =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

final _parentRemoteDataSource =
    _firebaseEnabled ? ParentFirestoreService() : null;
final AuthRepository _authRepository = _firebaseEnabled
    ? FirebaseAuthRepository(
        authService: FirebaseAuthService(),
        parentRemoteDataSource: _parentRemoteDataSource!,
      )
    : InMemoryAuthRepository();
final OnboardingRepository _onboardingRepository = _firebaseEnabled
    ? FirestoreOnboardingRepository(
        parentRemoteDataSource: _parentRemoteDataSource!,
      )
    : InMemoryOnboardingRepository();
final LearningReminderRepository _learningReminderRepository = _firebaseEnabled
    ? FirestoreLearningReminderRepository()
    : InMemoryLearningReminderRepository();
final _localDbHelper = LocalDbHelper();
final _childProfileDao = SqfliteChildProfileDao(_localDbHelper);
final _contentDao = SqfliteContentDao(_localDbHelper);
final _progressDao = SqfliteProgressDao(_localDbHelper);
final _syncOutboxDao = SqfliteSyncOutboxDao(_localDbHelper);
final _childProfileRemoteDataSource = _firebaseEnabled
    ? FirestoreChildProfileRemoteDataSource()
    : InMemoryChildProfileRemoteDataSource();
final _inMemoryContentRemoteDataSource = InMemoryContentRemoteDataSource();
final ContentRemoteDataSource _contentRemoteDataSource = _firebaseEnabled
    ? FirestoreContentRemoteDataSource()
    : _inMemoryContentRemoteDataSource;
final _inMemoryKoalaGuideRemoteDataSource =
    InMemoryKoalaGuideRemoteDataSource();
final KoalaGuideRemoteDataSource _koalaGuideRemoteDataSource = _firebaseEnabled
    ? FirestoreKoalaGuideRemoteDataSource()
    : _inMemoryKoalaGuideRemoteDataSource;
final _progressRemoteDataSource = _firebaseEnabled
    ? FirestoreProgressRemoteDataSource()
    : InMemoryProgressRemoteDataSource();
// Admin work runs on the secondary app, never the default one. See
// [AdminFirebaseApp]: the admin is signed in there and nowhere else, so a
// query on the default instance is denied by the rules however correct they
// are, and however successful the admin login was.
final MediaStorageDataSource _mediaStorageDataSource = _firebaseEnabled
    ? FirebaseMediaStorageDataSource(storage: AdminFirebaseApp.storage)
    : InMemoryMediaStorageDataSource();
final AdminContentRepository _baseAdminContentRepository = _firebaseEnabled
    ? FirestoreAdminContentRepository(firestore: AdminFirebaseApp.firestore)
    : InMemoryAdminContentRepository(
        contentRemoteDataSource: _inMemoryContentRemoteDataSource,
      );
final AdminKoalaGuideRepository _baseAdminKoalaGuideRepository =
    _firebaseEnabled
        ? FirestoreAdminKoalaGuideRepository(
            firestore: AdminFirebaseApp.firestore,
          )
        : InMemoryAdminKoalaGuideRepository(
            remoteDataSource: _inMemoryKoalaGuideRemoteDataSource,
          );
// UC-18: the admin portal runs on its own session, so admin work authorizes
// against [_adminAuthRepository] rather than the signed-in parent.
//
// Admin identity comes from `adminUsers/{uid}` — see
// docs/FIREBASE_ADMIN_SETUP.md. Set allowLegacyParentRole to false once every
// admin has an adminUsers document, and drop isLegacyAdminParent() from
// firestore.rules at the same time.
final AdminAuthRepository _adminAuthRepository = _firebaseEnabled
    ? FirebaseAdminAuthRepository(allowLegacyParentRole: true)
    : InMemoryAdminAuthRepository();
final _adminAuthorizationRepository = AdminSessionAuthorizationRepository(
  _adminAuthRepository,
);
// Demo mode reports real numbers from the local cache rather than placeholder
// values, so the dashboard reflects profiles and progress created in-session.
final AdminStatsRepository _adminStatsRepository =
    AuthorizedAdminStatsRepository(
  delegate: _firebaseEnabled
      ? FirestoreAdminStatsRepository(firestore: AdminFirebaseApp.firestore)
      : LocalAdminStatsRepository(
          childProfileDao: _childProfileDao,
          progressDao: _progressDao,
          contentDao: _contentDao,
          parentDirectory: _authRepository is ParentDirectory
              ? _authRepository as ParentDirectory
              : null,
        ),
  authorizationRepository: _adminAuthorizationRepository,
);
final AdminContentRepository _adminContentRepository =
    AuthorizedAdminContentRepository(
  delegate: _baseAdminContentRepository,
  authorizationRepository: _adminAuthorizationRepository,
);
final AdminKoalaGuideRepository _adminKoalaGuideRepository =
    AuthorizedAdminKoalaGuideRepository(
  delegate: _baseAdminKoalaGuideRepository,
  authorizationRepository: _adminAuthorizationRepository,
);
final MediaAssetRepository _baseMediaAssetRepository = _firebaseEnabled
    ? FirestoreMediaAssetRepository(
        firestore: AdminFirebaseApp.firestore,
        storageDataSource: _mediaStorageDataSource,
      )
    : InMemoryMediaAssetRepository(
        storageDataSource: _mediaStorageDataSource,
      );
final MediaAssetRepository _mediaAssetRepository =
    AuthorizedMediaAssetRepository(
  delegate: _baseMediaAssetRepository,
  authorizationRepository: _adminAuthorizationRepository,
);
final LeaderboardRemoteDataSource _leaderboardRemoteDataSource =
    _firebaseEnabled
        ? FirestoreLeaderboardRemoteDataSource()
        : InMemoryLeaderboardRemoteDataSource();
final _leaderboardRepository = RemoteLeaderboardRepository(
  remoteDataSource: _leaderboardRemoteDataSource,
);
final NotificationDeliveryRemoteDataSource
    _notificationDeliveryRemoteDataSource = _firebaseEnabled
        ? FirestoreNotificationDeliveryRemoteDataSource()
        : InMemoryNotificationDeliveryRemoteDataSource();
final _notificationDeliveryRepository = ReminderNotificationDeliveryRepository(
  reminderRepository: _learningReminderRepository,
  remoteDataSource: _notificationDeliveryRemoteDataSource,
);
final LocalNotificationService localNotificationService =
    _supportsLocalNotifications
        ? FlutterLocalNotificationService()
        : NoopLocalNotificationService();
final _profileRepository = CachedChildProfileRepository(
  profileDao: _childProfileDao,
  syncOutboxDao: _syncOutboxDao,
);
final _syncService = SyncService(
  childProfileDao: _childProfileDao,
  syncOutboxDao: _syncOutboxDao,
  childProfileRemoteDataSource: _childProfileRemoteDataSource,
);
final _progressSyncService = ProgressSyncService(
  progressDao: _progressDao,
  progressRemoteDataSource: _progressRemoteDataSource,
);
final _contentSyncService = ContentSyncService(
  contentDao: _contentDao,
  contentRemoteDataSource: _contentRemoteDataSource,
);
final _koalaGuideRepository = SeededKoalaGuideRepository();
final _koalaGuideSyncService = KoalaGuideSyncService(
  repository: _koalaGuideRepository,
  remoteDataSource: _koalaGuideRemoteDataSource,
);
final _leaderboardSyncService = LeaderboardSyncService(
  childProfileRepository: _profileRepository,
  progressRepository: _progressRepository,
  leaderboardRepository: _leaderboardRepository,
  profileSyncService: _syncService,
  progressSyncService: _progressSyncService,
);
final _syncOrchestrator = SyncOrchestrator(
  connectivityStatusProvider: const AlwaysOnlineConnectivityStatusProvider(),
);
final _backendSyncCoordinator = BackendSyncCoordinator(
  orchestrator: _syncOrchestrator,
  profileSyncService: _syncService,
  progressSyncService: _progressSyncService,
  contentSyncService: _contentSyncService,
  koalaGuideSyncService: _koalaGuideSyncService,
  leaderboardSyncService: _leaderboardSyncService,
);
final _parentalLockRepository = InMemoryParentalLockRepository();
final _contentRepository = CachedContentRepository(
  contentDao: _contentDao,
  contentSyncService: _contentSyncService,
);
final _progressRepository = CachedProgressRepository(progressDao: _progressDao);
final _parentReportRepository = CachedParentReportRepository(
  childProfileRepository: _profileRepository,
  progressRepository: _progressRepository,
  contentRepository: _contentRepository,
  profileSyncService: _syncService,
  progressSyncService: _progressSyncService,
);
final _koalaAudioPlayer = AudioplayersKoalaAudioPlayer();

/// The app's one speaker, built once and handed to [AppSound] so widgets as
/// deep as `Squishy` can reach it without a provider lookup.
///
/// Settings are read asynchronously; until they arrive the defaults apply,
/// which is the right way round — a parent who muted the app last night gets
/// silence a frame later, not a burst of music first. `load()` is called
/// before the first frame in `main.dart`.
final SoundController _soundController = _buildSoundController();

SoundController _buildSoundController() {
  final controller = AudioplayersSoundController(
    store: LocalSoundSettingsStore(
      dbHelper: _localDbHelper,
      defaults: const SoundSettings(
        muted: false,
        musicVolume: 0.28,
        sfxVolume: 0.75,
      ),
    ),
  );
  AppSound.instance = controller;
  return controller;
}

/// Loads the stored sound settings. Called from `main()` before the first
/// frame.
Future<void> loadSoundSettings() => _soundController.load();

class LittleLearnersApp extends StatelessWidget {
  const LittleLearnersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: _authRepository),
        Provider<AdminAuthorizationRepository>.value(
          value: _adminAuthorizationRepository,
        ),
        Provider<AdminAuthRepository>.value(value: _adminAuthRepository),
        Provider<AdminStatsRepository>.value(value: _adminStatsRepository),
        Provider<AdminContentRepository>.value(value: _adminContentRepository),
        Provider<AdminKoalaGuideRepository>.value(
          value: _adminKoalaGuideRepository,
        ),
        Provider<MediaAssetRepository>.value(value: _mediaAssetRepository),
        Provider<LeaderboardRepository>.value(value: _leaderboardRepository),
        Provider<NotificationDeliveryRepository>.value(
          value: _notificationDeliveryRepository,
        ),
        Provider<OnboardingRepository>.value(value: _onboardingRepository),
        Provider<LearningReminderRepository>.value(
          value: _learningReminderRepository,
        ),
        Provider<ChildProfileRepository>.value(value: _profileRepository),
        Provider<ParentalLockRepository>.value(value: _parentalLockRepository),
        Provider<ParentReportRepository>.value(value: _parentReportRepository),
        Provider<ContentRepository>.value(value: _contentRepository),
        Provider<ProgressRepository>.value(value: _progressRepository),
        Provider<KoalaGuideRepository>.value(value: _koalaGuideRepository),
        Provider<KoalaAudioPlayer>.value(value: _koalaAudioPlayer),
        ChangeNotifierProvider<SoundController>.value(
          value: _soundController,
        ),
        Provider<SyncService>.value(value: _syncService),
        Provider<ProgressSyncService>.value(value: _progressSyncService),
        Provider<ContentSyncService>.value(value: _contentSyncService),
        Provider<KoalaGuideSyncService>.value(value: _koalaGuideSyncService),
        Provider<BackendSyncCoordinator>.value(
          value: _backendSyncCoordinator,
        ),
        Provider<LeaderboardSyncService>.value(
          value: _leaderboardSyncService,
        ),
        ChangeNotifierProvider(create: (_) => AuthViewModel(_authRepository)),
        ChangeNotifierProvider(
          create: (_) => AdminAuthViewModel(_adminAuthRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => AdminStatsViewModel(_adminStatsRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => AdminMediaViewModel(_mediaAssetRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => AdminContentViewModel(
            _adminContentRepository,
            contentSyncService: _contentSyncService,
          ),
        ),
        Provider<LocalNotificationService>.value(
          value: localNotificationService,
        ),
        ChangeNotifierProvider(
          create: (_) => LearningReminderViewModel(
            _learningReminderRepository,
            localNotifications: localNotificationService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationViewModel(
            repository: _notificationDeliveryRepository,
            localNotifications: localNotificationService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => OnboardingViewModel(_onboardingRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => ProfileViewModel(
            _profileRepository,
            syncService: _syncService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ParentalLockViewModel(_parentalLockRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => ParentReportViewModel(_parentReportRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => LeaderboardViewModel(
            leaderboardRepository: _leaderboardRepository,
            leaderboardSyncService: _leaderboardSyncService,
          ),
        ),
        ChangeNotifierProvider(create: (_) => ActiveChildSession()),
        ChangeNotifierProvider(
          create: (_) => LearningViewModel(
            contentRepository: _contentRepository,
            progressRepository: _progressRepository,
            progressSyncService: _progressSyncService,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Little Learners',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        scrollBehavior: const AppScrollBehavior(),
        initialRoute: RouteNames.intro,
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
  }
}
