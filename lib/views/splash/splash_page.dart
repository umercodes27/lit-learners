import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/auth_flow_router.dart';
import '../../core/routing/route_names.dart';
import '../../viewmodels/auth_viewmodel.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _routeFromSplash());
  }

  Future<void> _routeFromSplash() async {
    final auth = context.read<AuthViewModel>();
    await auth.loadCurrentParent();
    if (!mounted) return;

    final parent = auth.parent;
    if (parent == null) {
      Navigator.of(context).pushReplacementNamed(RouteNames.login);
      return;
    }

    await AuthFlowRouter.routeAfterAuth(context: context, parent: parent);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school, size: 64),
            SizedBox(height: 16),
            Text(
              'Little Learners',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
