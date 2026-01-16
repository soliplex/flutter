/// Application configuration for user-configurable settings.
class AppConfig {
  const AppConfig({required this.baseUrl});

  final String baseUrl;

  AppConfig copyWith({String? baseUrl}) {
    return AppConfig(baseUrl: baseUrl ?? this.baseUrl);
  }
}
