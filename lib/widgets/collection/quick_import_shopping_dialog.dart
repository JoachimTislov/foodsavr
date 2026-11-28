import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../constants/product_categories.dart';
import '../../interfaces/i_auth_service.dart';
import '../../models/collection_model.dart';
import '../../models/product_model.dart';
import '../../service_locator.dart';
import '../../services/collection_service.dart';
import '../../services/product_service.dart';
import '../../utils/collection_types.dart';
import '../../utils/shopping_list_parser.dart';
import '../../utils/user_error.dart';
import '../common/adaptive_sheet.dart';
import '../product/product_icon.dart';

/// Modal for pasting or typing a free-form shopping list and importing all
/// detected items in one step.
class QuickImportShoppingDialog extends StatelessWidget {
  final String? collectionId;

  const QuickImportShoppingDialog({super.key, this.collectionId});

  /// Opens the quick-import modal.
  ///
  /// When [collectionId] is omitted, the modal loads the user's shopping lists
  /// so they can choose a target list. Returns `true` when items were imported.
  static Future<bool?> show(BuildContext context, {String? collectionId}) {
    return AdaptiveSheet.show<bool>(
      context,
      builder: (_) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: _QuickImportContent(collectionId: collectionId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _QuickImportContent extends StatefulWidget {
  final String? collectionId;

  const _QuickImportContent({this.collectionId});

  @override
  State<_QuickImportContent> createState() => _QuickImportContentState();
}

class _QuickImportContentState extends State<_QuickImportContent> {
  late final ProductService _productService;
  late final CollectionService _collectionService;
  late final IAuthService _authService;
  late final String? _userId;

  final TextEditingController _inputController = TextEditingController();
  final Set<String> _dismissedKeys = {};
  List<ParsedShoppingItem> _parsedItems = const [];

  List<Collection>? _shoppingLists;
  String? _selectedCollectionId;
  bool _loadingLists = false;
  bool _listsLoadFailed = false;
  bool _isSaving = false;

  String? get _effectiveCollectionId =>
      widget.collectionId ?? _selectedCollectionId;

  List<ParsedShoppingItem> get _visibleItems => [
    for (final item in _parsedItems)
      if (!_dismissedKeys.contains(item.name.toLowerCase())) item,
  ];

  @override
  void initState() {
    super.initState();
    _productService = getIt<ProductService>();
    _collectionService = getIt<CollectionService>();
    _authService = getIt<IAuthService>();
    _userId = _authService.getUserId();
    _selectedCollectionId = widget.collectionId;
    if (widget.collectionId == null) {
      _loadShoppingLists();
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _loadShoppingLists() async {
    setState(() {
      _loadingLists = true;
      _listsLoadFailed = false;
    });
    try {
      final lists = await _collectionService.getCollectionsForUser(
        _userId,
        type: CollectionType.shoppingList,
      );
      if (!mounted) return;
      setState(() {
        _shoppingLists = lists;
        _selectedCollectionId = lists.isNotEmpty ? lists.first.id : null;
        _loadingLists = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingLists = false;
        _listsLoadFailed = true;
      });
    }
  }

  void _onInputChanged(String value) {
    final parsed = ShoppingListParser.parse(value);
    final presentKeys = {for (final item in parsed) item.name.toLowerCase()};
    setState(() {
      _parsedItems = parsed;
      _dismissedKeys.removeWhere((key) => !presentKeys.contains(key));
    });
  }

  void _removeItem(ParsedShoppingItem item) {
    setState(() => _dismissedKeys.add(item.name.toLowerCase()));
  }

  Future<void> _importItems() async {
    final userId = _userId;
    final targetId = _effectiveCollectionId;
    final items = _visibleItems;
    if (userId == null || targetId == null || items.isEmpty || _isSaving) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final createdIds = <String>[];
      for (final item in items) {
        final product = Product(
          id: '',
          name: item.name,
          description: '',
          userId: userId,
          nonExpiringQuantity: item.quantity,
          category: item.category,
          registryType: 'current',
        );
        final saved = await _productService.addProduct(product);
        createdIds.add(saved.id);
      }
      await _collectionService.addProductsToCollection(targetId, createdIds);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'collection.quickImport.imported'.plural(
              items.length,
              name: 'count',
            ),
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e, stack) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userErrorMessage(
                e,
                'collection.quickImport.importError'.tr(),
                stack,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final items = _visibleItems;
    final canImport =
        !_isSaving && items.isNotEmpty && _effectiveCollectionId != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ExcludeSemantics(
              child: Icon(Icons.playlist_add, color: colorScheme.primary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'collection.quickImport.title'.tr(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'common.close'.tr(),
              onPressed: _isSaving
                  ? null
                  : () => Navigator.of(context).pop(false),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'collection.quickImport.subtitle'.tr(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (widget.collectionId == null) ...[
          _TargetShoppingListSelector(
            loading: _loadingLists,
            loadFailed: _listsLoadFailed,
            lists: _shoppingLists,
            selectedId: _selectedCollectionId,
            onChanged: (id) => setState(() => _selectedCollectionId = id),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _inputController,
          autofocus: true,
          enabled: !_isSaving,
          minLines: 3,
          maxLines: 6,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: 'collection.quickImport.placeholder'.tr(),
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          onChanged: _onInputChanged,
        ),
        const SizedBox(height: 12),
        Text(
          'collection.quickImport.previewCount'.plural(
            items.length,
            name: 'count',
          ),
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (items.isNotEmpty)
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _ParsedItemPreviewRow(
                    item: item,
                    enabled: !_isSaving,
                    onRemove: () => _removeItem(item),
                  );
                },
              ),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: canImport ? _importItems : null,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.playlist_add_check),
          label: Text(
            'collection.quickImport.importButton'.plural(
              items.length,
              name: 'count',
            ),
          ),
        ),
      ],
    );
  }
}

class _TargetShoppingListSelector extends StatelessWidget {
  final bool loading;
  final bool loadFailed;
  final List<Collection>? lists;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _TargetShoppingListSelector({
    required this.loading,
    required this.loadFailed,
    required this.lists,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (loading) {
      return const LinearProgressIndicator();
    }
    if (loadFailed) {
      return Text(
        'collection.loadError'.tr(),
        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.error),
      );
    }
    final available = lists ?? const [];
    if (available.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'collection.quickImport.noShoppingLists'.tr(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: selectedId,
      decoration: InputDecoration(
        labelText: 'collection.quickImport.targetList'.tr(),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        for (final list in available)
          DropdownMenuItem(value: list.id, child: Text(list.name)),
      ],
      onChanged: onChanged,
    );
  }
}

class _ParsedItemPreviewRow extends StatelessWidget {
  final ParsedShoppingItem item;
  final bool enabled;
  final VoidCallback onRemove;

  const _ParsedItemPreviewRow({
    required this.item,
    required this.enabled,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          ProductIcon(name: item.name, category: item.category, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.category != null)
                  Text(
                    ProductCategory.label(item.category!),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'x${item.quantity}', // l10n-ignore
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'collection.quickImport.removeItem'.tr(),
            onPressed: enabled ? onRemove : null,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
