import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';

import './api.dart';
import './model.dart';

class SlidesModel extends ChangeNotifier implements LiturgyHolder {
  SlidesModel() {
    updateLiturgy();
  }

  DateTime _date = DateTime.now();
  List<DeckItem> _items = [];
  DeckItem? _lastRemovedItem;
  int? _lastRemovedIndex;

  UnmodifiableListView<DeckItem> get items => UnmodifiableListView(_items);
  DateTime get date => _date;

  @override
  Liturgy? liturgy;

  bool isLivePaused = false;
  LiveResponse? live;

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
              return PsalmDeckItem(this);
            case 'ACCLAMATION':
              return AcclamationDeckItem(this);
            case 'TEXT':
              return TextDeckItem(itemJson['contents']);
            default:
              return null;
          }
        })
        .whereType<DeckItem>()
        .toList();
  }

  addItem(DeckItem item) {
    _items.add(item);
    notifyListeners();
  }

  replaceItem(int index, DeckItem item) {
    _items[index] = item;
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

    _items.insert(_lastRemovedIndex!, _lastRemovedItem!);
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
    _items.insertAll(index, [PsalmDeckItem(this), AcclamationDeckItem(this)]);
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
    updateLiturgy();
    notifyListeners();
  }

  removeOrdinary() {
    _items.removeWhere((item) => item is SongDeckItem && item.song.isOrdinary);
    notifyListeners();
  }

  addText(String contents) {
    _items.add(TextDeckItem(contents));
    notifyListeners();
  }

  updateText(int index, String newContents) {
    final item = _items[index];
    if (item is TextDeckItem) {
      item.contents = newContents;
    }
    notifyListeners();
  }

  setItems(List<DeckItem> items) {
    _items.clear();
    _items.addAll(items);
    notifyListeners();
  }

  Future<bool> setDate(DateTime date) async {
    final previousDate = _date;
    _date = date;

    try {
      await updateLiturgy();
    } on ApiError {
      _date = previousDate;
      notifyListeners();
      return false;
    }

    notifyListeners();
    return true;
  }

  updateLiturgy() async {
    liturgy = await getLiturgy(date);
    notifyListeners();
  }

  setRawVerses(int index, List<String> verses) {
    final item = _items[index];
    if (item is SongDeckItem) {
      item.rawVerses = verses;
    }
    notifyListeners();
  }

  setSelectedVerses(int index, List<bool> selectedVerses) {
    final item = _items[index];
    if (item is SongDeckItem) {
      item.selectedVerses = selectedVerses;
    }
    notifyListeners();
  }

  updateSelectedVerses(int index, int verseIndex, bool value) {
    final item = _items[index];
    if (item is SongDeckItem) {
      item.selectedVerses![verseIndex] = value;
    }
    notifyListeners();
  }

  bool isValid() {
    return _items.isNotEmpty &&
        !_items.any((item) => item is UnresolvedDeckItem);
  }

  setIsLivePaused(bool isPaused) {
    isLivePaused = isPaused;
    notifyListeners();
  }

  setLiveSession(LiveResponse live) {
    this.live = live;
    notifyListeners();
  }
}
