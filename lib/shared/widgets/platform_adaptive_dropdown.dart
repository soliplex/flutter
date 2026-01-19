import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
      hintText: hint,
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
    final selectedItem = items.firstWhere(
      (element) => element.value == initialSelection,
      orElse: () => items.first,
    );

    return GestureDetector(
      onTap: () => _showCupertinoModal(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: CupertinoColors.separator, width: 0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              hint ?? 'Select',
              style: const TextStyle(color: CupertinoColors.inactiveGray),
            ),
            Text(
              selectedItem.text,
              style: const TextStyle(color: CupertinoColors.activeBlue),
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
