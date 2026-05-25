enum GroceryStoreProvider { coop, rema1000, trumf }

extension GroceryStoreProviderX on GroceryStoreProvider {
  String get storageKey => switch (this) {
    GroceryStoreProvider.coop => 'coop',
    GroceryStoreProvider.rema1000 => 'rema1000',
    GroceryStoreProvider.trumf => 'trumf',
  };

  String get translationKey => switch (this) {
    GroceryStoreProvider.coop => 'settings.integrations.providers.coop',
    GroceryStoreProvider.rema1000 => 'settings.integrations.providers.rema1000',
    GroceryStoreProvider.trumf => 'settings.integrations.providers.trumf',
  };
}
