import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/theme/app_theme.dart';
import 'package:little_learners/repositories/auth_repository.dart';
import 'package:little_learners/viewmodels/auth_viewmodel.dart';
import 'package:little_learners/views/auth/login_page.dart';
import 'package:little_learners/views/auth/signup_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('LoginPage wooden form remains overflow-free on a compact phone',
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

  testWidgets('SignupPage keeps its minimal wooden form responsive',
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
}

Future<void> _pumpAuthPage(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => AuthViewModel(InMemoryAuthRepository()),
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
