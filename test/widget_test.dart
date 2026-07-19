// Basic smoke test for the wedding app's home screen.
//
// We don't call `main()` here because it initializes Firebase, which isn't
// available in the widget-test environment. Instead we test HomeScreen in
// isolation with the providers it needs.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:wedapp/screens/home_screen.dart';
import 'package:wedapp/services/guest_session.dart';

void main() {
  testWidgets('HomeScreen shows navigation entries', (WidgetTester tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(path: '/rsvp', builder: (context, state) => const SizedBox()),
        GoRoute(path: '/seating', builder: (context, state) => const SizedBox()),
        GoRoute(path: '/cakes', builder: (context, state) => const SizedBox()),
        GoRoute(path: '/photos', builder: (context, state) => const SizedBox()),
        GoRoute(path: '/program', builder: (context, state) => const SizedBox()),
        GoRoute(path: '/admin', builder: (context, state) => const SizedBox()),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => GuestSession(),
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    expect(find.text('Info und Timetable:'), findsOneWidget);
    expect(find.text('Auf Einladung antworten (RSVP)'), findsOneWidget);
    expect(find.text('Sitzplan'), findsOneWidget);
    expect(find.text('Kuchensektion'), findsOneWidget);
    expect(find.text('Fotogalerie'), findsOneWidget);
  });
}
