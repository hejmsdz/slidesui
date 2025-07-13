import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class PdfPresentation extends StatefulWidget {
  final String pdfPath;
  final int currentPage;

  const PdfPresentation({
    super.key,
    required this.pdfPath,
    required this.currentPage,
  });

  @override
  State<PdfPresentation> createState() => _PdfPresentationState();
}

class _PdfPresentationState extends State<PdfPresentation> {
  PdfDocument? _pdf;
  MemoryImage? _buffer0;
  MemoryImage? _buffer1;
  int _currentBuffer = 0;

  @override
  void initState() {
    super.initState();
    _initializePdf();
  }

  @override
  void didUpdateWidget(PdfPresentation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pdfPath != widget.pdfPath) {
      _initializePdf();
    } else if (oldWidget.currentPage != widget.currentPage) {
      _handlePageChange(widget.currentPage);
    }
  }

  @override
  void dispose() {
    _pdf?.close();
    super.dispose();
  }

  Future<void> _initializePdf() async {
    _pdf?.close();
    _pdf = await PdfDocument.openFile(widget.pdfPath);
    setState(() {
      _buffer0 = null;
      _buffer1 = null;
    });
    _handlePageChange(widget.currentPage);
  }

  double _getRenderHeight() {
    final height = MediaQuery.of(context).size.height;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return height * dpr;
  }

  Future<MemoryImage> _renderPage(int pageIndex) async {
    final page = await _pdf!.getPage(pageIndex + 1);
    try {
      final renderHeight = _getRenderHeight();
      final scale = renderHeight / page.height;
      final imageData =
          await page.render(height: renderHeight, width: page.width * scale);

      return MemoryImage(imageData!.bytes);
    } finally {
      page.close();
    }
  }

  Future<void> _handlePageChange(int pageIndex) async {
    if (_pdf == null) {
      return;
    }

    final image = await _renderPage(pageIndex);
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
    return Stack(children: [
      _buildBuffer(_buffer0, _currentBuffer == 0),
      _buildBuffer(_buffer1, _currentBuffer == 1),
    ]);
  }

  Widget _buildBuffer(MemoryImage? buffer, bool isVisible) {
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: buffer == null ? Container() : Center(child: Image(image: buffer)),
    );
  }
}
