import 'package:flutter/material.dart';

class DropdownModel<T> {
  final String label;
  final T value;
  final String? description;

  const DropdownModel({required this.label, required this.value, this.description});
}

class AppDropdownField<T> extends StatefulWidget {
  final List<DropdownModel<T>> items;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final String? label;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final String? helperText;
  final String? errorText;
  final bool isDense;
  final double? menuMaxHeight;
  final TextStyle? style;
  final TextStyle? labelStyle;
  final TextStyle? helperStyle;
  final TextStyle? errorStyle;
  final bool enabled;
  final String? Function(T?)? validator;
  final Color? prefixIconColor;
  final Color? suffixIconColor;
  final Color? borderColor;
  final Color? focusedBorderColor;
  final Color? errorBorderColor;
  final double borderRadius;
  final EdgeInsetsGeometry? contentPadding;
  final bool filled;
  final Color? fillColor;

  const AppDropdownField({
    super.key,
    required this.items,
    required this.value,
    this.onChanged,
    this.label,
    this.prefixIcon,
    this.suffixIcon,
    this.helperText,
    this.errorText,
    this.isDense = true,
    this.menuMaxHeight = 300,
    this.style,
    this.labelStyle,
    this.helperStyle,
    this.errorStyle,
    this.enabled = true,
    this.validator,
    this.prefixIconColor,
    this.suffixIconColor,
    this.borderColor,
    this.focusedBorderColor,
    this.errorBorderColor,
    this.borderRadius = 12,
    this.contentPadding,
    this.filled = true,
    this.fillColor,
  });

  @override
  State<AppDropdownField<T>> createState() => _AppDropdownFieldState<T>();
}

class _AppDropdownFieldState<T> extends State<AppDropdownField<T>> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  bool _isOpen = false;
  T? _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.value;
  }

  @override
  void didUpdateWidget(AppDropdownField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _selectedValue = widget.value;
    }
  }

  void _toggleDropdown() {
    if (!widget.enabled) return;

    if (_isOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomSpace = screenHeight - position.dy - size.height;
    final showAbove = bottomSpace < (widget.menuMaxHeight ?? 300);

    _overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            width: size.width,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, showAbove ? -(size.height + 8) : (size.height)),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                child: Container(
                  constraints: BoxConstraints(maxHeight: widget.menuMaxHeight ?? 300),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: widget.items.length,
                    itemBuilder: (context, index) {
                      final item = widget.items[index];
                      final isSelected = item.value == _selectedValue;
                      return ListTile(
                        dense: true,
                        selected: isSelected,
                        selectedTileColor: Colors.blue.withOpacity(0.1),
                        leading: Checkbox(
                          value: isSelected,
                          onChanged: (bool? value) {
                            if (value == true) {
                              setState(() {
                                _selectedValue = item.value;
                              });
                              widget.onChanged?.call(item.value);
                              _removeOverlay();
                            }
                          },
                        ),
                        title: Text(
                          item.label,
                          style: TextStyle(
                            color: isSelected ? Colors.blue : Colors.black,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing:
                            item.description != null
                                ? Text(item.description!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
                                : null,
                        onTap: () {
                          setState(() {
                            _selectedValue = item.value;
                          });
                          widget.onChanged?.call(item.value);
                          _removeOverlay();
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isOpen = true;
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _isOpen = false;
    });
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedItem = widget.items.firstWhere(
      (item) => item.value == _selectedValue,
      orElse: () => widget.items.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: widget.labelStyle ?? const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
        ],
        CompositedTransformTarget(
          link: _layerLink,
          child: GestureDetector(
            onTap: _toggleDropdown,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: widget.borderColor ?? Colors.grey.shade400),
                borderRadius: BorderRadius.circular(widget.borderRadius),
                color: widget.fillColor ?? Colors.grey.shade50,
              ),
              child: Padding(
                padding: widget.contentPadding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    if (widget.prefixIcon != null) ...[
                      Icon(widget.prefixIcon, color: widget.prefixIconColor ?? Colors.black, size: 20),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            selectedItem.label,
                            style: widget.style ?? const TextStyle(fontSize: 12, color: Colors.black),
                          ),
                          if (selectedItem.description != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              selectedItem.description!,
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      _isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                      color: widget.suffixIconColor ?? Colors.black,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (widget.helperText != null) ...[
          const SizedBox(height: 4),
          Text(widget.helperText!, style: widget.helperStyle ?? TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ],
        if (widget.errorText != null) ...[
          const SizedBox(height: 4),
          Text(widget.errorText!, style: widget.errorStyle ?? TextStyle(fontSize: 10, color: theme.colorScheme.error)),
        ],
      ],
    );
  }
}
