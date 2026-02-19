import 'package:meta/meta.dart';

/// A consent-to-monitoring notice shown before system access.
///
/// Regulated deployments can require users to acknowledge a notice
/// before proceeding past the login screen.
@immutable
class ConsentNotice {
  const ConsentNotice({
    required this.title,
    required this.body,
    this.acknowledgmentLabel = 'OK',
  });

  /// The notice heading.
  final String title;

  /// The full notice text.
  final String body;

  /// The label for the acknowledgment button.
  final String acknowledgmentLabel;

  /// Creates a copy with the specified fields replaced.
  ConsentNotice copyWith({
    String? title,
    String? body,
    String? acknowledgmentLabel,
  }) {
    return ConsentNotice(
      title: title ?? this.title,
      body: body ?? this.body,
      acknowledgmentLabel: acknowledgmentLabel ?? this.acknowledgmentLabel,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsentNotice &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          body == other.body &&
          acknowledgmentLabel == other.acknowledgmentLabel;

  @override
  int get hashCode => Object.hash(title, body, acknowledgmentLabel);

  @override
  String toString() => 'ConsentNotice('
      'title: $title, '
      'body: $body, '
      'acknowledgmentLabel: $acknowledgmentLabel)';
}
