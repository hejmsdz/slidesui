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
        primarySwatch: Colors.orange,
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
  bool _isWorking = false;

  setIsWorking(bool isWorking) {
    setState(() {
      _isWorking = isWorking;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) {
                  return SearchPage();
                }),
              );
            },
          ),
          Consumer<SlidesModel>(
              builder: (context, state, child) =>
                  PopupMenuButton<String>(onSelected: (choice) async {
                    switch (choice) {
                      case 'ADD_LITURGY':
                        state.addLiturgy();
                        break;
                      case 'CHANGE_DATE':
                        final now = DateTime.now();
                        final firstDate = DateTime(now.year - 1, 1, 1);
                        final lastDate = DateTime(now.year + 1, 12, 31);
                        final date = await showDatePicker(
                          context: context,
                          initialDate: state.date,
                          firstDate: firstDate,
                          lastDate: lastDate,
                        );
                        if (date != null) {
                          state.setDate(date);
                        }
                        break;
                    }
                    if (choice == 'ADD_LITURGY') {}
                  }, itemBuilder: (BuildContext context) {
                    return [
                      PopupMenuItem(
                        enabled: !state.hasLiturgy(),
                        child: Text(strings['addLiturgy']),
                        value: 'ADD_LITURGY',
                      ),
                      PopupMenuItem(
                        child: Text(strings['changeDate']),
                        value: 'CHANGE_DATE',
                      ),
                    ];
                  })),
        ],
        bottom: PreferredSize(
          preferredSize: Size(double.infinity, 1.0),
          child: Opacity(
            opacity: _isWorking ? 1 : 0,
            child: LinearProgressIndicator(
              value: null,
            ),
          ),
        ),
      ),
      body: Consumer<SlidesModel>(builder: (context, state, child) {
        if (state.items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    strings['emptyTitle'],
                    style: Theme.of(context).textTheme.headline6,
                  ),
                ),
                Text(strings['emptyDescription'])
              ],
            ),
          );
        }
        return ReorderableListView.builder(
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
                  content: Text(song.removedMessage),
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
        );
      }),
      floatingActionButton: Consumer<SlidesModel>(
        builder: (context, state, child) => Visibility(
          visible: state.items.isNotEmpty,
          child: FloatingActionButton(
            onPressed: _isWorking
                ? null
                : () async {
                    setIsWorking(true);
                    try {
                      await createDeck(context);
                    } finally {
                      setIsWorking(false);
                    }
                  },
            backgroundColor: _isWorking
                ? Theme.of(context).disabledColor
                : Theme.of(context).colorScheme.secondary,
            foregroundColor: _isWorking
                ? Colors.white
                : Theme.of(context).colorScheme.onSecondary,
            tooltip: strings['generateSlides'],
            child: Icon(Icons.slideshow_rounded),
          ),
        ),
      ),
    );
  }
}
