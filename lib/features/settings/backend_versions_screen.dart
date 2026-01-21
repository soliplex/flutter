import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_frontend/core/providers/backend_version_provider.dart';

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final versionInfo = ref.watch(backendVersionInfoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Backend Versions')),
      body: versionInfo.when(
        data: (info) => _buildContent(info.packageVersions),
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

  Widget _buildContent(Map<String, String> packageVersions) {
    final filteredPackages = _filterPackages(packageVersions);
    final sortedKeys = filteredPackages.keys.toList()..sort();

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
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _searchQuery.isEmpty
                  ? '${packageVersions.length} packages'
                  : '${sortedKeys.length} of '
                      '${packageVersions.length} packages',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: sortedKeys.isEmpty
              ? const Center(child: Text('No packages match your search'))
              : ListView.builder(
                  itemCount: sortedKeys.length,
                  itemBuilder: (context, index) {
                    final packageName = sortedKeys[index];
                    final version = filteredPackages[packageName]!;
                    return ListTile(
                      title: Text(packageName),
                      trailing: Text(version),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Map<String, String> _filterPackages(Map<String, String> packages) {
    if (_searchQuery.isEmpty) return packages;

    final query = _searchQuery.toLowerCase();
    return Map.fromEntries(
      packages.entries.where(
        (entry) => entry.key.toLowerCase().contains(query),
      ),
    );
  }
}
