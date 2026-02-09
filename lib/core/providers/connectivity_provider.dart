import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current network connectivity state.
///
/// Emits the initial connectivity result, then streams changes.
final connectivityProvider =
    StreamProvider<List<ConnectivityResult>>((ref) async* {
  ref.keepAlive();
  final connectivity = Connectivity();

  // Emit current state first.
  yield await connectivity.checkConnectivity();

  // Then listen for changes.
  await for (final results in connectivity.onConnectivityChanged) {
    yield results;
  }
});
