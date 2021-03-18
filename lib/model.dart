class Song {
  final String id;
  final String title;
  final String number;

  Song(this.id, this.title, this.number);

  Song.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        title = json['title'],
        number = json['number'];
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
  final Uri url;

  DeckResponse(this.url);

  DeckResponse.fromJson(Map<String, dynamic> json)
      : url = Uri.parse(json['url']);
}
