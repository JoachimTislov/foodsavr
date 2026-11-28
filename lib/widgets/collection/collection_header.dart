import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/collection_config.dart';
import '../../constants/material3_config.dart';
import '../../models/collection_model.dart';

/// Header widget for collection detail view. The title is edited in place:
/// tapping it opens a text field that saves on Enter or blur and cancels on
/// Escape.
class CollectionHeader extends StatefulWidget {
  final Collection collection;
  final int productCount;

  /// Saves a new name. A blank or unchanged name needs no call.
  final Future<void> Function(String name)? onRename;

  /// Opens the title in edit mode, with its text selected.
  final bool startEditing;
  final VoidCallback? onAdd;
  final VoidCallback? onDelete;

  const CollectionHeader({
    super.key,
    required this.collection,
    required this.productCount,
    this.onRename,
    this.startEditing = false,
    this.onAdd,
    this.onDelete,
  });

  @override
  State<CollectionHeader> createState() => _CollectionHeaderState();
}

class _CollectionHeaderState extends State<CollectionHeader> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.collection.name);
    _focus.addListener(_onFocusChanged);
    if (widget.startEditing && widget.onRename != null) _startEditing();
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _startEditing() {
    final name = widget.collection.name;
    _editing = true;
    _controller.value = TextEditingValue(
      text: name,
      selection: TextSelection(baseOffset: 0, extentOffset: name.length),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editing) _focus.requestFocus();
    });
  }

  void _onFocusChanged() {
    if (!_focus.hasFocus && _editing) _commit();
  }

  void _commit() {
    final name = _controller.text.trim();
    setState(() => _editing = false);
    if (name.isEmpty || name == widget.collection.name) return;
    widget.onRename?.call(name);
  }

  void _cancel() => setState(() => _editing = false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final titleStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
      color: colorScheme.onPrimaryContainer,
    );
    final description = widget.collection.description;

    final Widget title = _editing
        ? Focus(
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                _cancel();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              style: titleStyle,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _commit(),
              decoration: const InputDecoration(
                isDense: true,
                border: UnderlineInputBorder(),
              ),
            ),
          )
        : Tooltip(
            message: 'a11y.editCollection'.tr(),
            child: InkWell(
              onTap: widget.onRename == null
                  ? null
                  : () => setState(_startEditing),
              child: Text(
                widget.collection.name,
                style: titleStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: Material3Config.spacing16,
        top: MediaQuery.of(context).padding.top + Material3Config.spacing12,
        right: Material3Config.spacing8,
        bottom: Material3Config.spacing16,
      ),
      decoration: BoxDecoration(
        color: CollectionConfig.getColor(widget.collection.type, colorScheme),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(Material3Config.radiusLarge),
          bottomRight: Radius.circular(Material3Config.radiusLarge),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(child: title),
                    const SizedBox(width: Material3Config.spacing12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Material3Config.spacing8,
                        vertical: Material3Config.spacing4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(
                          Material3Config.radiusSmall,
                        ),
                      ),
                      child: Text(
                        'collection.items_count'.tr(
                          namedArgs: {'count': widget.productCount.toString()},
                        ),
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    if (widget.onAdd != null)
                      IconButton(
                        icon: Icon(
                          Icons.add,
                          color: colorScheme.onPrimaryContainer,
                        ),
                        tooltip: 'product.add'.tr(),
                        onPressed: widget.onAdd,
                      ),
                  ],
                ),
              ),
              if (widget.onDelete != null)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  tooltip: 'a11y.deleteCollection'.tr(),
                  onPressed: widget.onDelete,
                ),
            ],
          ),
          if (description != null && description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Material3Config.spacing4),
              child: Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
