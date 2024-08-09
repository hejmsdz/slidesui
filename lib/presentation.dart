import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mutex/mutex.dart';
import 'package:pdf_image_renderer/pdf_image_renderer.dart';
import 'dart:io';

import 'package:slidesui/cast.dart';

class PresentationController with ChangeNotifier {
  int _currentPage = 0;
  int get currentPage => _currentPage;

  void setCurrentPage(int newCurrentPage) {
    _currentPage = newCurrentPage;
    notifyListeners();
  }
}

class PresentationPage extends StatefulWidget {
  const PresentationPage({super.key, required this.filePath});

  final String filePath;

  @override
  State<PresentationPage> createState() => _PresentationPageState();
}

class _PresentationPageState extends State<PresentationPage> {
  bool _isLoading = false;
  bool _isUiVisible = false;
  PdfImageRendererPdf? _pdf;
  int _numPages = 0;
  final _pdfMutex = Mutex();
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

  handleSlideChange() {
    final isUserTriggeredChange =
        _pageController.page == _pageController.page?.truncate();
    if (isUserTriggeredChange) {
      _pageController.jumpToPage(controller.currentPage);
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

    _pdf?.close().then((_) {
      File(widget.filePath).delete();
    });

    super.dispose();
  }

  loadFile() async {
    setIsLoading(true);
    try {
      final pdf = PdfImageRendererPdf(path: widget.filePath);
      await pdf.open();
      final numPages = await pdf.getPageCount();
      _pdf = pdf;

      setState(() {
        _numPages = numPages;
      });
    } catch (e) {
      Navigator.of(context).pop();
      return;
    } finally {
      setIsLoading(false);
    }
  }

  Future<MemoryImage> renderPage(int pageIndex) async {
    final height = MediaQuery.of(context).size.height;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final renderHeight = height * dpr;

    await _pdfMutex.acquire();
    await _pdf!.openPage(pageIndex: pageIndex);
    try {
      final size = await _pdf!.getPageSize(pageIndex: pageIndex);
      final scale = renderHeight / size.height;
      final imageData = await _pdf!.renderPage(
        pageIndex: pageIndex,
        x: 0,
        y: 0,
        width: size.width,
        height: size.height,
        scale: scale,
        background: Colors.black,
      );

      return MemoryImage(imageData!);
    } finally {
      await _pdf!.closePage(pageIndex: pageIndex);
      _pdfMutex.release();
    }
  }

  setIsLoading(bool isLoading) {
    setState(() {
      _isLoading = isLoading;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        body: (_isLoading || _numPages == 0)
            ? Container()
            : Stack(children: [
                PageView.builder(
                    controller: _pageController,
                    itemCount: _numPages,
                    allowImplicitScrolling: true,
                    onPageChanged: (i) {
                      controller.setCurrentPage(i);
                    },
                    itemBuilder: (context, pageIndex) {
                      return FutureBuilder(
                        future: renderPage(pageIndex),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Center(
                              child: Image(
                                image: snapshot.data!,
                              ),
                            );
                          }
                          return Container();
                        },
                      );
                    }),
                GestureDetector(
                  onDoubleTap: () {
                    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
                    setState(() {
                      _isUiVisible = !_isUiVisible;
                    });
                  },
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
                        CastButton(controller: controller),
                      ],
                    ),
                  ),
                ),
              ]));
  }
}
