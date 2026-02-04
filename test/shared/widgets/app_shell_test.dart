import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';
import 'package:soliplex_frontend/shared/widgets/app_shell.dart';
import 'package:soliplex_frontend/shared/widgets/shell_config.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('AppShell', () {
    testWidgets('renders body content', (tester) async {
      const bodyKey = Key('body');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shellConfigProvider.overrideWithValue(testSoliplexConfig),
          ],
          child: MaterialApp(
            home: AppShell(
              config: const ShellConfig(),
              body: Container(key: bodyKey, child: const Text('Hello')),
            ),
          ),
        ),
      );

      expect(find.byKey(bodyKey), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('renders title from config', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shellConfigProvider.overrideWithValue(testSoliplexConfig),
          ],
          child: const MaterialApp(
            home: AppShell(
              config: ShellConfig(title: Text('My Title')),
              body: SizedBox.shrink(),
            ),
          ),
        ),
      );

      expect(find.text('My Title'), findsOneWidget);
    });

    testWidgets('renders single leading widget', (tester) async {
      const leadingKey = Key('leading');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shellConfigProvider.overrideWithValue(testSoliplexConfig),
          ],
          child: MaterialApp(
            home: AppShell(
              config: ShellConfig(
                leading: [
                  IconButton(
                    key: leadingKey,
                    icon: Icon(Icons.adaptive.arrow_back),
                    onPressed: () {},
                  ),
                ],
              ),
              body: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      expect(find.byKey(leadingKey), findsOneWidget);
    });

    testWidgets('renders multiple leading widgets in order', (tester) async {
      const backKey = Key('back');
      const menuKey = Key('menu');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shellConfigProvider.overrideWithValue(testSoliplexConfig),
          ],
          child: MaterialApp(
            home: AppShell(
              config: ShellConfig(
                leading: [
                  IconButton(
                    key: backKey,
                    icon: Icon(Icons.adaptive.arrow_back),
                    onPressed: () {},
                  ),
                  IconButton(
                    key: menuKey,
                    icon: const Icon(Icons.menu),
                    onPressed: () {},
                  ),
                ],
              ),
              body: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      // Both widgets should be present
      expect(find.byKey(backKey), findsOneWidget);
      expect(find.byKey(menuKey), findsOneWidget);

      // Back button should be to the left of menu button
      final backOffset = tester.getCenter(find.byKey(backKey));
      final menuOffset = tester.getCenter(find.byKey(menuKey));
      expect(backOffset.dx, lessThan(menuOffset.dx));
    });

    testWidgets('renders actions from config', (tester) async {
      const actionKey = Key('action');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shellConfigProvider.overrideWithValue(testSoliplexConfig),
          ],
          child: MaterialApp(
            home: AppShell(
              config: ShellConfig(
                actions: [
                  IconButton(
                    key: actionKey,
                    icon: const Icon(Icons.settings),
                    onPressed: () {},
                  ),
                ],
              ),
              body: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      expect(find.byKey(actionKey), findsOneWidget);
    });

    testWidgets('shows AppBar for empty config', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shellConfigProvider.overrideWithValue(testSoliplexConfig),
          ],
          child: const MaterialApp(
            home: AppShell(
              config: ShellConfig(),
              body: Center(child: Text('Content')),
            ),
          ),
        ),
      );

      expect(find.byType(AppBar), findsOneWidget);
    });

    group('start drawer', () {
      testWidgets('shows drawer when config provides one', (tester) async {
        const drawerContent = Text('Drawer Content');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              shellConfigProvider.overrideWithValue(testSoliplexConfig),
            ],
            child: const MaterialApp(
              home: AppShell(
                config: ShellConfig(drawer: Drawer(child: drawerContent)),
                body: SizedBox.shrink(),
              ),
            ),
          ),
        );

        tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
        await tester.pumpAndSettle();

        expect(find.text('Drawer Content'), findsOneWidget);
      });

      testWidgets('drawer is wrapped in Semantics', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              shellConfigProvider.overrideWithValue(testSoliplexConfig),
            ],
            child: const MaterialApp(
              home: AppShell(
                config: ShellConfig(drawer: Drawer(child: Text('Nav'))),
                body: SizedBox.shrink(),
              ),
            ),
          ),
        );

        tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
        await tester.pumpAndSettle();

        final semanticsFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Navigation drawer',
        );
        expect(semanticsFinder, findsOneWidget);
      });

      testWidgets('no drawer when config does not provide one', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              shellConfigProvider.overrideWithValue(testSoliplexConfig),
            ],
            child: const MaterialApp(
              home: AppShell(config: ShellConfig(), body: SizedBox.shrink()),
            ),
          ),
        );

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.drawer, isNull);
      });
    });
  });

  group('ShellConfig', () {
    test('has sensible defaults', () {
      const config = ShellConfig();
      expect(config.title, isNull);
      expect(config.leading, isEmpty);
      expect(config.actions, isEmpty);
      expect(config.drawer, isNull);
    });

    test('stores all provided values', () {
      const title = Text('Title');
      final leading = [
        IconButton(icon: const Icon(Icons.menu), onPressed: () {}),
      ];
      final actions = [
        IconButton(icon: const Icon(Icons.search), onPressed: () {}),
      ];
      const drawer = Drawer(child: Text('Menu'));

      final config = ShellConfig(
        title: title,
        leading: leading,
        actions: actions,
        drawer: drawer,
      );

      expect(config.title, same(title));
      expect(config.leading, same(leading));
      expect(config.actions, same(actions));
      expect(config.drawer, same(drawer));
    });
  });

  group('DrawerToggle', () {
    testWidgets('opens drawer when tapped', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shellConfigProvider.overrideWithValue(testSoliplexConfig),
          ],
          child: const MaterialApp(
            home: AppShell(
              config: ShellConfig(
                leading: [DrawerToggle()],
                drawer: Drawer(child: Text('Drawer Content')),
              ),
              body: SizedBox.shrink(),
            ),
          ),
        ),
      );

      // Drawer should be closed initially
      expect(find.text('Drawer Content'), findsNothing);

      // Tap the drawer toggle
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      // Drawer should be open
      expect(find.text('Drawer Content'), findsOneWidget);
    });

    testWidgets('has correct tooltip', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shellConfigProvider.overrideWithValue(testSoliplexConfig),
          ],
          child: const MaterialApp(
            home: AppShell(
              config: ShellConfig(
                leading: [DrawerToggle()],
                drawer: Drawer(child: Text('Nav')),
              ),
              body: SizedBox.shrink(),
            ),
          ),
        ),
      );

      final tooltipFinder = find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message == 'Open navigation',
      );
      expect(tooltipFinder, findsOneWidget);
    });
  });
}
