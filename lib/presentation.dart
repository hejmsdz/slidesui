import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:slidesui/cast.dart';
import 'package:slidesui/deck.dart';
import 'package:slidesui/external_display_singleton.dart';
import 'package:slidesui/live_session.dart';
import 'package:slidesui/model.dart';
import 'package:slidesui/state.dart';
import 'package:slidesui/strings.dart';

class PresentationController with ChangeNotifier {
  int _currentPage = 0;
  int get currentPage => _currentPage;

  bool _isPaused = false;
  bool get isPaused => _isPaused;

  Function? internalListener;

  void setCurrentPage(int newCurrentPage) {
    _currentPage = newCurrentPage;

    if (!_isPaused) {
      notifyListeners();
    }

    if (internalListener != null) {
      internalListener!();
    }
  }

  void pause() {
    _isPaused = true;
  }

  void resume() {
    _isPaused = false;
    notifyListeners();
  }

  void togglePause() {
    if (_isPaused) {
      resume();
    } else {
      pause();
    }
  }
}

class PresentationPage extends StatefulWidget {
  const PresentationPage({super.key, required this.filePath, this.contents});

  final String filePath;
  final List<ContentSlide>? contents;

  @override
  State<PresentationPage> createState() => _PresentationPageState();
}

class _PresentationPageState extends State<PresentationPage> {
  bool _isLoading = false;
  bool _isUiVisible = true;
  bool _isPageViewAnimating = false;
  bool _isBroadcasting = false;
  final Map<String, bool> _broadcastingState = {};
  PdfController? _pdf;

  PresentationController controller = PresentationController();

  @override
  void initState() {
    super.initState();

    loadFile();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    controller.internalListener = handleSlideChange;

    externalDisplay.sendParameters(
      action: "open",
      value: "${widget.filePath}#0",
    );
  }

  handleBroadcastChange(String channel, bool isBroadcasting) {
    setState(() {
      _broadcastingState[channel] = isBroadcasting;
      _isBroadcasting = _broadcastingState.values.any((value) => value);
    });
  }

  handleSlideChange() async {
    _isPageViewAnimating = true;
    await _pdf!.animateToPage(
      controller.currentPage + 1,
      duration: Durations.medium2,
      curve: Easing.standard,
    );
    _isPageViewAnimating = false;
  }

  @override
  dispose() {
    controller.internalListener = null;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.restoreSystemUIOverlays();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _pdf?.dispose();
    File(widget.filePath).delete();

    super.dispose();
  }

  loadFile() async {
    setIsLoading(true);
    try {
      final pdf = PdfController(
        document: PdfDocument.openFile(widget.filePath),
      );

      setState(() {
        _pdf = pdf;
      });
    } catch (e) {
      Navigator.of(context).pop();
      return;
    } finally {
      setIsLoading(false);
    }
  }

  bool isBlankPage(int pageIndex) {
    return widget.contents?[pageIndex].type == "blank";
  }

  setIsLoading(bool isLoading) {
    setState(() {
      _isLoading = isLoading;
    });
  }

  jumpToFirstSlideOfCurrentItem() {
    if (widget.contents == null) {
      return;
    }

    final contents = widget.contents!;
    final currentItemIndex = contents[controller.currentPage].itemIndex;
    final index = contents.indexWhere((cs) =>
        cs.type == "verse" &&
        cs.itemIndex == currentItemIndex &&
        cs.verseIndex == 0 &&
        cs.chunkIndex == 0);

    if (index >= 0) {
      controller.setCurrentPage(index);
    }
  }

  jumpToLastSlideOfCurrentItem() {
    if (widget.contents == null) {
      return;
    }

    final contents = widget.contents!;
    final currentItemIndex = contents[controller.currentPage].itemIndex;
    final index = contents.indexWhere(
        (cs) => cs.type == "blank" && cs.itemIndex == currentItemIndex);

    if (index >= 0) {
      controller.setCurrentPage(index);
    }
  }

