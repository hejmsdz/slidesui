import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:path_provider/path_provider.dart';
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
  const PresentationPage({super.key, required this.zipFilePath});

  final String zipFilePath;

  @override
  State<PresentationPage> createState() => _PresentationPageState();
}

class _PresentationPageState extends State<PresentationPage> {
  bool _isLoading = false;
  bool _isUiVisible = false;
  List<File>? _images;
  Directory? destinationDir;
  PresentationController controller = PresentationController();
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();

    extractZip();

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

    if (destinationDir != null) {
      destinationDir!.delete();
    }

    super.dispose();
  }

  extractZip() async {
    setIsLoading(true);
    List<File> images;
    try {
      final zipFile = File(widget.zipFilePath);
      final tempDir = await getTemporaryDirectory();
      destinationDir = await tempDir.createTemp();

      await ZipFile.extractToDirectory(
        zipFile: zipFile,
        destinationDir: destinationDir!,
      );
      await zipFile.delete();

      images = (await destinationDir!.list().toList())
          .map((entity) => File(entity.path))
          .toList();
    } catch (e) {
      Navigator.of(context).pop();
      return;
    } finally {
      setIsLoading(false);
    }

    setState(() {
      _images = images;
    });
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
        body: (() {
          if (_isLoading || _images == null) {
            return Container();
          }

          final double height = MediaQuery.of(context).size.height;

          return Stack(children: [
            PageView.builder(
                controller: _pageController,
                itemCount: _images?.length ?? 0,
                allowImplicitScrolling: true,
                onPageChanged: (i) {
                  controller.setCurrentPage(i);
                },
                itemBuilder: (context, index) {
                  return Center(
                    child: Image.file(
                      _images![index],
                      fit: BoxFit.cover,
                      height: height,
                    ),
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
          ]);
        })());
  }
}
