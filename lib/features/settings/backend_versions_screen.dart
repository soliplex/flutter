import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_frontend/core/providers/backend_version_provider.dart';
import 'package:soliplex_frontend/design/design.dart';
import 'package:soliplex_frontend/shared/widgets/app_shell.dart';
import 'package:soliplex_frontend/shared/widgets/shell_config.dart';

/// Screen displaying all backend package versions with search functionality.
class BackendVersionsScreen extends ConsumerStatefulWidget {
  const BackendVersionsScreen({super.key});

  @override
  ConsumerState<BackendVersionsScreen> createState() =>
      _BackendVersionsScreenState();
}

class _BackendVersionsScreenState extends ConsumerState<BackendVersionsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  // Cached data
  Map<String, String> _latestPackages = {};
  Map<String, String> _filteredPackages = {};
  List<String> _sortedKeys = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Update filtered packages based on current search query.
  void _updateFilter(Map<String, String> packages) {
    final query = _searchQuery.trim().toLowerCase();

    final entries = query.isEmpty
        ? packages.entries
        : packages.entries.where(
            (e) => e.key.toLowerCase().contains(query),
          );

    final newFiltered = Map<String, String>.fromEntries(entries);
    final newSortedKeys = newFiltered.keys.toList()..sort();

    // Only set state if something actually changed.
    if (!mapEquals(_filteredPackages, newFiltered) ||
        !listEquals(_sortedKeys, newSortedKeys)) {
      setState(() {
        _filteredPackages = newFiltered;
        _sortedKeys = newSortedKeys;
      });
    }
  }

  // Helpers to update cached packages when provider yields new data.
  void _maybeUpdatePackages(Map<String, String> packages) {
    // If the package map reference or contents changed, update caches.
    if (!mapEquals(_latestPackages, packages)) {
      _latestPackages = Map<String, String>.from(packages);
      _updateFilter(_latestPackages);
    }
  }

  // Debounced onChanged handler
  void _onSearchChanged(String value) {
    // cancel previous debounce
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      // update query and recompute filter once debounce fires
      if (mounted) {
        setState(() => _searchQuery = value);
        _updateFilter(_latestPackages);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final versionInfo = ref.watch(backendVersionInfoProvider);

    return AppShell(
      config: ShellConfig(
        leading: [
          IconButton(
            icon: Icon(Icons.adaptive.arrow_back),
            onPressed: () => context.pop(),
            tooltip: 'Back',
          ),
        ],
        title: const Text('Backend Versions'),
      ),
      body: versionInfo.when(
        data: (info) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _maybeUpdatePackages(info.packageVersions);
          });

          return _buildContent();
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          debugPrint('Failed to load backend versions: $error');
          debugPrint('$stack');
          return const Center(
            child: Text('Failed to load version information'),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    final totalPackages = _latestPackages.length;
    final visibleCount = _sortedKeys.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search packages...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _searchQuery.isEmpty
                  ? '$totalPackages packages'
                  : '$visibleCount of $totalPackages packages',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _sortedKeys.isEmpty
              ? const Center(child: Text('No packages match your search'))
              : ListView.builder(
                  itemCount: _sortedKeys.length,
                  itemBuilder: (context, index) {
                    final packageName = _sortedKeys[index];
                    final version = _filteredPackages[packageName] ?? '';

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        dense: true,
                        title: Text(
                          packageName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: SoliplexSpacing.s2,
                          children: [
                            Text(
                              version,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () => Clipboard.setData(
                                ClipboardData(text: '$packageName $version'),
                              ),
                              tooltip: 'Copy package & version',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
