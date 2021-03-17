import 'package:flutter/material.dart';
import './strings.dart';
import './model.dart';

class SearchPage extends StatefulWidget {
  SearchPage({Key key}) : super(key: key);

  @override
  _SearchPageState createState() => _SearchPageState();
}

class SearchListItem extends StatelessWidget {
  SearchListItem({Key key, this.title, this.number}) : super(key: key);

  final String title;
  final String number;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodyText1,
        ),
        Spacer(),
        Text(number, style: Theme.of(context).textTheme.caption),
      ]),
    );
  }
}

class _SearchPageState extends State<SearchPage> {
  TextEditingController controller = TextEditingController();
  String _query = "";
  List<Song> _items = [
    Song("288ef611-5f1e-475c-beb0-573618e9be93", "Bądź mi litościw", "3.9"),
    Song("ad822725-2459-4f58-bfce-556331b1f6f6", "Krzyż jest źródłem", "3.11"),
    Song("824162c3-58f3-44cc-8c90-908d23ab9394", "Chrystus Pan karmi nas",
        "6.16"),
    Song("e2208656-289a-4ca1-8736-37edbfe68136", "Ukaż mi Panie swą twarz", ""),
    Song("bf4baad1-d607-4d9f-b738-29ae875b58a8", "O, matko miłościwa", ""),
  ];

  @override
  Widget build(BuildContext context) {
    print(_query);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: strings['searchSongs'],
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white30),
          ),
          style: TextStyle(color: Colors.white, fontSize: 16.0),
          onChanged: (newQuery) {
            setState(() {
              _query = newQuery;
            });
          },
        ),
      ),
      body: ListView.builder(
        itemCount: _items.length,
        itemBuilder: (BuildContext context, int index) {
          final song = _items[index];
          return SearchListItem(
            key: ValueKey(song.id),
            title: song.title,
            number: song.number,
          );
        },
      ),
    );
  }
}
