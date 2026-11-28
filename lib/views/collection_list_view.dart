import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../controllers/collection_list_controller.dart';
import '../interfaces/i_auth_service.dart';
import '../models/collection_model.dart';
import '../service_locator.dart';
import '../services/collection_service.dart';
import '../utils/collection_types.dart';
import '../widgets/collection/collection_card.dart';
import '../widgets/collection/collection_kickstart_card.dart';
import '../widgets/common/master_detail_layout.dart';
import '../widgets/common/refresh_on_return.dart';
import '../widgets/common/retry_scaffold.dart';
import 'collection_detail_view.dart';
import 'collection_form_view.dart';

class CollectionListView extends StatefulWidget {
  final CollectionType? typeFilter;
  const CollectionListView({super.key, this.typeFilter});

  @override
  State<CollectionListView> createState() => _CollectionListViewState();
}

class _CollectionListViewState extends State<CollectionListView> {
  late final CollectionService _collectionService;
  late final CollectionListController _controller;
  Collection? _selected;
  Map<String, int> _productCounts = {};
  int _fetchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _collectionService = getIt<CollectionService>();
    _controller = CollectionListController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // similar to collection detail view
  Future<void> _fetchCollections() async {
    final generation = ++_fetchGeneration;
    final userId = getIt<IAuthService>().getUserId();
    if (userId == null) {
      _controller.clear();
      return;
    }
    final all = await _collectionService.getCollectionsForUser(userId);
    final counts = await _collectionService.resolveCounts(userId, all);
    if (!mounted || generation != _fetchGeneration) return;
    _productCounts = counts;
    _controller.loadCollections(all, widget.typeFilter);
  }

  Future<void> _refreshAfterChange() async {
    if (!mounted) return;
    try {
      await _fetchCollections();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('collection.loadError'.tr()),
          action: SnackBarAction(
            label: 'common.tryAgain'.tr(),
            onPressed: _refreshAfterChange,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final master = RetryScaffold(
      errorMessage: 'collection.loadError'.tr(),
      onRefresh: _fetchCollections,
      fetchOnInit: true,
      isBodyScrollable: true,
      floatingActionButton: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => _controller.collections.isEmpty
            ? const SizedBox.shrink()
            : FloatingActionButton(
                heroTag:
                    'collection_list_fab_${widget.typeFilter?.name ?? 'all'}',
                onPressed: () async {
                  final result = await CollectionFormView.show(
                    context,
                    type: widget.typeFilter ?? CollectionType.inventory,
                  );
                  if (!mounted) return;
                  if (result == true) {
                    await _refreshAfterChange();
                  }
                },
                child: const Icon(Icons.add),
              ),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.only(
                  left: 24,
                  top: MediaQuery.of(context).padding.top + 16,
                  right: 16,
                  bottom: 16,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.typeFilter == CollectionType.shoppingList
                          ? 'dashboard.shoppingList'.tr()
                          : 'dashboard.myInventory'.tr(),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_controller.collections.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                // This tab stays alive while a collection can be created
                // from another one.
                child: RefreshOnReturn(
                  onReturn: _refreshAfterChange,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: CollectionKickstartCard(
                        type: widget.typeFilter ?? CollectionType.inventory,
                        onChanged: _refreshAfterChange,
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(top: 12, bottom: 20),
                sliver: SliverList.builder(
                  itemCount: _controller.collections.length,
                  itemBuilder: (context, index) {
                    final collection = _controller.collections[index];
                    return CollectionCard(
                      collection: collection,
                      productCount: _productCounts[collection.id] ?? 0,
                      onTap: () => _navigateToCollectionDetail(collection),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
    final selected = _selected;
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => MasterDetailLayout(
        enabled: _controller.collections.isNotEmpty,
        master: master,
        detail: selected == null
            ? null
            : CollectionDetailView(
                key: ValueKey(selected.id),
                collection: selected,
                onChanged: _onSelectedChanged,
              ),
      ),
    );
  }

  void _onSelectedChanged(Collection? collection) {
    setState(() => _selected = collection);
    _refreshAfterChange();
  }

  Future<void> _navigateToCollectionDetail(Collection collection) async {
    if (MasterDetailLayout.isSplit(context)) {
      setState(() => _selected = collection);
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CollectionDetailView(collection: collection),
      ),
    );
    if (mounted) await _refreshAfterChange();
  }
}
