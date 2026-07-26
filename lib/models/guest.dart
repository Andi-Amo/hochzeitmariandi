import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single wedding guest as stored in the `guests` collection.
class Guest {
  final String id;
  final String firstName;
  final String lastName;
  final String? groupId; // <--- Added: Family / Household group ID
  final String? tableId;
  final String? seat;

  /// Guests who are known to usually bring a cake. They get an automatic
  /// reminder popup in the cake section.
  final bool isUsualCakeSuspect;

  /// Whether this guest is a child (vs. adult). Defaults to `false` (adult)
  /// unless set otherwise in the guest list; guests can also adjust this
  /// themselves (with [childAge]) when submitting their RSVP.
  final bool isChild;

  /// Age of the child, only meaningful when [isChild] is `true`.
  final int? childAge;

  final String rsvpStatus; // 'pending' | 'attending' | 'declined'
  final int plusOnes;
  final String? dietaryNotes;

  const Guest({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.groupId, // <--- Added
    this.tableId,
    this.seat,
    this.isUsualCakeSuspect = false,
    this.isChild = false,
    this.childAge,
    this.rsvpStatus = 'pending',
    this.plusOnes = 0,
    this.dietaryNotes,
  });

  String get fullName => '$firstName $lastName';

  /// Normalized name used for case/whitespace-insensitive search matching.
  String get normalizedName =>
      fullName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  factory Guest.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Guest(
      id: doc.id,
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      groupId: data['groupId'] as String?, // <--- Added
      tableId: data['tableId'] as String?,
      seat: data['seat'] as String?,
      isUsualCakeSuspect: data['isUsualCakeSuspect'] as bool? ?? false,
      isChild: data['isChild'] as bool? ?? false,
      childAge: (data['childAge'] as num?)?.toInt(),
      rsvpStatus: data['rsvpStatus'] as String? ?? 'pending',
      plusOnes: (data['plusOnes'] as num?)?.toInt() ?? 0,
      dietaryNotes: data['dietaryNotes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'groupId': groupId, // <--- Added
      'tableId': tableId,
      'seat': seat,
      'isUsualCakeSuspect': isUsualCakeSuspect,
      'isChild': isChild,
      'childAge': childAge,
      'rsvpStatus': rsvpStatus,
      'plusOnes': plusOnes,
      'dietaryNotes': dietaryNotes,
    };
  }

  Guest copyWith({
    String? groupId, // <--- Added
    String? tableId,
    String? seat,
    bool? isUsualCakeSuspect,
    bool? isChild,
    int? childAge,
    String? rsvpStatus,
    int? plusOnes,
    String? dietaryNotes,
  }) {
    return Guest(
      id: id,
      firstName: firstName,
      lastName: lastName,
      groupId: groupId ?? this.groupId, // <--- Added
      tableId: tableId ?? this.tableId,
      seat: seat ?? this.seat,
      isUsualCakeSuspect: isUsualCakeSuspect ?? this.isUsualCakeSuspect,
      isChild: isChild ?? this.isChild,
      childAge: childAge ?? this.childAge,
      rsvpStatus: rsvpStatus ?? this.rsvpStatus,
      plusOnes: plusOnes ?? this.plusOnes,
      dietaryNotes: dietaryNotes ?? this.dietaryNotes,
    );
  }
}