import 'package:meta/meta.dart';

/// User identity from the backend's /user_info endpoint.
@immutable
class UserIdentity {
  /// Creates a user identity.
  const UserIdentity({
    required this.email,
    required this.preferredUsername,
    this.givenName,
    this.familyName,
  });

  /// The user's email address.
  final String email;

  /// The user's preferred username (login name).
  final String preferredUsername;

  /// The user's given (first) name, if available.
  final String? givenName;

  /// The user's family (last) name, if available.
  final String? familyName;

  /// Display name: "Given Family" if available, else username.
  String get displayName {
    final parts = [
      if (givenName != null && givenName!.isNotEmpty) givenName!,
      if (familyName != null && familyName!.isNotEmpty) familyName!,
    ];
    return parts.isNotEmpty ? parts.join(' ') : preferredUsername;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserIdentity &&
          email == other.email &&
          preferredUsername == other.preferredUsername &&
          givenName == other.givenName &&
          familyName == other.familyName;

  @override
  int get hashCode =>
      Object.hash(email, preferredUsername, givenName, familyName);

  @override
  String toString() => 'UserIdentity($preferredUsername, $email)';
}