  Future<bool?> _confirmExit() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(strings['confirmExitTitle']!),
          content: Text(strings['confirmExit']!),
          actions: <Widget>[
            TextButton(
              child: Text(strings['no']!),
              onPressed: () {
                Navigator.pop(context, false);
              },
            ),
            TextButton(
              child: Text(strings['yes']!),
              onPressed: () {
                Navigator.pop(context, true);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: (_isLoading || _pdf == null || _pdf?.pagesCount == 0)
          ? Container()
          : PopScope<Object?>(
              canPop:
                  !_isBroadcasting, // todo: false only if an external display is connected
              onPopInvokedWithResult: (didPop, result) async {
                if (!didPop) {
                  final shouldPop = await _confirmExit() ?? false;
                  if (context.mounted && shouldPop) {
                    Navigator.pop(context);
                  }
                }
              },
              child: Stack(children: [
                PdfView(
                  controller: _pdf!,
                  onPageChanged: (page) {
                    if (!_isPageViewAnimating) {
                      controller.setCurrentPage(page - 1);
                    }
                  },
                  scrollDirection: Axis.horizontal,
                ),
                Row(
                  children: [
                    Expanded(
                        flex: 1,
                        child: GestureDetector(
                          onDoubleTap: jumpToFirstSlideOfCurrentItem,
                        )),
                    Expanded(
                        flex: 3,
                        child: GestureDetector(
                          onDoubleTap: () {
                            SystemChrome.setEnabledSystemUIMode(
                                SystemUiMode.immersive);
                            setState(() {
                              _isUiVisible = !_isUiVisible;
                            });
                          },
                        )),
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        onDoubleTap: jumpToLastSlideOfCurrentItem,
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    duration: Durations.medium1,
                    opacity: _isUiVisible ? 1 : 0,
                    child: AppBar(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white54,
                      actions: [
                        _isBroadcasting
                            ? IconButton(
                                icon: Icon(controller.isPaused
                                    ? Icons.play_arrow
                                    : Icons.pause),
                                tooltip: controller.isPaused
                                    ? strings['resume']!
                                    : strings['pause']!,
                                onPressed: () {
                                  setState(() {
                                    controller.togglePause();
                                  });
                                },
                              )
                            : Container(),
                        ExternalDisplayBroadcaster(
                          controller: controller,
                          filePath: widget.filePath,
                          onStateChange: handleBroadcastChange,
                        ),
                        CastButton(controller: controller),
                        LiveSessionButton(
                          controller: controller,
                          onStateChange: handleBroadcastChange,
                        ),
                        ContentsButton(
                          controller: controller,
                          contents: widget.contents!,
                        ),
                        IconButton(
                          icon: const Icon(Icons.share),
                          tooltip: strings['shareSlides'],
                          onPressed: () {
                            Share.shareXFiles([XFile(widget.filePath)]);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.save_alt),
                          tooltip: strings['saveToFile'],
                          onPressed: () {
                            notifyOnDownloaded(context, widget.filePath);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
    );
  }
}

class ExternalDisplayBroadcaster extends StatefulWidget {
  const ExternalDisplayBroadcaster(
      {super.key,
      required this.controller,
      required this.filePath,
      this.onStateChange});

  final PresentationController controller;
  final String filePath;
  final void Function(String, bool)? onStateChange;

  @override
  State<ExternalDisplayBroadcaster> createState() =>
      _ExternalDisplayBroadcasterState();
}

class _ExternalDisplayBroadcasterState
    extends State<ExternalDisplayBroadcaster> {
  @override
  void initState() {
    super.initState();

    widget.controller.addListener(handlePageChange);
    handleOpen();
    externalDisplay.addStatusListener(handleDisplayChange);

    Future.microtask(() {
      if (externalDisplay.isPlugging) {
        widget.onStateChange?.call('externalDisplay', true);
      }
    });
  }

  void handleOpen() async {
    externalDisplay.sendParameters(
      action: "open",
      value: "${widget.filePath}#${widget.controller.currentPage}",
    );
  }

  void handleDisplayChange(dynamic status) {
    widget.onStateChange?.call('externalDisplay', status == true);

    if (status == true) {
      handleOpen();
    }
  }

  void handlePageChange() {
    externalDisplay.sendParameters(
      action: "page",
      value: widget.controller.currentPage,
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(handlePageChange);
    externalDisplay.removeStatusListener(handleDisplayChange);

    externalDisplay.sendParameters(
      action: "close",
    );

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class ContentsButton extends StatelessWidget {
  final PresentationController controller;
  final List<ContentSlide> contents;

  const ContentsButton({
    super.key,
    required this.controller,
    required this.contents,
  });

  goToItem(int index) {
    final page = contents.indexWhere(
        (slide) => slide.type == "verse" && slide.itemIndex == index);
    controller.setCurrentPage(page);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SlidesModel>(builder: (context, state, child) {
      final items = state.items.indexed;
      return MenuAnchor(
        menuChildren: items
            .map(
              (idxItem) => MenuItemButton(
                onPressed: () => goToItem(idxItem.$1),
                child: Text(idxItem.$2.title),
              ),
            )
            .toList(),
        builder: (_, menuController, child) => IconButton(
          icon: const Icon(Icons.toc),
          onPressed: () => menuController.isOpen
              ? menuController.close()
              : menuController.open(),
        ),
      );
    });
  }
}
