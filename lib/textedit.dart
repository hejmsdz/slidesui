import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import './strings.dart';
import './state.dart';
import './model.dart';
import './api.dart';

class TextEditPage extends StatefulWidget {
  @override
  _TextEditPageState createState() => _TextEditPageState();
}

class _TextEditPageState extends State<TextEditPage> {
  TextEditingController controller = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    controller.text = getSlidesAsText();
  }

  setIsLoading(bool isLoading) {
    setState(() {
      _isLoading = isLoading;
    });
  }

  String getSlidesAsText() {
    final state = Provider.of<SlidesModel>(context, listen: false);

    return state.items.asMap().entries.map((entry) {
      final item = entry.value;
      final index = entry.key;
      final numberSuffix = (item.number.isEmpty || item.number == '?')
          ? ''
          : " [${item.number}]";
      return "${index + 1}. ${item.title}$numberSuffix";
    }).join("\n");
  }

  clearText() {
    controller.clear();
  }

  applyText() async {
    final lines = controller.text.split("\n");
    final state = Provider.of<SlidesModel>(context, listen: false);
    final Map<String, DeckItem> currentTitles = Map.fromIterable(
      state.items,
      key: (item) => item.title.toLowerCase(),
      value: (item) => item,
    );

    setIsLoading(true);
    List<DeckItem> parsedItems;

    try {
      parsedItems = await Future.wait<DeckItem>(lines.map((line) async {
        final title = line
            .replaceFirst(RegExp(r"^\w+[.:]\s"), "")
            .replaceFirst(RegExp(r"\s[\[\(].*[\]\)]$"), "")
            .trim();
        final titleNormalized = title.toLowerCase();
        if (title.isEmpty) {
          return null;
        }
        if (currentTitles.containsKey(titleNormalized)) {
          return currentTitles[titleNormalized];
        }
        if (titleNormalized == strings['psalm'].toLowerCase()) {
          return PsalmDeckItem();
        }
        if (titleNormalized == strings['acclamation'].toLowerCase()) {
          return AcclamationDeckItem();
        }
        final songs = await getSongs(titleNormalized);
        if (songs.length == 1) {
          return SongDeckItem(songs[0]);
        } else {
          return UnresolvedDeckItem(title);
        }
      }).where((item) => item != null));
    } finally {
      setIsLoading(false);
    }

    final unresolvedCount = parsedItems.whereType<UnresolvedDeckItem>().length;
    if (unresolvedCount > 0) {
      final unresolvedMessage = unresolvedCount == 1
          ? strings['unresolvedOne']
          : strings['unresolvedMany'].replaceFirst('{}', "$unresolvedCount");
      final snackBar = SnackBar(content: Text(unresolvedMessage));
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }

    state.setItems(parsedItems);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(strings['editAsText']),
        actions: [
          IconButton(
            icon: Icon(Icons.clear),
            tooltip: strings['clearText'],
            onPressed: _isLoading ? null : clearText,
          ),
          IconButton(
            icon: Icon(Icons.check),
            tooltip: strings['applyText'],
            onPressed: _isLoading ? null : applyText,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size(double.infinity, 1.0),
          child: Opacity(
            opacity: _isLoading ? 1 : 0,
            child: LinearProgressIndicator(
              value: null,
            ),
          ),
        ),
      ),
      body: TextField(
        controller: controller,
        keyboardType: TextInputType.multiline,
        maxLines: null,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        ),
      ),
    );
  }
}
