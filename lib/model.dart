import 'dart:convert';

import './strings.dart';

class Song {
  final String id;
  final String title;
  final String number;
  final String slug;
  final bool isOrdinary;

  Song(this.id, this.title, this.number, this.slug, [this.isOrdinary = false]);

  Song.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        title = json['title'],
        number = json['number'],
        slug = json['slug'],
        isOrdinary = json['isOrdinary'] ?? false;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'number': number,
        'slug': slug,
        'isOrdinary': isOrdinary,
      };
}

abstract class OrdinaryItems {
  static Song kyrie = Song(
      'f29bb232-be0c-4998-9142-5524c38ec9d7', 'Kyrie eleison', '', '', true);
  static Song sanctus =
      Song('bf218c0a-ac22-4049-85d0-6072b2830f15', 'Sanctus', '', '', true);
  static Song agnus =
      Song('548120f1-604c-4386-ae89-f9737aac7ae4', 'Agnus Dei', '', '', true);
}

abstract class DeckItem {
  String get id;
  String get title;
  String get number;

  String get removedMessage;

  Map<String, dynamic> toJson();
  Map<String, dynamic> toFullJson();
}

class SongDeckItem implements DeckItem {
  SongDeckItem(this.song);

  Song song;
  String get id => song.id;
  String get title => song.title;
  String get number => song.number;
  bool get isOrdinary => song.isOrdinary;

  String get removedMessage =>
      strings['itemRemovedSong'].replaceFirst("{}", song.title);

  Map<String, dynamic> toJson() => {'id': id};
  Map<String, dynamic> toFullJson() => {'type': 'SONG'}..addAll(song.toJson());
}

abstract class LiturgyDeckItem implements DeckItem {}

class PsalmDeckItem extends LiturgyDeckItem {
  String get id => 'PSALM';
  String get title => strings['psalm'];
  String get number => '';

  String get removedMessage => strings['itemRemovedPsalm'];

  Map<String, dynamic> toJson() => {'type': 'PSALM'};
  Map<String, dynamic> toFullJson() => toJson();
}

class AcclamationDeckItem extends LiturgyDeckItem {
  String get id => 'ACCLAMATION';
  String get title => strings['acclamation'];
  String get number => '';

  String get removedMessage => strings['itemRemovedAcclamation'];

  Map<String, dynamic> toJson() => {'type': 'ACCLAMATION'};
  Map<String, dynamic> toFullJson() => toJson();
}

class DeckRequest {
  final DateTime date;
  final List<DeckItem> items;

  DeckRequest(this.date, this.items);

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String().substring(0, 10),
        'items': items.map((item) => item.toJson()).toList(),
      };
}

class DeckResponse {
  final String url;

  DeckResponse(this.url);

  DeckResponse.fromJson(Map<String, dynamic> json) : url = json['url'];
}

class Manual {
  final List<String> steps;

  Manual(this.steps);

  Manual.fromJson(Map<String, dynamic> json)
      : steps = List<String>.from(json['steps']);
}
