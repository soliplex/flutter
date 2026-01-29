import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_frontend/core/application/run_lifecycle_impl.dart';
import 'package:soliplex_frontend/core/domain/interfaces/run_lifecycle.dart';
import 'package:soliplex_frontend/core/domain/interfaces/screen_wake_lock.dart';
import 'package:soliplex_frontend/core/infrastructure/platform/wakelock_plus_adapter.dart';

/// Provider for the screen wake lock implementation.
final screenWakeLockProvider = Provider<ScreenWakeLock>((ref) {
  return WakelockPlusAdapter();
});

/// Provider for run lifecycle management.
final runLifecycleProvider = Provider<RunLifecycle>((ref) {
  return RunLifecycleImpl(wakeLock: ref.watch(screenWakeLockProvider));
});
