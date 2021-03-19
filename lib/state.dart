import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import './model.dart';

nextSunday() {
  final now = DateTime.now();
  if (now.weekday == DateTime.sunday) {
    return now;
  }
  return now.add(Duration(days: 7 - now.weekday));
}

class SlidesModel extends ChangeNotifier {
  DateTime _date = nextSunday();

  List<DeckItem> _items = [];
  DeckItem _lastRemovedItem;
  int _lastRemovedIndex;

  UnmodifiableListView<DeckItem> get items => UnmodifiableListView(_items);
  DateTime get date => _date;

  addItem(DeckItem item) {
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

  bool containsSong(String id) {
    return _items.any((item) => item.id == id);
  }

  bool hasLiturgy() {
    return _items.any((item) => item is LiturgyDeckItem);
  }

  addLiturgy() {
    final index = min(_items.length, 1);
    _items.insertAll(index, [PsalmDeckItem(), AcclamationDeckItem()]);
    notifyListeners();
  }

  setDate(DateTime date) {
    _date = date;
  }
}
