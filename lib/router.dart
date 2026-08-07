import 'package:go_router/go_router.dart';

import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_guest_list_screen.dart';
import 'screens/admin/admin_login_screen.dart';
import 'screens/admin/admin_photo_curation_screen.dart';
import 'screens/admin/admin_program_overview_screen.dart';
import 'screens/admin/admin_seating_plan_screen.dart';
import 'screens/cake_screen.dart';
import 'screens/home_screen.dart';
import 'screens/photo_gallery_screen.dart';
import 'screens/program_signup_screen.dart';
import 'screens/rsvp_screen.dart';
import 'screens/hotel_screen.dart';
import 'screens/location_screen.dart';
import 'screens/seating_plan_screen.dart';
import 'services/auth_service.dart';

/// App-wide route table. Admin routes ('/admin/...') are guarded by a
/// simple redirect that checks [AuthService.isAdmin].
GoRouter buildRouter() {
  final authService = AuthService();

  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/rsvp', builder: (context, state) => const RsvpScreen()),
      GoRoute(path: '/cakes', builder: (context, state) => const CakeScreen()),
      GoRoute(path: '/photos', builder: (context, state) => const PhotoGalleryScreen()),
      GoRoute(path: '/program', builder: (context, state) => const ProgramSignupScreen()),
      GoRoute(path: '/admin', builder: (context, state) => const AdminLoginScreen()),
      GoRoute(path: '/seating', builder: (context, state) => const SeatingPlanScreen()),
      GoRoute(path: '/location', builder: (context, state) => const LocationScreen()),
      GoRoute(path: '/hotel', builder: (context, state) => const HotelScreen()),
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/guests',
        builder: (context, state) => const AdminGuestListScreen(),
      ),
      GoRoute(
        path: '/admin/photos',
        builder: (context, state) => const AdminPhotoCurationScreen(),
      ),
      GoRoute(
        path: '/admin/program',
        builder: (context, state) => const AdminProgramOverviewScreen(),
      ),
      GoRoute(
        path: '/admin/seating',
        builder: (context, state) => const AdminSeatingPlanScreen(),
      ),
    ],
    redirect: (context, state) {
      final goingToAdminArea = state.matchedLocation.startsWith('/admin');
      final goingToLoginPage = state.matchedLocation == '/admin';
      if (goingToAdminArea && !goingToLoginPage && !authService.isAdmin) {
        return '/admin';
      }
      return null;
    },
  );
}
