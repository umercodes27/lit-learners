import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/constants/avatar_presets.dart';
import 'package:little_learners/core/theme/app_theme.dart';
import 'package:little_learners/repositories/auth_repository.dart';
import 'package:little_learners/repositories/child_profile_repository.dart';
import 'package:little_learners/viewmodels/auth_viewmodel.dart';
import 'package:little_learners/viewmodels/profile_viewmodel.dart';
import 'package:little_learners/views/profile/profile_create_edit_page.dart';
import 'package:little_learners/widgets/child_avatar.dart';
import 'package:little_learners/widgets/play/play.dart';
import 'package:provider/provider.dart';

void main() {
  test('the catalog offers six ready-made avatars with distinct ids', () {
    expect(AvatarPresets.all, hasLength(6));
    expect(
      AvatarPresets.all.map((preset) => preset.id).toSet(),
      hasLength(6),
    );
    // The ids that shipped before the catalog have to keep resolving, or
    // profiles already on a device lose their face.
    for (final id in ['koala-blue', 'koala-green', 'koala-coral',
      'koala-honey']) {
      expect(AvatarPresets.byId(id), isNotNull, reason: id);
    }
  });

  test('an uploaded photo is not mistaken for a preset', () {
    expect(AvatarPresets.byId('https://example.com/a.jpg'), isNull);
    expect(AvatarPresets.byId('file:///tmp/a.jpg'), isNull);
  });

  testWidgets('the form lays out every ready-made avatar to choose from',
      (tester) async {
    await _pumpForm(tester);

    for (final preset in AvatarPresets.all) {
      expect(find.text(preset.label), findsOneWidget, reason: preset.id);
    }
    // One per option, plus the preview of the chosen one.
    expect(find.byType(ChildAvatar), findsNWidgets(AvatarPresets.all.length + 1));
    expect(find.text('Use a photo'), findsOneWidget);
  });

  testWidgets('the form offers only the ages the content is authored for',
      (tester) async {
    await _pumpForm(tester);

    expect(find.text('Choose an age from 1 to 4.'), findsOneWidget);
    // Squishy rather than ChoiceChip: the age options are play-kit tiles now.
    // The assertion is unchanged — each age in range is offered as something
    // tappable, and nothing outside the range is.
    for (final age in ['1', '2', '3', '4']) {
      expect(find.widgetWithText(Squishy, age), findsOneWidget);
    }
    for (final age in ['5', '6', '7', '8']) {
      expect(find.widgetWithText(Squishy, age), findsNothing);
    }
  });

  testWidgets('a photo asks for the camera or the gallery, then for consent',
      (tester) async {
    await _pumpForm(tester);

    await _tapText(tester, 'Use a photo');
    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);

    await _tapText(tester, 'Take a photo');
    expect(find.text('Allow camera access?'), findsOneWidget);

    // Declining stops before the system prompt, and the form is untouched.
    await _tapText(tester, 'Not now');
    expect(find.text('Allow camera access?'), findsNothing);
    expect(find.text('Create profile'), findsOneWidget);
  });

  testWidgets('the gallery asks for photo access rather than the camera',
      (tester) async {
    await _pumpForm(tester);

    await _tapText(tester, 'Use a photo');
    await _tapText(tester, 'Choose from gallery');

    expect(find.text('Allow photo access?'), findsOneWidget);
    expect(find.text('Allow camera access?'), findsNothing);
  });
}

/// The form scrolls, so anything below the fold has to be brought into view
/// before it can be tapped.
Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Future<void> _pumpForm(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final authRepository = InMemoryAuthRepository();
  await authRepository.signUp(
    email: 'parent@example.com',
    password: 'StrongPass1!',
  );
  final auth = AuthViewModel(authRepository);
  await auth.loadCurrentParent();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>.value(value: auth),
        ChangeNotifierProvider<ProfileViewModel>(
          create: (_) => ProfileViewModel(InMemoryChildProfileRepository()),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const ProfileCreateEditPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
