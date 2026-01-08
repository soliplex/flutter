import 'package:meta/meta.dart';
import 'package:soliplex_client/soliplex_client.dart';

/// Authentication state for the application.
///
/// Uses sealed class pattern for exhaustive matching.
@immutable
sealed class AuthState {
  const AuthState();
}

/// User is not authenticated.
@immutable
class Unauthenticated extends AuthState {
  const Unauthenticated();

  @override
  bool operator ==(Object other) => other is Unauthenticated;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'Unauthenticated()';
}

/// User is authenticated with valid tokens.
@immutable
class Authenticated extends AuthState {
  const Authenticated({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.issuerId,
    required this.issuerDiscoveryUrl,
    required this.clientId,
    required this.idToken,
    this.endSessionEndpoint,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String issuerId;
  final String issuerDiscoveryUrl;
  final String clientId;
  final String idToken;
  final String? endSessionEndpoint;

  /// Whether the access token has expired.
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Whether the access token needs refresh (expiring soon).
  bool get needsRefresh => DateTime.now().isAfter(
        expiresAt.subtract(TokenRefreshService.refreshThreshold),
      );

  @override
  bool operator ==(Object other) =>
      other is Authenticated &&
      other.accessToken == accessToken &&
      other.refreshToken == refreshToken &&
      other.expiresAt == expiresAt &&
      other.issuerId == issuerId &&
      other.issuerDiscoveryUrl == issuerDiscoveryUrl &&
      other.clientId == clientId &&
      other.idToken == idToken &&
      other.endSessionEndpoint == endSessionEndpoint;

  @override
  int get hashCode => Object.hash(
        accessToken,
        refreshToken,
        expiresAt,
        issuerId,
        issuerDiscoveryUrl,
        clientId,
        idToken,
        endSessionEndpoint,
      );

  @override
  String toString() =>
      'Authenticated(issuerId: $issuerId, expiresAt: $expiresAt)';
}

/// Authentication is being restored from storage.
@immutable
class AuthLoading extends AuthState {
  const AuthLoading();

  @override
  bool operator ==(Object other) => other is AuthLoading;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'AuthLoading()';
}

/// Authentication is not required by the backend.
@immutable
class NoAuthRequired extends AuthState {
  const NoAuthRequired();

  @override
  bool operator ==(Object other) => other is NoAuthRequired;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'NoAuthRequired()';
}
