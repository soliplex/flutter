import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/backend_version_provider.dart';
import 'package:soliplex_frontend/features/settings/backend_versions_screen.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('BackendVersionsScreen', () {
    testWidgets('displays all package versions', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const BackendVersionsScreen(),
          skipBackendVersionOverride: true,
          overrides: [
            backendVersionInfoProvider.overrideWithValue(
              const AsyncValue.data(
                BackendVersionInfo(
                  soliplexVersion: '0.36.dev0',
                  packageVersions: {
                    'soliplex': '0.36.dev0',
                    'fastapi': '0.115.0',
                    'pydantic': '2.9.0',
                  },
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Backend Versions'), findsOneWidget);
      expect(find.text('soliplex'), findsOneWidget);
      expect(find.text('0.36.dev0'), findsOneWidget);
      expect(find.text('fastapi'), findsOneWidget);
      expect(find.text('0.115.0'), findsOneWidget);
      expect(find.text('pydantic'), findsOneWidget);
      expect(find.text('2.9.0'), findsOneWidget);
    });

    testWidgets('shows loading indicator when fetching', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const BackendVersionsScreen(),
          skipBackendVersionOverride: true,
          overrides: [
            backendVersionInfoProvider.overrideWithValue(
              const AsyncValue<BackendVersionInfo>.loading(),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message on failure', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const BackendVersionsScreen(),
          skipBackendVersionOverride: true,
          overrides: [
            backendVersionInfoProvider.overrideWithValue(
              const AsyncValue<BackendVersionInfo>.error(
                NetworkException(message: 'Connection failed'),
                StackTrace.empty,
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Failed to load version information'), findsOneWidget);
    });

    group('search', () {
      testWidgets('filters packages by name', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: const BackendVersionsScreen(),
            skipBackendVersionOverride: true,
            overrides: [
              backendVersionInfoProvider.overrideWithValue(
                const AsyncValue.data(
                  BackendVersionInfo(
                    soliplexVersion: '0.36.dev0',
                    packageVersions: {
                      'soliplex': '0.36.dev0',
                      'fastapi': '0.115.0',
                      'pydantic': '2.9.0',
                    },
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        // Enter search text
        await tester.enterText(find.byType(TextField), 'fast');
        await tester.pump();

        // Should show fastapi, hide others
        expect(find.text('fastapi'), findsOneWidget);
        expect(find.text('soliplex'), findsNothing);
        expect(find.text('pydantic'), findsNothing);

        // Should show filtered count
        expect(find.text('1 of 3 packages'), findsOneWidget);
      });

      testWidgets('shows no results message when nothing matches',
          (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: const BackendVersionsScreen(),
            skipBackendVersionOverride: true,
            overrides: [
              backendVersionInfoProvider.overrideWithValue(
                const AsyncValue.data(
                  BackendVersionInfo(
                    soliplexVersion: '0.36.dev0',
                    packageVersions: {
                      'soliplex': '0.36.dev0',
                      'fastapi': '0.115.0',
                    },
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        await tester.enterText(find.byType(TextField), 'nonexistent');
        await tester.pump();

        expect(find.text('No packages match your search'), findsOneWidget);
      });

      testWidgets('search is case insensitive', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: const BackendVersionsScreen(),
            skipBackendVersionOverride: true,
            overrides: [
              backendVersionInfoProvider.overrideWithValue(
                const AsyncValue.data(
                  BackendVersionInfo(
                    soliplexVersion: '0.36.dev0',
                    packageVersions: {
                      'FastAPI': '0.115.0',
                    },
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        await tester.enterText(find.byType(TextField), 'fastapi');
        await tester.pump();

        expect(find.text('FastAPI'), findsOneWidget);
      });
    });

    testWidgets('displays package count', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const BackendVersionsScreen(),
          skipBackendVersionOverride: true,
          overrides: [
            backendVersionInfoProvider.overrideWithValue(
              const AsyncValue.data(
                BackendVersionInfo(
                  soliplexVersion: '0.36.dev0',
                  packageVersions: {
                    'soliplex': '0.36.dev0',
                    'fastapi': '0.115.0',
                    'pydantic': '2.9.0',
                  },
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('3 packages'), findsOneWidget);
    });

    testWidgets('displays packages in alphabetical order', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const BackendVersionsScreen(),
          skipBackendVersionOverride: true,
          overrides: [
            backendVersionInfoProvider.overrideWithValue(
              const AsyncValue.data(
                BackendVersionInfo(
                  soliplexVersion: '0.36.dev0',
                  // Provide in non-alphabetical order
                  packageVersions: {
                    'zebra': '1.0.0',
                    'alpha': '2.0.0',
                    'mango': '3.0.0',
                  },
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      // Find all ListTile widgets with package names
      final listTiles = find.byType(ListTile);
      final titles = <String>[];
      for (final element in tester.widgetList<ListTile>(listTiles)) {
        final title = element.title;
        if (title is Text) {
          titles.add(title.data ?? '');
        }
      }

      // Verify alphabetical order
      expect(titles, equals(['alpha', 'mango', 'zebra']));
    });

    testWidgets('handles empty packageVersions', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const BackendVersionsScreen(),
          skipBackendVersionOverride: true,
          overrides: [
            backendVersionInfoProvider.overrideWithValue(
              const AsyncValue.data(
                BackendVersionInfo(
                  soliplexVersion: 'Unknown',
                  packageVersions: {},
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('0 packages'), findsOneWidget);
      expect(find.text('No packages match your search'), findsOneWidget);
    });
  });
}
