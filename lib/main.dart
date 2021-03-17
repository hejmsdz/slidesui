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
        child: Container(
          padding: EdgeInsets.all(8),
          child: Row(children: [
            Padding(
                padding: EdgeInsets.only(right: 8),
                child: CircleAvatar(
                  // backgroundColor: Colors.orange,
                  // foregroundColor: Colors.black87,
                  child: Text(symbol),
                )),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyText1,
            ),
            Spacer(),
            Padding(
                padding: EdgeInsets.all(8.0),
                child:
                    Text(number, style: Theme.of(context).textTheme.caption)),
          ]),
        ));
  }
}

class _MyHomePageState extends State<MyHomePage> {
  List<Song> _items = [
    Song("288ef611-5f1e-475c-beb0-573618e9be93", "Bądź mi litościw", "3.9"),
    Song("ad822725-2459-4f58-bfce-556331b1f6f6", "Krzyż jest źródłem", "3.11"),
    Song("824162c3-58f3-44cc-8c90-908d23ab9394", "Chrystus Pan karmi nas",
        "6.16"),
    Song("e2208656-289a-4ca1-8736-37edbfe68136", "Ukaż mi Panie swą twarz", ""),
    Song("bf4baad1-d607-4d9f-b738-29ae875b58a8", "O, matko miłościwa", ""),
  ];

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
                  return SearchPage();
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
