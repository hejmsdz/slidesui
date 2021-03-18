import 'dart:collection';
import 'package:flutter/material.dart';
import './model.dart';

class SlidesModel extends ChangeNotifier {
  List<Song> _items = [];
  Song _lastRemovedItem;
  int _lastRemovedIndex;

  UnmodifiableListView<Song> get items => UnmodifiableListView(_items);

  addItem(Song item) {
    _items.add(item);
    notifyListeners();
  }

  removeItem(int index) {
    _lastRemovedIndex = index;
    _lastRemovedItem = _items.removeAt(index);
    notifyListeners();
  }

  removeItemById(String id) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index >= 0) {
      removeItem(index);
    }
  }

  undoRemoveItem() {
    if (_lastRemovedIndex == null || _lastRemovedItem == null) {
      return;
    }

    _items.insert(_lastRemovedIndex, _lastRemovedItem);
    _lastRemovedIndex = null;
    _lastRemovedItem = null;
    notifyListeners();
  }

  reorderItems(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);
    notifyListeners();
  }

  containsSong(String id) {
    return _items.any((item) => item.id == id);
  }
}
