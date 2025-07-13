import 'package:flutter/material.dart';
import 'package:external_display/transfer_parameters.dart';
import 'package:slidesui/pdf_presentation.dart';

class ExternalDisplayApp extends StatefulWidget {
  const ExternalDisplayApp({super.key});

  @override
  State<ExternalDisplayApp> createState() => _ExternalDisplayAppState();
}

class _ExternalDisplayAppState extends State<ExternalDisplayApp> {
  bool _isPresenting = false;
  String? _pdfPath;
  int _currentPage = 0;

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

  handleOpen(String pdfPathWithPage) {
    final [pdfPath, pageStr] = pdfPathWithPage.split("#");
    final page = int.parse(pageStr);

    setState(() {
      _isPresenting = true;
      _pdfPath = pdfPath;
      _currentPage = page;
    });
  }

  handleClose() {
    setState(() {
      _isPresenting = false;
      _pdfPath = null;
    });
  }

  handlePageChange(int pageIndex) {
    setState(() {
      _currentPage = pageIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: _isPresenting && _pdfPath != null
            ? PdfPresentation(
                pdfPath: _pdfPath!,
                currentPage: _currentPage,
              )
            : Container(),
      ),
    );
  }
}
