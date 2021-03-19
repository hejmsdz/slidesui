import './strings.dart';

class Song {
  final String id;
  final String title;
  final String number;
  final String slug;

  Song(this.id, this.title, this.number, this.slug);

  Song.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        title = json['title'],
        number = json['number'],
        slug = json['slug'];
}

abstract class DeckItem {
  String get id;
  String get title;
  String get number;

  Map<String, dynamic> toJson();
}

class SongDeckItem implements DeckItem {
  SongDeckItem(this.song);

  Song song;
  String get id => song.id;
  String get title => song.title;
  String get number => song.number;

  Map<String, dynamic> toJson() => {'id': id};
}

abstract class LiturgyDeckItem implements DeckItem {}

class PsalmDeckItem extends LiturgyDeckItem {
  String get id => 'PSALM';
  String get title => strings['psalm'];
  String get number => '';

  Map<String, dynamic> toJson() => {'type': 'PSALM'};
}

class AcclamationDeckItem extends LiturgyDeckItem {
  String get id => 'ACCLAMATION';
  String get title => strings['acclamation'];
  String get number => '';

  Map<String, dynamic> toJson() => {'type': 'ACCLAMATION'};
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
