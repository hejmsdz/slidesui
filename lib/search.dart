import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
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
  static const itemsPerPage = 20;
  static const debounceDuration = Duration(milliseconds: 500);

  TextEditingController controller = TextEditingController();
  List<Future<List<Song>>> _items = [];
  PaginatedResponse<Song>? _firstUnfilteredPage;
  int _totalItems = 0;
  Timer? _debounce;

  bool _isLoading = false;
  int replaceIndex = -1;

  @override
  void initState() {
    super.initState();

    replaceIndex = widget.replaceIndex;
    controller.text = widget.initialQuery;

    updateQuery(immediate: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  setIsLoading(bool isLoading) {
    setState(() {
      _isLoading = isLoading;
    });
  }

  Future<void> _performSearch() async {
    final query = controller.text;

    if (query.length < queryPrefixLength && query.isNotEmpty) {
      return;
    }

    if (query.isEmpty && _firstUnfilteredPage != null) {
      setState(() {
        _items = [Future.value(_firstUnfilteredPage!.items)];
        _totalItems = _firstUnfilteredPage!.total;
      });
      return;
    }

    setIsLoading(true);

    final response = await loadSongs(query, 0);
    setState(() {
      _totalItems = response.total;
      _items = [Future.value(response.items)];
    });

    setIsLoading(false);

    if (query.isEmpty && _firstUnfilteredPage == null) {
      _firstUnfilteredPage = response;
    }
  }

  void updateQuery({bool immediate = false}) async {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }

    if (immediate) {
      await _performSearch();
      return;
    }

    _debounce = Timer(debounceDuration, _performSearch);
  }

  Future<PaginatedResponse<Song>> loadSongs(String query, int page) async {
    final state = context.read<SlidesModel>();
    return getSongsPaginated(
      query,
      teamId: state.currentTeam?.id,
      limit: itemsPerPage,
      offset: page * itemsPerPage,
    );
  }

  Future<List<Song>?> getPage(int page) async {
    if (_items.length <= page) {
      _items.add(
          loadSongs(controller.text, page).then((response) => response.items));
    }
    return _items[page];
  }

  void resetQuery() {
    controller.clear();
    updateQuery(immediate: true);
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
          onChanged: (value) => updateQuery(),
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
      body: Builder(
        builder: (context) {
          if (!_isLoading && _totalItems == 0) {
            return Center(
              child: Text(
                strings['searchNoResults']!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          }
          return ListView.builder(
            itemCount: _totalItems,
            itemBuilder: (BuildContext context, int index) {
              final page = index ~/ itemsPerPage;
              final itemIndex = index % itemsPerPage;

              return FutureBuilder(
                future: getPage(page),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const ListTile(
                      title: Text(''),
                    );
                  }

                  final items = snapshot.data as List<Song>;
                  final song = items[itemIndex];

                  return Consumer<SlidesModel>(
                    builder: (context, state, child) {
                      final isAdded = state.containsSong(song.id);
                      return SearchListItem(
                        id: song.id,
                        title: song.title,
                        subtitle: song.subtitle,
                        isChecked: isAdded,
                        onTap: () {
                          if (!isAdded) {
                            if (replaceIndex > -1) {
                              state.replaceItem(
                                  replaceIndex, SongDeckItem(song));
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
              );
            },
          );
        },
      ),
    );
  }
}
