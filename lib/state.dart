import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import './api.dart';
import './model.dart';

class SlidesModel extends ChangeNotifier implements LiturgyHolder {
  SlidesModel() {
    updateLiturgy();
    loadUser();
  }

  DateTime _date = DateTime.now();
  List<DeckItem> _items = [];
  DeckItem? _lastRemovedItem;
  int? _lastRemovedIndex;

  UnmodifiableListView<DeckItem> get items => UnmodifiableListView(_items);
  DateTime get date => _date;

  BootstrapResponse? _bootstrap;
  BootstrapResponse? get bootstrap => _bootstrap;

  User? _user;
  User? get user => _user;

  Team? _currentTeam;
  Team? get currentTeam => _currentTeam;

  @override
  Liturgy? liturgy;

  bool isLiveConnected = false;

  Map<String, dynamic> toJson() => {
        'date': _date.toIso8601String().substring(0, 10),
        'items': _items.map((item) => item.toFullJson()).toList(),
        'currentTeam': _currentTeam?.toJson(),
      };

  void loadFromJson(Map<String, dynamic> json) {
    final date = DateTime.parse(json['date'] as String);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (date.isBefore(today)) {
      return;
    }

    _date = date;

    final items = json['items'] as List;
    _items = items
        .map((itemJson) {
          switch (itemJson['type']) {
            case 'SONG':
              return SongDeckItem.fromJson(itemJson);
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

    _currentTeam =
        json['currentTeam'] != null ? Team.fromJson(json['currentTeam']) : null;

    notifyListeners();
  }

  Future<void> loadUser() async {
    final storage = FlutterSecureStorage();
    final hasToken = await storage.containsKey(key: 'accessToken');
    if (hasToken) {
      try {
        final user = await getAuthMe();
        setUser(user);
      } catch (e) {
        setUser(null);
        await storeAuthResponse(null);
      }
    }
  }

  void addItem(DeckItem item) {
    _items.add(item);
    notifyListeners();
  }

  void replaceItem(int index, DeckItem item) {
    _items[index] = item;
    notifyListeners();
  }

  void removeItem(int index) {
    _lastRemovedIndex = index;
    _lastRemovedItem = _items.removeAt(index);
    notifyListeners();
  }

  void removeItemById(String id) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index >= 0) {
      removeItem(index);
    }
  }

  void removeAllItems() {
    _items.clear();
    notifyListeners();
  }

  void undoRemoveItem() {
    if (_lastRemovedIndex == null || _lastRemovedItem == null) {
      return;
    }

    _items.insert(_lastRemovedIndex!, _lastRemovedItem!);
    _lastRemovedIndex = null;
    _lastRemovedItem = null;
    notifyListeners();
  }

  void reorderItems(int oldIndex, int newIndex) {
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

  void addLiturgy() {
    final kyrieIndex =
        _items.indexWhere((item) => item.id == OrdinaryItems.kyrie.id);
    final index = min(
      _items.length,
      kyrieIndex >= 0 ? kyrieIndex + 1 : 1,
    );
    _items.insertAll(index, [PsalmDeckItem(this), AcclamationDeckItem(this)]);
    notifyListeners();
  }

  void removeLiturgy() {
    _items.removeWhere((item) => item is LiturgyDeckItem);
    notifyListeners();
  }

  bool hasOrdinary() {
    return _items.any((item) => item is SongDeckItem && item.song.isOrdinary);
  }

  void addOrdinary() {
    final kyrieItem = SongDeckItem(OrdinaryItems.kyrie);
    final sanctusItem = SongDeckItem(OrdinaryItems.sanctus);
    final agnusItem = SongDeckItem(OrdinaryItems.agnus);

    final numItems = _items.length;

    if (numItems <= 1) {
      _items.insertAll(numItems, [kyrieItem, sanctusItem, agnusItem]);
    } else if (numItems < 5) {
      _items.insert(1, kyrieItem);
      _items.insertAll(3, [sanctusItem, agnusItem]);
    } else {
      _items.insert(1, kyrieItem);
      _items.insertAll(_items.length - 3, [sanctusItem, agnusItem]);
    }
    notifyListeners();
  }

  void removeOrdinary() {
    _items.removeWhere((item) => item is SongDeckItem && item.song.isOrdinary);
    notifyListeners();
  }

  void addText(String contents) {
    _items.add(TextDeckItem(contents));
    notifyListeners();
  }

  void updateText(int index, String newContents) {
    final item = _items[index];
    if (item is TextDeckItem) {
      item.contents = newContents;
    }
    notifyListeners();
  }

  void setItems(List<DeckItem> items) {
    _items.clear();
    _items.addAll(items);
    notifyListeners();
  }

  void setBootstrap(BootstrapResponse bootstrap) {
    _bootstrap = bootstrap;
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

  Future<void> updateLiturgy() async {
    liturgy = await getLiturgy(date);
    notifyListeners();
  }

  void setRawVerses(int index, List<String> verses) {
    final item = _items[index];
    if (item is SongDeckItem) {
      item.rawVerses = verses;
    }
    notifyListeners();
  }

  void setSelectedVerses(int index, List<bool> selectedVerses) {
    final item = _items[index];
    if (item is SongDeckItem) {
      item.selectedVerses = selectedVerses;
    }
    notifyListeners();
  }

  void updateSelectedVerses(int index, int verseIndex, bool value) {
    final item = _items[index];
    if (item is SongDeckItem) {
      item.selectedVerses![verseIndex] = value;
    }
    notifyListeners();
  }

  Future<void> reloadSong(String id, String? newId) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index >= 0) {
      final song = await getSong(newId ?? id);
      _items[index] = SongDeckItem(song);
    }
    notifyListeners();
  }

  bool isValid() {
    return _items.isNotEmpty &&
        !_items.any((item) => item is UnresolvedDeckItem);
  }

  // TODO
  void setIsLiveConnected(bool isConnected) {
    isLiveConnected = isConnected;
    notifyListeners();
  }

  Future<void> setUser(User? user) async {
    _user = user;
    notifyListeners();

    final List<Team> teams = user != null ? await getTeams() : [];
    if (teams.isNotEmpty) {
      final team = teams.firstWhere(
        (team) => team.id == _currentTeam?.id,
        orElse: () => teams.first,
      );
      setCurrentTeam(team);
    } else {
      setCurrentTeam(null);
    }
  }

  void setCurrentTeam(Team? team) {
    _currentTeam = team;
    notifyListeners();
  }
}
