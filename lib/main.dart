import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import './persistence.dart';
import './strings.dart';
import './state.dart';
import './deck.dart';
import './search.dart';
import './manual.dart';

void main() async {
  if (!kIsWeb) {
    WidgetsFlutterBinding.ensureInitialized();
    await FlutterDownloader.initialize(debug: kDebugMode);
  }
  final state = await loadSavedState();
  saveStateChanges(state);
  runApp(
    ChangeNotifierProvider(
      create: (context) => state,
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
                      case 'REMOVE_LITURGY':
                        state.removeLiturgy();
                        break;
                      case 'ADD_ORDINARY':
                        state.addOrdinary();
                        break;
                      case 'REMOVE_ORDINARY':
                        state.removeOrdinary();
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
                      case 'OPEN_MANUAL':
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) {
                            return ManualPage();
                          }),
                        );
                    }
                  }, itemBuilder: (BuildContext context) {
                    return [
                      state.hasLiturgy()
                          ? PopupMenuItem(
                              child: Text(strings['removeLiturgy']),
                              value: 'REMOVE_LITURGY',
                            )
                          : PopupMenuItem(
                              child: Text(strings['addLiturgy']),
                              value: 'ADD_LITURGY',
                            ),
                      state.hasOrdinary()
                          ? PopupMenuItem(
                              child: Text(strings['removeOrdinary']),
                              value: 'REMOVE_ORDINARY',
                            )
                          : PopupMenuItem(
                              child: Text(strings['addOrdinary']),
                              value: 'ADD_ORDINARY',
                            ),
                      PopupMenuItem(
                        child: Text(strings['changeDate']),
                        value: 'CHANGE_DATE',
                      ),
                      PopupMenuItem(
                        child: Text(strings['manual']),
                        value: 'OPEN_MANUAL',
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
