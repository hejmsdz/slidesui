import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:slidesui/cast_service.dart';
import 'package:slidesui/external_display.dart';
import 'package:slidesui/external_display_singleton.dart';
import 'package:slidesui/invitation.dart';
import 'package:slidesui/presentation.dart';
import 'package:slidesui/receiver.dart';
import 'package:slidesui/verse_order.dart';
import 'package:slidesui/web_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import './model.dart';
import './api.dart';
import './persistence.dart';
import './strings.dart';
import './state.dart';
import './deck.dart';
import './search.dart';
import './textedit.dart';
import './navigation_drawer.dart';

void main() async {
  if (!kIsWeb) {
    WidgetsFlutterBinding.ensureInitialized();
  }
  final state = await loadSavedState();
  await Settings.init();
  saveStateChanges(state);

  externalDisplay.addStatusListener((status) {
    if (status) {
      externalDisplay.connect();
    }
  });
  externalDisplay.connect();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => state),
        ChangeNotifierProvider(create: (_) => CastService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
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
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => MyHomePage(),
            routes: [
              GoRoute(
                path: 'invitation/:token',
                builder: (context, state) {
                  return InvitationPage(token: state.pathParameters['token']!);
                },
              ),
              GoRoute(
                path: ':liveSessionKey([0-9]{4})',
                builder: (context, state) {
                  return PresentationReceiver(
                      liveSessionKey: state.pathParameters['liveSessionKey']!);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class ListItem extends StatelessWidget {
  const ListItem(
      {required this.itemKey,
      required this.symbol,
      required this.title,
      this.subtitle,
      required this.index,
      required this.isSong,
      required this.isUnresolved,
      required this.onRemoved,
      required this.onTap})
      : super(key: itemKey);

  final ValueKey itemKey;
  final String symbol;
  final String title;
  final String? subtitle;
  final bool isSong;
  final bool isUnresolved;
  final void Function() onRemoved;
  final void Function() onTap;
  final int index;

  edit(BuildContext context, SlidesModel state) {
    final id = itemKey.value;
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (context) => WebViewPage(
                path: "dashboard/songs/$id",
                title: strings['edit']!,
                onClose: (url) {
                  String newId = id;
                  if (url != null) {
                    newId = url.split("/").last;
                  }
                  state.reloadSong(id, newId);
                },
              )),
    );
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
                Consumer<SlidesModel>(builder: (context, state, _) {
                  return SlidableAction(
                    onPressed: (context) {
                      if (state.currentTeam == null) {
                        final isLoggedIn = state.user != null;
                        showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                                  title: Text(strings['teamRequired']!),
                                  content: Text(isLoggedIn
                                      ? strings[
                                          'teamRequiredDescriptionLoggedIn']!
                                      : strings[
                                          'teamRequiredDescriptionLoggedOut']!),
                                  actions: [
                                    TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: Text(strings['ok']!))
                                  ],
                                ));
                      } else {
                        edit(context, state);
                      }
                    },
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    icon: Icons.edit,
                    label: strings['edit']!,
                  );
                }),
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
        trailing: isUnresolved ? const Icon(Icons.report) : null,
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
    if (mounted) {
      context.read<SlidesModel>().setBootstrap(bootstrap);
    }

    if (bootstrap.currentVersion == null) {
      return;
    }

    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final localVersion = packageInfo.version;
    SharedPreferences prefs = await SharedPreferences.getInstance();

    final latestVersion = bootstrap.currentVersion;
    final isSkipped = prefs.getString("skippedVersion") == latestVersion;

    if (latestVersion != localVersion && !isSkipped && latestVersion != null) {
      showNewVersionDialog(
          latestVersion, localVersion, bootstrap.appDownloadUrl);
    }
  }

  setIsWorking(bool isWorking) {
    setState(() {
      _isWorking = isWorking;
    });
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

  showDateErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(strings['liturgyDateError']!),
        actions: [
          TextButton(
            child: Text(strings['ok']!),
            onPressed: () async {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
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
        title: Text(strings['appTitle']!),
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
            icon: const Icon(Icons.edit_note),
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
            builder: (context, state, child) => MenuAnchor(
              builder: (context, controller, widget) {
                return IconButton(
                  icon: Icon(Icons.more_vert),
                  tooltip: strings['menu']!,
                  onPressed: () {
                    controller.open();
                  },
                );
              },
              menuChildren: [
                if (state.hasLiturgy())
                  MenuItemButton(
                    onPressed: () {
                      state.removeLiturgy();
                    },
                    child: Text(strings['removeLiturgy']!),
                  )
                else
                  MenuItemButton(
                    onPressed: () {
                      state.addLiturgy();
                    },
                    child: Text(strings['addLiturgy']!),
                  ),
                if (state.hasOrdinary())
                  MenuItemButton(
                    onPressed: () {
                      state.removeOrdinary();
                    },
                    child: Text(strings['removeOrdinary']!),
                  )
                else
                  MenuItemButton(
                    onPressed: () {
                      state.addOrdinary();
                    },
                    child: Text(strings['addOrdinary']!),
                  ),
                MenuItemButton(
                  onPressed: () {
                    showTextDialog((String contents) {
                      state.addText(contents);
                    });
                  },
                  child: Text(strings['addText']!),
                ),
                MenuItemButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final lastDate = DateTime(now.year + 1, 12, 31);
                    final date = await showDatePicker(
                      context: context,
                      initialDate: state.date,
                      firstDate: now,
                      lastDate: lastDate,
                    );
                    if (date != null) {
                      final ok = await state.setDate(date);
                      if (!ok) {
                        showDateErrorDialog();
                      }
                    }
                  },
                  child: Text(strings['changeDate']!),
                ),
              ],
            ),
          )
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
      drawer: const AppNavigationDrawer(),
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
              index: index,
              isSong: song is SongDeckItem && !song.isOrdinary,
              isUnresolved: song is UnresolvedDeckItem,
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
                          Settings.getValue<String>('app.slidesBehavior') ??
                              'display';
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
                        case 'save':
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

@pragma('vm:entry-point')
void externalDisplayMain() {
  runApp(const ExternalDisplayApp());
}
