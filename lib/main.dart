import 'package:flutter/material.dart';
import 'package:slidesui/search.dart';
import 'package:provider/provider.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import './strings.dart';
import './state.dart';
import './deck.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterDownloader.initialize(debug: true);
  runApp(
    ChangeNotifierProvider(
      create: (context) => SlidesModel(),
      child: MyApp(),
    ),
  );
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
      body: Consumer<SlidesModel>(
          builder: (context, state, child) => ReorderableListView.builder(
                itemCount: state.items.length,
                itemBuilder: (BuildContext context, int index) {
                  final song = state.items[index];
                  return ListItem(
                    key: ValueKey(song.id),
                    symbol: "${index + 1}",
                    title: song.title,
                    number: song.number,
                    onRemoved: () {
                      state.removeItem(index);
                      final snackBar = SnackBar(
                        content: Text(strings['itemRemoved']),
                        action: SnackBarAction(
                          label: strings['undo'],
                          onPressed: state.undoRemoveItem,
                        ),
                      );

                      ScaffoldMessenger.of(context).showSnackBar(snackBar);
                    },
                  );
                },
                onReorder: state.reorderItems,
              )),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          createDeck(context);
        },
        tooltip: strings['generateSlides'],
        child: Icon(Icons.slideshow_rounded),
      ),
    );
  }
}
