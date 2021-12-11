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

final String TEXT_ITEM_DELIMITER = "'''";

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
      final text = item is TextDeckItem ? "${TEXT_ITEM_DELIMITER}${item.contents}${TEXT_ITEM_DELIMITER}" : item.title;
      return "${index + 1}. ${text}$numberSuffix";
    }).join("\n");
  }

  clearText() {
    controller.clear();
  }

  List<String> splitLines(String text) {
    final naiveLines = text.split("\n");
    final lines = List<String>();

    String textItem = null;
    naiveLines.forEach((naiveLine) {
      final hasDelimiter = naiveLine.contains(TEXT_ITEM_DELIMITER);
      if (hasDelimiter) {
        if (textItem == null) {
          textItem = naiveLine + "\n";
        } else {
          textItem += naiveLine + "\n";
          lines.add(textItem);
          textItem = null;
        }
      } else {
        if (textItem == null) {
          lines.add(naiveLine);
        } else {
          textItem += naiveLine + "\n";
        }
      }
    });

    return lines;
  }

  applyText() async {
    final state = Provider.of<SlidesModel>(context, listen: false);
    final text = controller.text.trim();
    if (text.isEmpty) {
      state.setItems([]);
      Navigator.pop(context);
      return;
    }
    final lines = splitLines(text);
    print(lines);
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

        if (title.startsWith(TEXT_ITEM_DELIMITER) && title.endsWith(TEXT_ITEM_DELIMITER)) {
          final trimChars = TEXT_ITEM_DELIMITER.length;
          return TextDeckItem(title.substring(trimChars, title.length - trimChars));
        }

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
