import 'package:flutter/material.dart';
import './strings.dart';
import './model.dart';
import './api.dart';

class SearchPage extends StatefulWidget {
  SearchPage({Key key, this.onSelect}) : super(key: key);

  final Function(Song) onSelect;

  @override
  _SearchPageState createState() => _SearchPageState(onSelect: onSelect);
}

class SearchListItem extends StatelessWidget {
  SearchListItem({Key key, this.title, this.number, this.onTap})
      : super(key: key);

  final String title;
  final String number;
  final Function onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyText1,
            overflow: TextOverflow.ellipsis,
          ),
          Spacer(),
          Text(number, style: Theme.of(context).textTheme.caption),
        ]),
      ),
    );
  }
}

class _SearchPageState extends State<SearchPage> {
  _SearchPageState({this.onSelect}) : super();

  final Function(Song) onSelect;

  TextEditingController controller = TextEditingController();
  String _query = "";
  List<Song> _items = [];

  void updateQuery(query) async {
    setState(() {
      _query = query;
    });

    if (_query.length < 3) {
      setState(() {
        _items = [];
      });
      return;
    }

    final items = await getSongs(_query);

    setState(() {
      _items = items;
    });
  }

  @override
  Widget build(BuildContext context) {
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
          onChanged: updateQuery,
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
            onTap: () {
              print(context);
              onSelect(song);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }
}
