import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/theme/app_theme.dart';
import 'package:little_learners/repositories/auth_repository.dart';
import 'package:little_learners/viewmodels/auth_viewmodel.dart';
import 'package:little_learners/views/auth/forgot_password_page.dart';
import 'package:little_learners/views/auth/login_page.dart';
import 'package:little_learners/views/auth/signup_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('LoginPage form remains overflow-free on a compact phone',
      (tester) async {
    final errorCapture = _FlutterErrorCapture.start();
    addTearDown(errorCapture.restore);

    await _pumpAuthPage(tester, const LoginPage());
    errorCapture.restore();

    expect(find.text('PARENT'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(errorCapture.errors, isEmpty);
  });

  testWidgets('SignupPage keeps its minimal form responsive',
      (tester) async {
    final errorCapture = _FlutterErrorCapture.start();
    addTearDown(errorCapture.restore);

    await _pumpAuthPage(tester, const SignupPage());
    await tester.enterText(
      find.byType(TextField).last,
      'StrongPass1!',
    );
    await tester.pump();
    errorCapture.restore();

    expect(find.text('CREATE'), findsOneWidget);
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(
      find.text('8+ characters with uppercase, number and symbol'),
      findsOneWidget,
    );
    expect(errorCapture.errors, isEmpty);
  });

  testWidgets('LoginPage offers Google alongside the password form',
      (tester) async {
    await _pumpAuthPage(tester, const LoginPage());

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('ForgotPasswordPage asks Firebase to mail a reset link',
      (tester) async {
    final repository = InMemoryAuthRepository();
    await repository.signUp(email: 'parent@example.com', password: 'Old1!aaa');
    await _pumpAuthPage(
      tester,
      const ForgotPasswordPage(),
      repository: repository,
    );

    expect(find.text('RESET'), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'parent@example.com');
    await _tap(tester, 'Send reset link');

    expect(repository.passwordResetEmails, ['parent@example.com']);
    // The screen confirms in place rather than moving on: the rest of the
    // flow happens in the parent's mail client.
    expect(find.textContaining('Reset link sent'), findsOneWidget);
    expect(find.text('Send it again'), findsOneWidget);
  });

  testWidgets('ForgotPasswordPage reports an unknown email', (tester) async {
    await _pumpAuthPage(tester, const ForgotPasswordPage());

    await tester.enterText(find.byType(TextField), 'nobody@example.com');
    await _tap(tester, 'Send reset link');

    expect(find.text('No account found for this email.'), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);
  });
}

/// Taps the button carrying [label] and lets the resulting rebuild finish.
Future<void> _tap(WidgetTester tester, String label) async {
  final button = find.text(label);
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _pumpAuthPage(
  WidgetTester tester,
  Widget page, {
  InMemoryAuthRepository? repository,
  Size size = const Size(320, 568),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => AuthViewModel(repository ?? InMemoryAuthRepository()),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FlutterErrorCapture {
  _FlutterErrorCapture._(this._originalOnError);

  final void Function(FlutterErrorDetails)? _originalOnError;
  final errors = <FlutterErrorDetails>[];
  bool _restored = false;

  static _FlutterErrorCapture start() {
    final capture = _FlutterErrorCapture._(FlutterError.onError);
    FlutterError.onError = capture.errors.add;
    return capture;
  }

  void restore() {
    if (_restored) return;
    FlutterError.onError = _originalOnError;
    _restored = true;
  }
}
