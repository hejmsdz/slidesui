import 'package:flutter/material.dart';
import 'package:external_display/transfer_parameters.dart';
import 'package:slidesui/pdf.dart';

class ExternalDisplayApp extends StatefulWidget {
  const ExternalDisplayApp({super.key});

  @override
  State<ExternalDisplayApp> createState() => _ExternalDisplayAppState();
}

class _ExternalDisplayAppState extends State<ExternalDisplayApp> {
  PdfRenderQueue? _pdf;
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

  handleOpen(String pdfPath) async {
    _pdf = PdfRenderQueue(pdfPath);
    await _pdf!.openPdf();

    setState(() {
      _isPresenting = true;
      _buffer0 = null;
      _buffer1 = null;
    });

    handlePageChange(0);
  }

  handleClose() {
    setState(() {
      _isPresenting = false;
    });
    _pdf?.close();
  }

  handlePageChange(int pageIndex) async {
    final image = await _pdf!.getPage(
      pageIndex,
      renderHeight: getRenderHeight(context),
    );

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
          _buildBuffer(_buffer0, _isPresenting && _currentBuffer == 0),
          _buildBuffer(_buffer1, _isPresenting && _currentBuffer == 1),
        ]),
      ),
    );
  }

  Widget _buildBuffer(MemoryImage? buffer, bool isVisible) {
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: Duration(milliseconds: 500),
      child: buffer == null ? Container() : Center(child: Image(image: buffer)),
    );
  }
}
