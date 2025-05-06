import 'package:flutter/material.dart';
import 'package:external_display/transfer_parameters.dart';
import 'package:pdfx/pdfx.dart';

class ExternalDisplayApp extends StatefulWidget {
  const ExternalDisplayApp({super.key});

  @override
  State<ExternalDisplayApp> createState() => _ExternalDisplayAppState();
}

class _ExternalDisplayAppState extends State<ExternalDisplayApp> {
  PdfDocument? _pdf;
  bool _isPresenting = false;
  MemoryImage? _buffer0;
  MemoryImage? _buffer1;
  int _currentBuffer = 0;

  @override
  initState() {
    super.initState();

    TransferParameters transferParameters = TransferParameters();
    transferParameters.addListener(({required action, value}) {
      switch (action) {
        case "open":
          handleOpen(value as String);
          break;
        case "close":
          handleClose();
          break;
        case "page":
          handlePageChange(value as int);
          break;
      }
    });
  }

  handleOpen(String pdfPathWithPage) async {
    final [pdfPath, pageStr] = pdfPathWithPage.split("#");
    final page = int.parse(pageStr);

    _pdf = await PdfDocument.openFile(pdfPath);

    setState(() {
      _isPresenting = true;
      _buffer0 = null;
      _buffer1 = null;
    });

    handlePageChange(page);
  }

  handleClose() {
    setState(() {
      _isPresenting = false;
    });
    _pdf?.close();
  }

  double getRenderHeight() {
    final height = MediaQuery.of(context).size.height;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return height * dpr;
  }

  Future<MemoryImage> renderPage(int pageIndex) async {
    final page = await _pdf!.getPage(pageIndex + 1);
    try {
      final renderHeight = getRenderHeight();
      final scale = renderHeight / page.height;
      final imageData =
          await page.render(height: renderHeight, width: page.width * scale);

      return MemoryImage(imageData!.bytes);
    } finally {
      page.close();
    }
  }

  handlePageChange(int pageIndex) async {
    if (_pdf == null) {
      return;
    }

    final image = await renderPage(pageIndex);
    setState(() {
      if (_currentBuffer == 0) {
        _buffer1 = image;
      } else {
        _buffer0 = image;
      }
      _currentBuffer = 1 - _currentBuffer;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          buildBuffer(_buffer0, _isPresenting && _currentBuffer == 0),
          buildBuffer(_buffer1, _isPresenting && _currentBuffer == 1),
        ]),
      ),
    );
  }

  Widget buildBuffer(MemoryImage? buffer, bool isVisible) {
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: Duration(milliseconds: 500),
      child: buffer == null ? Container() : Center(child: Image(image: buffer)),
    );
  }
}
