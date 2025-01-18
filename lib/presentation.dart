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
import 'package:slidesui/live_session.dart';
import 'package:slidesui/model.dart';
import 'package:slidesui/state.dart';
import 'package:slidesui/strings.dart';

class PresentationController with ChangeNotifier {
  int _currentPage = 0;
  int get currentPage => _currentPage;

  void setCurrentPage(int newCurrentPage) {
    _currentPage = newCurrentPage;
    notifyListeners();
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
  PdfRenderQueue? _pdf;
  int? _skipRenderingTillPage;
  int? _skipRenderingAfterPage;
  PresentationController controller = PresentationController();
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();

    loadFile();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    controller.addListener(handleSlideChange);
  }

  handleSlideChange() async {
    final isUserTriggeredChange =
        _pageController.page == _pageController.page?.truncate();
    if (isUserTriggeredChange) {
      _isPageViewAnimating = true;
      _skipRenderingTillPage = controller.currentPage - 1;
      _skipRenderingAfterPage = controller.currentPage + 1;
      await _pageController.animateToPage(
        controller.currentPage,
        duration: Durations.medium2,
        curve: Easing.standard,
      );
      _isPageViewAnimating = false;
      _skipRenderingTillPage = null;
      _skipRenderingAfterPage = null;
    }
  }

  @override
  dispose() {
    controller.removeListener(handleSlideChange);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.restoreSystemUIOverlays();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _pdf?.closeAndDeletePdf();

    super.dispose();
  }

  loadFile() async {
    setIsLoading(true);
    try {
      final pdf = PdfRenderQueue(widget.filePath);
      await pdf.openPdf();

      setState(() {
        _pdf = pdf;
      });

      preloadFirstPageOfEachItem();
    } catch (e) {
      Navigator.of(context).pop();
      return;
    } finally {
      setIsLoading(false);
    }
  }

  preloadFirstPageOfEachItem() async {
    if (widget.contents == null) {
      return;
    }

    final indices = widget.contents!.indexed
        .where((idxItem) =>
            idxItem.$2.type == "verse" &&
            idxItem.$2.verseIndex == 0 &&
            idxItem.$2.chunkIndex == 0)
        .map((idxItem) => idxItem.$1);

    for (var index in indices) {
      renderPageCached(index, lowPriority: true);
    }
  }

  Future<MemoryImage?> renderPageCached(int pageIndex,
      {bool lowPriority = false}) async {
    if (!_pdf!.isPageReady(pageIndex)) {
      if (isBlankPage(pageIndex)) {
        return null;
      }

      if (_skipRenderingTillPage != null &&
          pageIndex < _skipRenderingTillPage!) {
        return null;
      }

      if (_skipRenderingAfterPage != null &&
          pageIndex > _skipRenderingAfterPage!) {
        return null;
      }
    }

    return _pdf!.getPage(
      pageIndex,
      renderHeight: getRenderHeight(),
      lowPriority: lowPriority,
    );
  }

  double getRenderHeight() {
    final height = MediaQuery.of(context).size.height;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return height * dpr;
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
      body: (_isLoading || _pdf?._numPages == 0)
          ? Container()
          : PopScope(
              canPop:
                  false, // todo: false only if an external display is connected
              onPopInvoked: (didPop) async {
                if (!didPop) {
                  final shouldPop = await _confirmExit() ?? false;
                  if (context.mounted && shouldPop) {
                    Navigator.pop(context);
                  }
                }
              },
              child: Stack(children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: _pdf?._numPages ?? 0,
                  allowImplicitScrolling: true,
                  onPageChanged: (i) {
                    if (!_isPageViewAnimating) {
                      controller.setCurrentPage(i);
                    }
                  },
                  itemBuilder: (context, pageIndex) => FutureBuilder(
                    future: renderPageCached(pageIndex),
                    builder: (context, snapshot) {
                      if (isBlankPage(pageIndex)) {
                        return Container();
                      }

                      if (snapshot.hasData) {
                        return Center(
                          child: Image(image: snapshot.data!),
                        );
                      }
                      return Container();
                    },
                  ),
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
                        widget.contents != null
                            ? ContentsButton(
                                controller: controller,
                                contents: widget.contents!)
                            : Container(),
                        CastButton(controller: controller),
                        LiveSessionButton(controller: controller),
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

class PdfRenderQueue {
  final String _pdfPath;
  PdfDocument? _pdf;
  int _numPages = 0;
  double _renderHeight = 1080;
  List<Completer<MemoryImage>?> _renderedPages = [];
  final Queue<int> _highPriorityQueue = Queue();
  final Queue<int> _lowPriorityQueue = Queue();
  bool _isProcessing = false;

  PdfRenderQueue(String pdfPath) : _pdfPath = pdfPath;

  openPdf() async {
    _pdf = await PdfDocument.openFile(_pdfPath);
    _numPages = _pdf!.pagesCount;
    _renderedPages = List.filled(_numPages, null);
  }

  closeAndDeletePdf() async {
    await _pdf!.close();
    await File(_pdfPath).delete();
  }

  bool isPageReady(int pageIndex) {
    return _renderedPages[pageIndex]?.isCompleted ?? false;
  }

  int get numPages => _numPages;

  Future<MemoryImage> getPage(
    int pageIndex, {
    double? renderHeight,
    bool lowPriority = false,
  }) {
    if (pageIndex >= _numPages || pageIndex < 0) {
      throw RangeError.range(pageIndex, 0, _numPages);
    }

    if (_renderedPages[pageIndex] != null) {
      return _renderedPages[pageIndex]!.future;
    }

    if (renderHeight != null) {
      _renderHeight = renderHeight;
    }

    _renderedPages[pageIndex] = Completer();
    if (lowPriority) {
      _lowPriorityQueue.addLast(pageIndex);
    } else {
      _highPriorityQueue.addLast(pageIndex);
    }

    if (!_isProcessing) {
      _processQueue();
    }

    return _renderedPages[pageIndex]!.future;
  }

  _processQueue() async {
    _isProcessing = true;
    try {
      do {
        if (_highPriorityQueue.isNotEmpty) {
          await _processRenderTask(_highPriorityQueue.removeFirst());
        } else if (_lowPriorityQueue.isNotEmpty) {
          await _processRenderTask(_lowPriorityQueue.removeFirst());
        } else {
          break;
        }
      } while (true);
    } finally {
      _isProcessing = false;
    }
  }

  _processRenderTask(int pageIndex) async {
    final image = await _renderPage(pageIndex);
    _renderedPages[pageIndex]!.complete(image);
  }

  Future<MemoryImage> _renderPage(int pageIndex) async {
    final page = await _pdf!.getPage(pageIndex + 1);
    try {
      final scale = _renderHeight / page.height;
      final imageData =
          await page.render(height: _renderHeight, width: page.width * scale);

      return MemoryImage(imageData!.bytes);
    } catch (e) {
      rethrow;
    } finally {
      page.close();
    }
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
