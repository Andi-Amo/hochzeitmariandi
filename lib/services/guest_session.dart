import 'package:flutter/foundation.dart';

import '../models/guest.dart';

/// Holds the currently identified guest (via name search) for the duration
/// of the app session, so RSVP, seating plan, cake, and program screens can
/// all reference "who is looking at this".
class GuestSession extends ChangeNotifier {
  Guest? _guest;

  Guest? get guest => _guest;

  bool get isIdentified => _guest != null;

  void identify(Guest guest) {
    _guest = guest;
    notifyListeners();
  }

  void clear() {
    _guest = null;
    notifyListeners();
  }
}
