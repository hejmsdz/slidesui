import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

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

double getRenderHeight(BuildContext context) {
  final height = MediaQuery.of(context).size.height;
  final dpr = MediaQuery.of(context).devicePixelRatio;
  return height * dpr;
}
