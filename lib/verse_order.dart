import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slidesui/api.dart';
import 'package:slidesui/model.dart';
import 'package:slidesui/state.dart';
import 'package:slidesui/strings.dart';

class VerseOrderPage extends StatefulWidget {
  const VerseOrderPage({super.key, required this.itemIndex});

  final int itemIndex;

  @override
  State<VerseOrderPage> createState() => _VerseOrderPageState();
}

class _VerseOrderPageState extends State<VerseOrderPage> {
  _VerseOrderPageState();

  bool _isLoading = false;

  fetchVerses() async {
    final int itemIndex = widget.itemIndex;
    final state = Provider.of<SlidesModel>(context, listen: false);
    final item = state.items[itemIndex] as SongDeckItem;

    if (item.rawVerses == null) {
      setIsLoading(true);
    }

    try {
      List<String> rawVerses = await getLyrics(item.id, raw: true);
      setState(() {
        state.setRawVerses(
            itemIndex,
            rawVerses
                .map((verse) => verse.replaceFirst(RegExp("//\\s+"), ""))
                .toList());

        if (item.selectedVerses == null ||
            item.selectedVerses!.length != rawVerses.length) {
          state.setSelectedVerses(itemIndex,
              rawVerses.map((verse) => !verse.startsWith("//")).toList());
        }
      });
    } finally {
      setIsLoading(false);
    }
  }

  setIsLoading(bool isLoading) {
    setState(() {
      _isLoading = isLoading;
    });
  }

  @override
  initState() {
    super.initState();

    fetchVerses();
  }

  @override
  Widget build(BuildContext context) {
    final int itemIndex = widget.itemIndex;

    return Scaffold(
        appBar: AppBar(
          title: Text(strings['verseOrder']!),
          bottom: PreferredSize(
            preferredSize: const Size(double.infinity, 1.0),
            child: Opacity(
              opacity: _isLoading ? 1 : 0,
              child: const LinearProgressIndicator(
                value: null,
              ),
            ),
          ),
        ),
        body: Consumer<SlidesModel>(
          builder: (context, state, child) {
            final item = state.items[itemIndex] as SongDeckItem;
            if (item.rawVerses == null || item.selectedVerses == null) {
              return Container();
            }

            final rawVerses = item.rawVerses!;

            return ListView.builder(
                padding: const EdgeInsets.all(0),
                itemCount: rawVerses.length,
                itemBuilder: (BuildContext context, int index) {
                  bool isSelected = item.selectedVerses!.elementAt(index);

                  return ListTile(
                    title: Text(rawVerses[index],
                        softWrap: true,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: isSelected ? null : Colors.black45,
                            decoration: isSelected
                                ? null
                                : TextDecoration.lineThrough)),
                    leading: Checkbox(
                        value: isSelected,
                        onChanged: (bool? value) {
                          if (value == null) return;
                          state.updateSelectedVerses(itemIndex, index, value);
                        }),
                  );
                });
          },
        ));
  }
}
