class SortableShufflableMap {
  final Map<String, bool> _map = {};
  final List<String> _keys = [];

  void addAll(Map<String, bool> values) {
    _map.clear();
    _map.addAll(values);
    _keys.clear();
    _keys.addAll(values.keys);
  }

  void add(String key, bool value) {
    if (!_map.containsKey(key)) {
      _keys.add(key);
    }
    _map[key] = value;
  }

  void remove(String key) {
    if (_map.containsKey(key)) {
      _map.remove(key);
      _keys.remove(key);
    }
  }

  void updateValue(String key, bool value) {
    if (_map.containsKey(key)) {
      _map[key] = value;
    }
  }

  void updateValueByIndex(int index, bool value) {
    String key = _keys[index];
    updateValue(key, value);
  }

  int getLength() => _keys.length;

  String getKey(int index) => _keys[index];

  bool? get(String key) => _map[key];

  bool? getByIndex(int index) => _map[_keys[index]];

  void sortByBool() {
    _keys.sort((a, b) {
      if (_map[b]! && !_map[a]!) return 1;
      if (!_map[b]! && _map[a]!) return -1;
      return 0;
    });
  }

  void shuffleTrueValues() {
    List<String> trueKeys = _keys.where((key) => _map[key] == true).toList();
    trueKeys.shuffle();
    int trueIndex = 0;
    for (int i = 0; i < _keys.length; i++) {
      if (_map[_keys[i]] == true) {
        _keys[i] = trueKeys[trueIndex++];
      }
    }
  }

  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final String key = _keys.removeAt(oldIndex);
    _keys.insert(newIndex, key);
  }

  List<MapEntry<String, bool>> get entries {
    return _keys.map((key) => MapEntry(key, _map[key]!)).toList();
  }
}
