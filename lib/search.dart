import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slidesui/utils.dart';
import './strings.dart';
import './state.dart';
import './model.dart';
import './api.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.initialQuery = "", this.replaceIndex = -1});

  final String initialQuery;
  final int replaceIndex;

  @override
  _SearchPageState createState() => _SearchPageState();
}

class SearchListItem extends StatelessWidget {
  SearchListItem(
      {required this.id,
      required this.title,
      this.subtitle,
      this.isChecked = false,
      this.onTap})
      : super(key: ValueKey(id));

  final String id;
  final String title;
  final String? subtitle;
  final bool isChecked;
  final Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      leading: isChecked ? const Icon(Icons.check) : const Icon(null),
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
      .replaceAll(RegExp('[^a-zA-Z0-9\\. ]+'), '');
}

class _SearchPageState extends State<SearchPage> {
  _SearchPageState();

  TextEditingController controller = TextEditingController();
  String query = "";
  List<Song> _prefilteredItems = [];
  List<Song> _items = [];
  bool _isLoading = false;
  bool _isQueryValid = false;
  int replaceIndex = -1;

  @override
  void initState() {
    super.initState();

    query = widget.initialQuery;
    replaceIndex = widget.replaceIndex;

    controller.text = query;
    if (query.isNotEmpty) {
      updateQuery(query, forceUpdate: true);
    }
  }

  setIsLoading(bool isLoading) {
    setState(() {
      _isLoading = isLoading;
    });
  }

  void updateQuery(String newQuery, {bool forceUpdate = false}) async {
    if (newQuery.startsWith('\$')) {
      handleCheatCode(newQuery);
      return;
    }

    final previousQuery = query;
    setState(() {
      query = newQuery;
      _isQueryValid = query.length >= queryPrefixLength;
    });

    if (!_isQueryValid) {
      return;
    }

    final queryPrefixChanged = previousQuery.length < queryPrefixLength ||
        newQuery.substring(0, queryPrefixLength) !=
            previousQuery.substring(0, queryPrefixLength);

    if (forceUpdate || (queryPrefixChanged && !_isLoading)) {
      setIsLoading(true);
      try {
        _prefilteredItems =
            await getSongs(query.substring(0, queryPrefixLength));
      } finally {
        setIsLoading(false);
      }
    }

    final querySlug = slugify(query);

    setState(() {
      _items = _prefilteredItems
          .where((item) => item.slug.contains(querySlug))
          .toList();
    });
  }

  handleCheatCode(String code) {
    if (code == '\$admin') {
      final state = Provider.of<SlidesModel>(context, listen: false);
      if (state.specialMode == "admin") {
        state.setSpecialMode(null);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Wyłączono tryb administratora tekstów.")));
      } else {
        state.setSpecialMode("admin");
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Włączono tryb administratora tekstów.")));
      }
    }
  }

  void resetQuery() {
    setState(() {
      query = "";
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
              hintText: strings['searchSongs']!,
              border: InputBorder.none,
            ),
            style: const TextStyle(fontSize: 16.0),
            onChanged: updateQuery,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: resetQuery,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size(double.infinity, 1.0),
            child: Opacity(
              opacity: _isLoading ? 1 : 0,
              child: const LinearProgressIndicator(
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
                  strings['searchStartTyping']!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }
            if (!_isLoading && _items.isEmpty) {
              return Center(
                child: Text(
                  strings['searchNoResults']!,
                  style: Theme.of(context).textTheme.bodySmall,
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
                  subtitle: song.subtitle,
                  isChecked: isAdded,
                  onTap: () {
                    if (!isAdded) {
                      if (replaceIndex > -1) {
                        state.replaceItem(replaceIndex, SongDeckItem(song));
                        Navigator.pop(context);
                      } else {
                        state.addItem(SongDeckItem(song));
                      }
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
