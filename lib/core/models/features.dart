import 'package:meta/meta.dart';

/// Feature flags for enabling/disabling functionality.
///
/// All flags default to `true` for backwards compatibility with existing
/// Soliplex behavior. White-label apps can disable features as needed.
@immutable
class Features {
  /// Creates feature flags with all features enabled by default.
  const Features({
    this.enableHttpInspector = true,
    this.enableQuizzes = true,
    this.enableSettings = true,
    this.showVersionInfo = true,
  });

  /// Creates feature flags with all features disabled.
  const Features.minimal()
      : enableHttpInspector = false,
        enableQuizzes = false,
        enableSettings = false,
        showVersionInfo = false;

  /// Whether to show the HTTP inspector button and drawer.
  ///
  /// Useful for debugging network traffic. Typically disabled in production
  /// white-label apps.
  final bool enableHttpInspector;

  /// Whether to enable the quiz feature.
  ///
  /// Quizzes provide interactive assessments based on room content.
  final bool enableQuizzes;

  /// Whether to show the settings screen in navigation.
  final bool enableSettings;

  /// Whether to show app version info in the settings screen.
  final bool showVersionInfo;

  /// Creates a copy with the specified fields replaced.
  Features copyWith({
    bool? enableHttpInspector,
    bool? enableQuizzes,
    bool? enableSettings,
    bool? showVersionInfo,
  }) {
    return Features(
      enableHttpInspector: enableHttpInspector ?? this.enableHttpInspector,
      enableQuizzes: enableQuizzes ?? this.enableQuizzes,
      enableSettings: enableSettings ?? this.enableSettings,
      showVersionInfo: showVersionInfo ?? this.showVersionInfo,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Features &&
          runtimeType == other.runtimeType &&
          enableHttpInspector == other.enableHttpInspector &&
          enableQuizzes == other.enableQuizzes &&
          enableSettings == other.enableSettings &&
          showVersionInfo == other.showVersionInfo;

  @override
  int get hashCode => Object.hash(
        enableHttpInspector,
        enableQuizzes,
        enableSettings,
        showVersionInfo,
      );

  @override
  String toString() => 'Features('
      'enableHttpInspector: $enableHttpInspector, '
      'enableQuizzes: $enableQuizzes, '
      'enableSettings: $enableSettings, '
      'showVersionInfo: $showVersionInfo)';
}
