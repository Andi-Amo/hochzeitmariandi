/// Central place for wedding-day constants that gate time-based features
/// (e.g. the seating plan, which stays hidden until the reception starts).
class WeddingConfig {
  WeddingConfig._();

  /// The seating plan ([lib/screens/seating_plan_screen.dart]) stays locked
  /// for guests until this moment. Update if the schedule changes.
  static final DateTime seatingPlanUnlockTime = DateTime(2026, 9, 5, 14, 0);
}
