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
