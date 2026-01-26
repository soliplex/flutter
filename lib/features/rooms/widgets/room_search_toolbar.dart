import 'package:flutter/material.dart';

import 'package:soliplex_frontend/design/tokens/spacing.dart';

/// Search toolbar with optional view toggle for room listing.
class RoomSearchToolbar extends StatefulWidget {
  const RoomSearchToolbar({
    required this.query,
    required this.isGridView,
    required this.showViewToggle,
    required this.onQueryChanged,
    required this.onToggleView,
    super.key,
  });

  final String query;
  final bool isGridView;
  final bool showViewToggle;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onToggleView;

  @override
  State<RoomSearchToolbar> createState() => _RoomSearchToolbarState();
}

class _RoomSearchToolbarState extends State<RoomSearchToolbar> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.query;
  }

  @override
  void didUpdateWidget(RoomSearchToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _controller.text) {
      _controller.text = widget.query;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: SoliplexSpacing.s4,
        bottom: SoliplexSpacing.s2,
      ),
      child: Row(
        mainAxisAlignment: widget.showViewToggle
            ? MainAxisAlignment.spaceBetween
            : MainAxisAlignment.center,
        spacing: SoliplexSpacing.s2,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Search rooms...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: widget.query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Clear search',
                          onPressed: () => widget.onQueryChanged(''),
                        )
                      : null,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: widget.onQueryChanged,
              ),
            ),
          ),
          if (widget.showViewToggle)
            IconButton.filledTonal(
              icon: Icon(widget.isGridView ? Icons.view_list : Icons.grid_view),
              onPressed: widget.onToggleView,
              tooltip: widget.isGridView ? 'Show as list' : 'Show as grid',
            ),
        ],
      ),
    );
  }
}
