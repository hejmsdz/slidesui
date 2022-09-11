import './strings.dart';

class Song {
  final String id;
  final String title;
  final String? subtitle;
  final String number;
  final String slug;
  final bool isOrdinary;

  Song(this.id, this.title, this.subtitle, this.number, this.slug,
      [this.isOrdinary = false]);

  Song.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        title = json['title'],
        subtitle = json['subtitle'],
        number = json['number'],
        slug = json['slug'],
        isOrdinary = json['isOrdinary'] ?? false;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': title,
        'number': number,
        'slug': slug,
        'isOrdinary': isOrdinary,
      };
}

abstract class OrdinaryItems {
  static Song kyrie = Song('f29bb232-be0c-4998-9142-5524c38ec9d7',
      'Kyrie eleison', null, '', '', true);
  static Song sanctus = Song(
      'bf218c0a-ac22-4049-85d0-6072b2830f15', 'Sanctus', null, '', '', true);
  static Song agnus = Song(
      '548120f1-604c-4386-ae89-f9737aac7ae4', 'Agnus Dei', null, '', '', true);
}

abstract class DeckItem {
  String get id;
  String get title;
  String? get subtitle;
  String get number;

  String get removedMessage;

  Map<String, dynamic> toJson();
  Map<String, dynamic> toFullJson();
}

class SongDeckItem implements DeckItem {
  SongDeckItem(this.song);

  Song song;
  @override
  String get id => song.id;
  @override
  String get title => song.title;
  @override
  String? get subtitle => song.subtitle;
  @override
  String get number => song.number;
  bool get isOrdinary => song.isOrdinary;

  @override
  String get removedMessage =>
      strings['itemRemovedSong']!.replaceFirst("{}", song.title);

  @override
  Map<String, dynamic> toJson() => {'id': id};
  @override
  Map<String, dynamic> toFullJson() => {'type': 'SONG'}..addAll(song.toJson());
}

abstract class LiturgyDeckItem implements DeckItem {}

class PsalmDeckItem extends LiturgyDeckItem {
  @override
  String get id => 'PSALM';
  @override
  String get title => strings['psalm']!;
  @override
  String? get subtitle => null;
  @override
  String get number => '';

  @override
  String get removedMessage => strings['itemRemovedPsalm']!;

  @override
  Map<String, dynamic> toJson() => {'type': 'PSALM'};
  @override
  Map<String, dynamic> toFullJson() => toJson();
}

class AcclamationDeckItem extends LiturgyDeckItem {
  @override
  String get id => 'ACCLAMATION';
  @override
  String get title => strings['acclamation']!;
  @override
  String? get subtitle => null;
  @override
  String get number => '';

  @override
  String get removedMessage => strings['itemRemovedAcclamation']!;

  @override
  Map<String, dynamic> toJson() => {'type': 'ACCLAMATION'};
  @override
  Map<String, dynamic> toFullJson() => toJson();
}

class UnresolvedDeckItem implements DeckItem {
  UnresolvedDeckItem(this.title);

  @override
  String title;
  @override
  String get subtitle => '';
  @override
  String get id => title.hashCode.toString();
  @override
  final String number = '?';
  final bool isOrdinary = false;

  @override
  String get removedMessage =>
      strings['itemRemovedSong']!.replaceFirst("{}", title);

  @override
  Map<String, dynamic> toJson() => {};
  @override
  Map<String, dynamic> toFullJson() => {'type': 'UNRESOLVED', 'title': title};
}

class TextDeckItem implements DeckItem {
  TextDeckItem(this.contents);

  String contents;

  @override
  String get id => contents.hashCode.toString();
  @override
  String get title => getTitle();
  @override
  String get subtitle => '';
  @override
  String get number => '';

  @override
  String get removedMessage =>
      strings['itemRemovedSong']!.replaceFirst("{}", title);

  @override
  Map<String, dynamic> toJson() => {'contents': contents.split("\n\n")};
  @override
  Map<String, dynamic> toFullJson() => {'type': 'TEXT', 'contents': contents};

  String getTitle() {
    final lines = contents.split("\n");
    final firstLine = lines[0];
    final firstLineLength = firstLine.length;
    final slice = firstLineLength > 30 ? firstLine.substring(0, 30) : firstLine;
    final isTruncated = contents.length > 30 || firstLineLength > 30;

    return isTruncated ? "$slice..." : slice;
  }
}

class DeckRequest {
  final DateTime date;
  final List<DeckItem> items;
  final bool? hints;
  final String? ratio;
  final int? fontSize;

  DeckRequest({
    required this.date,
    required this.items,
    this.hints,
    this.ratio,
    this.fontSize,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String().substring(0, 10),
        'items': items.map((item) => item.toJson()).toList(),
        'hints': hints,
        'ratio': ratio,
        'fontSize': fontSize,
      };
}

class DeckResponse {
  final String url;

  DeckResponse(this.url);

  DeckResponse.fromJson(Map<String, dynamic> json) : url = json['url'];
}

class Manual {
  final List<String> steps;
  final String image;

  Manual(this.steps, this.image);

  Manual.fromJson(Map<String, dynamic> json)
      : steps = List<String>.from(json['steps']),
        image = json['image'];
}

class BootstrapResponse {
  final String currentVersion;
  final String appDownloadUrl;

  BootstrapResponse(this.currentVersion, this.appDownloadUrl);

  BootstrapResponse.fromJson(Map<String, dynamic> json)
      : currentVersion = json['currentVersion'],
        appDownloadUrl = json['appDownloadUrl'];
}
