import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'router.dart';
import 'services/auth_service.dart';
import 'services/guest_session.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AuthService().ensureSignedIn();
  runApp(const WeddingApp());
}

class WeddingApp extends StatelessWidget {
  const WeddingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GuestSession(),
      child: _RouterApp(router: buildRouter()),
    );
  }
}

class _RouterApp extends StatelessWidget {
  final GoRouter router;

  const _RouterApp({required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Unsere Hochzeit',
      theme: AppTheme.light(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

