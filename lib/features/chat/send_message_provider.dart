import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:soliplex_frontend/core/providers/active_run_provider.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/selected_documents_provider.dart';
import 'package:soliplex_frontend/features/chat/send_message.dart';

/// Provides a [SendMessage] interactor wired to Riverpod dependencies.
final sendMessageProvider = Provider<SendMessage>((ref) {
  return SendMessage(
    api: ref.watch(apiProvider),
    startRun: ref.watch(activeRunNotifierProvider.notifier).startRun,
    documentSelection: ref.watch(documentSelectionProvider),
  );
});
