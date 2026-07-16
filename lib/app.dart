import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/routing/app_router.dart';
import 'core/routing/route_names.dart';
import 'core/theme/app_theme.dart';
import 'repositories/admin_authorization_repository.dart';
import 'repositories/admin_content_repository.dart';
import 'repositories/admin_koala_guide_repository.dart';
import 'repositories/auth_repository.dart';
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
import 'services/audio/koala_audio_player.dart';
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
import 'viewmodels/admin_content_viewmodel.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/leaderboard_viewmodel.dart';
import 'viewmodels/learning_viewmodel.dart';
import 'viewmodels/learning_reminder_viewmodel.dart';
import 'viewmodels/onboarding_viewmodel.dart';
import 'viewmodels/parental_lock_viewmodel.dart';
import 'viewmodels/parent_report_viewmodel.dart';
import 'viewmodels/profile_viewmodel.dart';

bool get _firebaseEnabled => AppConfig.useFirebase && Firebase.apps.isNotEmpty;

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
final MediaStorageDataSource _mediaStorageDataSource = _firebaseEnabled
    ? FirebaseMediaStorageDataSource()
    : InMemoryMediaStorageDataSource();
final AdminContentRepository _baseAdminContentRepository = _firebaseEnabled
    ? FirestoreAdminContentRepository()
    : InMemoryAdminContentRepository(
        contentRemoteDataSource: _inMemoryContentRemoteDataSource,
      );
final AdminKoalaGuideRepository _baseAdminKoalaGuideRepository =
    _firebaseEnabled
        ? FirestoreAdminKoalaGuideRepository()
        : InMemoryAdminKoalaGuideRepository(
            remoteDataSource: _inMemoryKoalaGuideRemoteDataSource,
          );
final _adminAuthorizationRepository = AuthAdminAuthorizationRepository(
  _authRepository,
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
          create: (_) => AdminContentViewModel(
            _adminContentRepository,
            contentSyncService: _contentSyncService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => LearningReminderViewModel(
            _learningReminderRepository,
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
        initialRoute: RouteNames.splash,
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
  }
}
