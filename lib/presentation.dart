import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

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
  CarouselController carouselController = CarouselController();

  @override
  void initState() {
    super.initState();

    extractZip();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  dispose() {
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
            CarouselSlider(
              carouselController: carouselController,
              options: CarouselOptions(
                height: height,
                viewportFraction: 1.0,
                enableInfiniteScroll: false,
                enlargeCenterPage: false,
                onPageChanged: (i, reason) {
                  if (reason == CarouselPageChangedReason.manual) {
                    print(i);
                  }
                },
              ),
              items: _images!
                  .map(
                    (image) => Center(
                        child: Image.file(
                      image,
                      fit: BoxFit.cover,
                      height: height,
                    )),
                  )
                  .toList(),
            ),
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
                  /*
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.cast),
                      tooltip: "Cast",
                      onPressed: () {},
                    )
                  ],
                  */
                ),
              ),
            ),
          ]);
        })());
  }
}
