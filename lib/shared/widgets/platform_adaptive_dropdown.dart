import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:soliplex_frontend/design/design.dart';
import 'package:soliplex_frontend/shared/utils/platform_resolver.dart';

class PlatformAdaptiveDropdownItem<T> {
  const PlatformAdaptiveDropdownItem({
    required this.text,
    required this.value,
  });

  final String text;
  final T value;
}

class PlatformAdaptiveDropdown<T> extends StatelessWidget {
  const PlatformAdaptiveDropdown({
    required this.items,
    required this.onSelected,
    this.initialSelection,
    this.hint,
    super.key,
  });

  final List<PlatformAdaptiveDropdownItem<T>> items;
  final ValueChanged<T?> onSelected;
  final T? initialSelection;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) return _buildCupertinoPicker(context);
    return _buildMaterialDropdown(context);
  }

  Widget _buildMaterialDropdown(BuildContext context) {
    return DropdownMenu<T>(
      initialSelection: initialSelection,
      hintText: hint ?? 'Select',
      onSelected: onSelected,
      dropdownMenuEntries: items
          .map(
            (item) => DropdownMenuEntry<T>(
              value: item.value,
              label: item.text,
            ),
          )
          .toList(),
    );
  }

  Widget _buildCupertinoPicker(BuildContext context) {
    final selectedItem =
        items.cast<PlatformAdaptiveDropdownItem<T>?>().firstWhere(
              (element) => element?.value == initialSelection,
              orElse: () => null,
            );

    final displayText = selectedItem?.text ?? hint ?? 'Select';
    final isPlaceholder = selectedItem == null;

    return Semantics(
      button: true,
      label: displayText,
      child: GestureDetector(
        onTap: () => _showCupertinoModal(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                displayText,
                overflow: TextOverflow.ellipsis,
                style: isPlaceholder
                    ? TextStyle(
                        color: CupertinoColors.placeholderText
                            .resolveFrom(context),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: SoliplexSpacing.s1),
            Icon(
              CupertinoIcons.chevron_down,
              size: 16,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showCupertinoModal(BuildContext context) {
    var selectedIndex =
        items.indexWhere((item) => item.value == initialSelection);
    if (selectedIndex == -1) selectedIndex = 0;

    showCupertinoModalPopup<T>(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            _buildPickerHeader(context),
            Expanded(
              child: CupertinoPicker(
                scrollController:
                    FixedExtentScrollController(initialItem: selectedIndex),
                itemExtent: 32,
                onSelectedItemChanged: (index) {
                  onSelected(items[index].value);
                },
                children: items
                    .map((item) => Center(child: Text(item.text)))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: CupertinoColors.tertiarySystemFill,
        border: Border(
          bottom: BorderSide(color: CupertinoColors.separator, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          CupertinoButton(
            child: const Text('Done'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
