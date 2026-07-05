
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class PdfViewerScreen extends StatelessWidget {
  final String filePath;
  final String fileName;

  const PdfViewerScreen({super.key, required this.filePath, required this.fileName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
        backgroundColor: const Color(0xFF2E1E14),
      ),
      body: PDFView(
        filePath: filePath,
        enableSwipe: true,
        swipeHorizontal: true,
        autoSpacing: false,
        pageFling: true,
        pageSnap: true,
        defaultPage: 0,
        fitPolicy: FitPolicy.BOTH,
        preventLinkNavigation: false, // if set to true the link is handled in flutter
        onRender: (pages) {
          //_pages = pages;
          //setState(() {});
        },
        onError: (error) {
          //setState(() {
            //_errorMessage = error.toString();
          //});
          debugPrint(error.toString());
        },
        onPageError: (page, error) {
          //setState(() {
           // _errorMessage = '$page: ${error.toString()}';
          //});
          debugPrint('$page: ${error.toString()}');
        },
        onViewCreated: (PDFViewController pdfViewController) {
          //_controller.complete(pdfViewController);
        },
        onPageChanged: (int? page, int? total) {
          debugPrint('page change: $page/$total');
        },
      ),
    );
  }
}
