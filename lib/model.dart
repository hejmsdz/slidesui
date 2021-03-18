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

class DeckRequest {
  final List<Song> items;

  DeckRequest(this.items);

  Map<String, dynamic> toJson() => {
        'items': items
            .map((item) => {
                  'id': item.id,
                })
            .toList(),
      };
}

class DeckResponse {
  final String url;

  DeckResponse(this.url);

  DeckResponse.fromJson(Map<String, dynamic> json) : url = json['url'];
}
