import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:slidesui/presentation.dart';
import 'package:slidesui/verse_order.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import './model.dart';
import './api.dart';
import './persistence.dart';
import './strings.dart';
import './state.dart';
import './deck.dart';
import './search.dart';
import './textedit.dart';
import './manual.dart';
import './settings.dart';

void main() async {
  if (!kIsWeb) {
    WidgetsFlutterBinding.ensureInitialized();
  }
  final state = await loadSavedState();
  await Settings.init();
  saveStateChanges(state);
  runApp(
    ChangeNotifierProvider(
      create: (context) => state,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: strings['appTitle']!,
      theme: ThemeData(
        colorSchemeSeed: Colors.orange,
        appBarTheme: const AppBarTheme(elevation: 1.0),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.orange,
        appBarTheme: const AppBarTheme(elevation: 1.0),
      ),
      themeMode: ThemeMode.system,
      home: MyHomePage(title: strings['appTitle']!),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class ListItem extends StatelessWidget {
  const ListItem(
      {required this.itemKey,
      required this.symbol,
      required this.title,
      this.subtitle,
      required this.number,
      required this.index,
      required this.isSong,
      required this.onRemoved,
      required this.onTap})
      : super(key: itemKey);

  final ValueKey itemKey;
  final String symbol;
  final String title;
  final String? subtitle;
  final String number;
  final bool isSong;
  final void Function() onRemoved;
  final void Function() onTap;
  final int index;

  edit(BuildContext context) {
    String id = itemKey.value.replaceAll('-', '');
    Uri editUrl = Uri.parse("notion://www.notion.so/$id");
    launchUrl(editUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: itemKey,
      startActionPane: isSong
          ? ActionPane(
              motion: const ScrollMotion(),
              children: [
                SlidableAction(
                  onPressed: (context) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) {
                        return VerseOrderPage(
                          itemIndex: index,
                        );
                      }),
                    );
                  },
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  icon: Icons.reorder,
                  label: strings['verseOrder']!,
                ),
                SlidableAction(
                  onPressed: edit,
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  icon: Icons.edit,
                  label: strings['edit']!,
                ),
              ],
            )
          : null,
      endActionPane: ActionPane(
          motion: const ScrollMotion(),
          dismissible: DismissiblePane(onDismissed: () {
            onRemoved();
          }),
          children: [
            SlidableAction(
              onPressed: (context) {
                onRemoved();
              },
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: strings['remove']!,
            ),
          ]),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(symbol),
        ),
        title: Text(title, overflow: TextOverflow.ellipsis),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, overflow: TextOverflow.ellipsis),
        trailing: Padding(
          padding: const EdgeInsets.only(right: kIsWeb ? 24 : 0),
          child: number == '?'
              ? const Icon(Icons.report)
              : Text(
                  number,
                  style: Theme.of(context).textTheme.bodySmall,
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
          title: Text(strings['enterText']!),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.multiline,
            maxLines: null,
            autofocus: true,
          ),
          actions: [
            TextButton(
              child: Text(strings['cancel']!),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(strings['ok']!),
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
          title: Text(strings['newVersionAvailable']!),
          content: Text(strings['newVersionDescription']!
              .replaceFirst("{latestVersion}", latestVersion)
              .replaceFirst("{yourVersion}", yourVersion)),
          actions: [
            TextButton(
              child: Text(strings['skipVersion']!),
              onPressed: () async {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                prefs.setString("skippedVersion", latestVersion);
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(strings['notNow']!),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(strings['download']!),
              onPressed: () {
                launchUrl(Uri.parse(appDownloadUrl));
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
            icon: const Icon(Icons.search),
            tooltip: strings['searchSongs']!,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) {
                  return const SearchPage();
                }),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.assignment_outlined),
            tooltip: strings['editAsText']!,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) {
                  return const TextEditPage();
                }),
              );
            },
          ),
          Consumer<SlidesModel>(
              builder: (context, state, child) => PopupMenuButton<String>(
                  tooltip: strings['menu']!,
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
                          MaterialPageRoute(
                              builder: (context) => const ManualPage()),
                        );
                        break;
                      case 'RELOAD_LYRICS':
                        reloadLyrics();
                        break;
                      case 'OPEN_SETTINGS':
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SettingsPage()),
                        );
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return [
                      state.hasLiturgy()
                          ? PopupMenuItem(
                              value: 'REMOVE_LITURGY',
                              child: Text(strings['removeLiturgy']!),
                            )
                          : PopupMenuItem(
                              value: 'ADD_LITURGY',
                              child: Text(strings['addLiturgy']!),
                            ),
                      state.hasOrdinary()
                          ? PopupMenuItem(
                              value: 'REMOVE_ORDINARY',
                              child: Text(strings['removeOrdinary']!),
                            )
                          : PopupMenuItem(
                              value: 'ADD_ORDINARY',
                              child: Text(strings['addOrdinary']!),
                            ),
                      PopupMenuItem(
                        value: 'ADD_TEXT',
                        child: Text(strings['addText']!),
                      ),
                      PopupMenuItem(
                        value: 'CHANGE_DATE',
                        child: Text(strings['changeDate']!),
                      ),
                      PopupMenuItem(
                        value: 'OPEN_MANUAL',
                        child: Text(strings['manual']!),
                      ),
                      PopupMenuItem(
                        value: 'RELOAD_LYRICS',
                        child: Text(strings['reloadLyrics']!),
                      ),
                      PopupMenuItem(
                        value: 'OPEN_SETTINGS',
                        child: Text(strings['settings']!),
                      ),
                    ];
                  })),
        ],
        bottom: PreferredSize(
          preferredSize: const Size(double.infinity, 1.0),
          child: Opacity(
            opacity: _isWorking ? 1 : 0,
            child: const LinearProgressIndicator(
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
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    strings['emptyTitle']!,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  strings['emptyDescription']!,
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
              itemKey: ValueKey(song.id),
              symbol: "${index + 1}",
              title: song.title,
              subtitle: song.subtitle,
              number: song.number,
              index: index,
              isSong: song is SongDeckItem && !song.isOrdinary,
              onRemoved: () {
                state.removeItem(index);
                final snackBar = SnackBar(
                  content: Text(song.removedMessage),
                  action: SnackBarAction(
                    label: strings['undo']!,
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
          visible: state.isValid(),
          child: FloatingActionButton(
            onPressed: _isWorking
                ? null
                : () async {
                    setIsWorking(true);
                    try {
                      final behavior =
                          Settings.getValue<String>('app.slidesBehavior');
                      final result = await createDeck(context,
                          contents: behavior == 'display');

                      switch (behavior) {
                        case 'display':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                fullscreenDialog: true,
                                builder: (context) {
                                  return PresentationPage(
                                    filePath: result.url,
                                    contents: result.contents,
                                  );
                                }),
                          );
                          break;
                        case 'share':
                          Share.shareXFiles([XFile(result.url)]);
                          break;
                        default:
                          notifyOnDownloaded(context, result.url);
                          break;
                      }
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
            tooltip: strings['generateSlides']!,
            child: const Icon(Icons.slideshow_rounded),
          ),
        ),
      ),
    );
  }
}
