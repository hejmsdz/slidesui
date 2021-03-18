import 'package:flutter/material.dart';
import 'package:slidesui/search.dart';
import './strings.dart';
import './model.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: strings['appTitle'],
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: strings['appTitle']),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class ListItem extends StatelessWidget {
  ListItem({Key key, this.symbol, this.title, this.number, this.onRemoved})
      : super(key: key);

  final String symbol;
  final String title;
  final String number;
  final void Function() onRemoved;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: key,
      onDismissed: (direction) {
        onRemoved();
      },
      background: Container(color: Colors.red),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(symbol),
        ),
        title: Text(title),
        trailing: Text(
          number,
          style: Theme.of(context).textTheme.caption,
        ),
      ),
    );
  }
}

class _MyHomePageState extends State<MyHomePage> {
  List<Song> _items = [];

  void _reorderItems(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _addItem(Song item) {
    setState(() {
      _items.add(item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(
              Icons.search,
              color: Colors.white,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) {
                  return SearchPage(onSelect: _addItem);
                }),
              );
            },
          ),
        ],
      ),
      body: ReorderableListView.builder(
        itemCount: _items.length,
        itemBuilder: (BuildContext context, int index) {
          final song = _items[index];
          return ListItem(
            key: ValueKey(song.id),
            symbol: "${index + 1}",
            title: song.title,
            number: song.number,
            onRemoved: () {
              _removeItem(index);
            },
          );
        },
        onReorder: _reorderItems,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: strings['generateSlides'],
        child: Icon(Icons.slideshow_rounded),
      ),
    );
  }
}
