enum Provider {
  coop('Coop'),
  rema('Rema'),
  trumf('Trumf');

  const Provider(this._name);

  final String _name;

  @override
  toString() {
    return _name;
  }
}
