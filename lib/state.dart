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
  SlidesModel();

  DateTime _date = nextSunday();

  List<DeckItem> _items = [];
  DeckItem _lastRemovedItem;
  int _lastRemovedIndex;

  UnmodifiableListView<DeckItem> get items => UnmodifiableListView(_items);
  DateTime get date => _date;

  Map<String, dynamic> toJson() => {
        'date': _date.toIso8601String().substring(0, 10),
        'items': _items.map((item) => item.toFullJson()).toList(),
      };

  SlidesModel.fromJson(Map<String, dynamic> json) {
    _date = DateTime.parse(json['date'] as String);

    final items = json['items'] as List;
    _items = items
        .map((itemJson) {
          switch (itemJson['type']) {
            case 'SONG':
              return SongDeckItem(Song.fromJson(itemJson));
            case 'PSALM':
              return PsalmDeckItem();
            case 'ACCLAMATION':
              return AcclamationDeckItem();
            default:
              return null;
          }
        })
        .where((item) => item != null)
        .toList();
  }

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
    final kyrieIndex =
        _items.indexWhere((item) => item.id == OrdinaryItems.kyrie.id);
    final index = min(
      _items.length,
      kyrieIndex >= 0 ? kyrieIndex + 1 : 1,
    );
    _items.insertAll(index, [PsalmDeckItem(), AcclamationDeckItem()]);
    notifyListeners();
  }

  removeLiturgy() {
    _items.removeWhere((item) => item is LiturgyDeckItem);
    notifyListeners();
  }

  bool hasOrdinary() {
    return _items.any((item) => item is SongDeckItem && item.song.isOrdinary);
  }

  addOrdinary() {
    final kyrieItem = SongDeckItem(OrdinaryItems.kyrie);
    final sanctusItem = SongDeckItem(OrdinaryItems.sanctus);
    final agnusItem = SongDeckItem(OrdinaryItems.agnus);

    _items.insert(min(_items.length, 1), kyrieItem);
    _items.insertAll(max(0, _items.length - 3), [sanctusItem, agnusItem]);
    notifyListeners();
  }

  removeOrdinary() {
    _items.removeWhere((item) => item is SongDeckItem && item.song.isOrdinary);
    notifyListeners();
  }

  setItems(List<DeckItem> items) {
    _items.clear();
    _items.addAll(items);
    notifyListeners();
  }

  setDate(DateTime date) {
    _date = date;
    notifyListeners();
  }
}
