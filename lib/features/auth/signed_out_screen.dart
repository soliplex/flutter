import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Screen shown after the user has been signed out.
///
/// Chrome-less (no AppShell) like other auth screens.
/// Provides a button to navigate back to the login screen.
class SignedOutScreen extends StatelessWidget {
  const SignedOutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ExcludeSemantics(child: Icon(Icons.logout, size: 48)),
            const SizedBox(height: 16),
            Text(
              'You have been signed out',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/login'),
              child: const Text('Sign in again'),
            ),
          ],
        ),
      ),
    );
  }
}
