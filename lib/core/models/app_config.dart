/// Application configuration for user-configurable settings.
class AppConfig {
  const AppConfig({required this.baseUrl});

  /// Default configuration for local development.
  factory AppConfig.defaults() {
    return const AppConfig(baseUrl: 'http://localhost:8000');
  }

  final String baseUrl;

  AppConfig copyWith({String? baseUrl}) {
    return AppConfig(baseUrl: baseUrl ?? this.baseUrl);
  }
}
