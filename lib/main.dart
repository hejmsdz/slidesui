import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:slidesui/model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './api.dart';
import './persistence.dart';
import './strings.dart';
import './state.dart';
import './deck.dart';
import './search.dart';
import './textedit.dart';
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
  ListItem(
      {Key key,
      this.symbol,
      this.title,
      this.number,
      this.index,
      this.onRemoved,
      this.onTap})
      : super(key: key);

  final String symbol;
  final String title;
  final String number;
  final void Function() onRemoved;
  final void Function() onTap;
  final int index;

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
        trailing: Padding(
          padding: EdgeInsets.only(right: kIsWeb ? 24 : 0),
          child: number == '?'
              ? Icon(Icons.report)
              : Text(
                  number,
                  style: Theme.of(context).textTheme.caption,
                ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isWorking = false;

  @override
  void initState() {
    super.initState();

    checkVersion();
  }

  void checkVersion() async {
    final bootstrap = await getBootstrap();
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final localVersion = packageInfo.version;
    SharedPreferences prefs = await SharedPreferences.getInstance();

    final latestVersion = bootstrap.currentVersion;
    final isSkipped = prefs.getString("skippedVersion") == latestVersion;

    if (latestVersion != localVersion && !isSkipped) {
      showNewVersionDialog(
          latestVersion, localVersion, bootstrap.appDownloadUrl);
    }
  }

  setIsWorking(bool isWorking) {
    setState(() {
      _isWorking = isWorking;
    });
  }

  reloadLyrics() async {
    setIsWorking(true);
    try {
      await postReload();
    } finally {
      setIsWorking(false);
    }
  }

  showTextDialog(Function(String) callback, [String initialValue = ""]) {
    TextEditingController controller =
        TextEditingController(text: initialValue);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
          title: Text(strings['enterText']),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.multiline,
            maxLines: null,
            autofocus: true,
          ),
          actions: [
            TextButton(
              child: Text(strings['cancel']),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(strings['ok']),
              onPressed: () {
                if (controller.text.isEmpty) {
                  return;
                }

                callback(controller.text);
                Navigator.of(context).pop();
              },
            ),
          ]),
    );
  }

  showNewVersionDialog(
      String latestVersion, String yourVersion, String appDownloadUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
          title: Text(strings['newVersionAvailable']),
          content: Text(strings['newVersionDescription']
              .replaceFirst("{latestVersion}", latestVersion)
              .replaceFirst("{yourVersion}", yourVersion)),
          actions: [
            TextButton(
              child: Text(strings['skipVersion']),
              onPressed: () async {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                prefs.setString("skippedVersion", latestVersion);
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(strings['notNow']),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(strings['download']),
              onPressed: () {
                launch(appDownloadUrl);
                Navigator.of(context).pop();
              },
            ),
          ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            tooltip: strings['searchSongs'],
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) {
                  return SearchPage();
                }),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.assignment_outlined),
            tooltip: strings['editAsText'],
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) {
                  return TextEditPage();
                }),
              );
            },
          ),
          Consumer<SlidesModel>(
              builder: (context, state, child) => PopupMenuButton<String>(
                  tooltip: strings['menu'],
                  onSelected: (choice) async {
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
                      case 'ADD_TEXT':
                        showTextDialog((String contents) {
                          state.addText(contents);
                        });
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
                        break;
                      case 'RELOAD_LYRICS':
                        reloadLyrics();
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) {
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
                        child: Text(strings['addText']),
                        value: 'ADD_TEXT',
                      ),
                      PopupMenuItem(
                        child: Text(strings['changeDate']),
                        value: 'CHANGE_DATE',
                      ),
                      PopupMenuItem(
                        child: Text(strings['manual']),
                        value: 'OPEN_MANUAL',
                      ),
                      PopupMenuItem(
                        child: Text(strings['reloadLyrics']),
                        value: 'RELOAD_LYRICS',
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
                Text(
                  strings['emptyDescription'],
                  textAlign: TextAlign.center,
                ),
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
              index: index,
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
              onTap: () {
                if (song is SongDeckItem || song is UnresolvedDeckItem) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) {
                      return SearchPage(
                        initialQuery: song.title,
                        replaceIndex: index,
                      );
                    }),
                  );
                } else if (song is TextDeckItem) {
                  showTextDialog((String newContents) {
                    state.updateText(index, newContents);
                  }, song.contents);
                }
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
