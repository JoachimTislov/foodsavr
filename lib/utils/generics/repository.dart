class GenericRepository<T> {
  final List<T> _items = [];

  void addItem(T item) {
    _items.add(item);
  }

  List<T> getItems() {
    return _items;
  }

  T? getItemAt(int index) {
    if (index < 0 || index >= _items.length) {
      return null;
    }
    return _items[index];
  }

  void removeItem(T item) {
    _items.remove(item);
  }
}
