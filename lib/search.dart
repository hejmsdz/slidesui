import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import './strings.dart';
import './state.dart';
import './model.dart';
import './api.dart';

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class SearchListItem extends StatelessWidget {
  SearchListItem({this.id, this.title, this.number, this.isChecked, this.onTap})
      : super(key: ValueKey(id));

  final String id;
  final String title;
  final String number;
  final bool isChecked;
  final Function onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      leading: this.isChecked ? Icon(Icons.check) : Icon(null),
      trailing: Text(
        number,
        style: Theme.of(context).textTheme.caption,
      ),
      onTap: onTap,
    );
  }
}

const queryPrefixLength = 3;

slugify(String text) {
  return text
      .toLowerCase()
      .replaceAll('ą', 'a')
      .replaceAll('ć', 'c')
      .replaceAll('ę', 'e')
      .replaceAll('ł', 'l')
      .replaceAll('ń', 'n')
      .replaceAll('ó', 'o')
      .replaceAll('ś', 's')
      .replaceAll('ź', 'z')
      .replaceAll('ż', 'z')
      .replaceAll(RegExp('[^a-zA-Z0-9\. ]+'), '');
}

class _SearchPageState extends State<SearchPage> {
  TextEditingController controller = TextEditingController();
  String _query = "";
  List<Song> _prefilteredItems = [];
  List<Song> _items = [];
  bool _isLoading = false;
  bool _isQueryValid = false;

  setIsLoading(bool isLoading) {
    setState(() {
      _isLoading = isLoading;
    });
  }

  void updateQuery(String query) async {
    final previousQuery = _query;
    setState(() {
      _query = query;
      _isQueryValid = _query.length >= queryPrefixLength;
    });

    if (!_isQueryValid) {
      return;
    }

    final queryPrefixChanged = previousQuery.length < queryPrefixLength ||
        query.substring(0, queryPrefixLength) !=
            previousQuery.substring(0, queryPrefixLength);

    final querySlug = slugify(query);

    if (queryPrefixChanged && !_isLoading) {
      setIsLoading(true);
      try {
        _prefilteredItems =
            await getSongs(_query.substring(0, queryPrefixLength));
      } finally {
        setIsLoading(false);
      }
    }

    setState(() {
      _items = _prefilteredItems
          .where((item) => item.slug.contains(querySlug))
          .toList();
    });
  }

  void resetQuery() {
    setState(() {
      _query = "";
      _prefilteredItems = [];
      _items = [];
    });
    controller.clear();
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
            ),
            style: TextStyle(fontSize: 16.0),
            onChanged: updateQuery,
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.clear),
              onPressed: resetQuery,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: Size(double.infinity, 1.0),
            child: Opacity(
              opacity: _isLoading ? 1 : 0,
              child: LinearProgressIndicator(
                value: null,
              ),
            ),
          ),
        ),
        body: Consumer<SlidesModel>(
          builder: (context, state, child) {
            if (!_isQueryValid) {
              return Center(
                child: Text(
                  strings['searchStartTyping'],
                  style: Theme.of(context).textTheme.caption,
                ),
              );
            }
            if (!_isLoading && _items.isEmpty) {
              return Center(
                child: Text(
                  strings['searchNoResults'],
                  style: Theme.of(context).textTheme.caption,
                ),
              );
            }
            return ListView.builder(
              itemCount: _items.length,
              itemBuilder: (BuildContext context, int index) {
                final song = _items[index];
                final isAdded = state.containsSong(song.id);
                return SearchListItem(
                  id: song.id,
                  title: song.title,
                  number: song.number,
                  isChecked: isAdded,
                  onTap: () {
                    if (!isAdded) {
                      state.addItem(SongDeckItem(song));
                    } else {
                      state.removeItemById(song.id);
                    }
                  },
                );
              },
            );
          },
        ));
  }
}
