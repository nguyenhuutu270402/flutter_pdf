import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:huutu_app/home_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';
import 'dart:developer' as developer;

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String remotePDFpath = "";
  @override
  void initState() {
    super.initState();
    createFileOfPdfUrl().then((f) {
      setState(() {
        remotePDFpath = f.path;
      });
    });
  }

  Future<File> createFileOfPdfUrl() async {
    Completer<File> completer = Completer();
    print("Start download file from internet!");
    try {
      const url = "https://pdfkit.org/docs/guide.pdf";
      downloadFile(url, "mypdf.pdf");
      final filename = url.substring(url.lastIndexOf("/") + 1);
      var request = await HttpClient().getUrl(Uri.parse(url));
      var response = await request.close();
      var bytes = await consolidateHttpClientResponseBytes(response);
      var dir = await getExternalStorageDirectory();
      File file = File("${dir!.path}/$filename");
      print("Download files>>>>>>>>>>>>>>>>> ${file.path}");
      await file.writeAsBytes(bytes, flush: true);
      completer.complete(file);
    } catch (e) {
      throw Exception('Error parsing asset file!');
    }

    return completer.future;
  }

  Future<void> openPdf() async {
    await OpenFile.open(remotePDFpath);
  }

  void sendMail() {
    String? encodeQueryParameters(Map<String, String> params) {
      return params.entries
          .map((MapEntry<String, String> e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
    }

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'smith@example.com',
      query: encodeQueryParameters(<String, String>{
        'subject': 'Example Subject & Symbols are allowed!',
        'body': 'Hello, this is the body of the email.',
        'attachment': '$remotePDFpath',
      }),
    );

    launchUrl(emailLaunchUri);
  }

  // Future<void> downloadFile(String url, String fileName) async {
  //   Dio dio = Dio();
  //   try {
  //     // Tạo thư mục download nếu chưa tồn tại
  //     Directory appDocDir = await getApplicationSupportDirectory();
  //     String downloadPath = appDocDir.path + "/Download";
  //     await Directory(downloadPath).create(recursive: true);
  //     // Tạo đường dẫn đầy đủ cho file PDF
  //     String filePath = '$downloadPath/$fileName';
  //     // Tải file từ URL
  //     await dio.download(url, filePath);
  //     File file = File(filePath);
  //     developer.log('File đã được tải và lưu vào: $file');
  //     await open_file.OpenFile.open(file.path);
  //   } catch (e) {
  //     print('Lỗi khi tải file: $e');
  //   }
  // }

  Future<void> downloadFile(String url, String fileName) async {
    Dio dio = Dio();
    try {
      // Lấy thư mục download trên bộ nhớ ngoại vi
      // Directory? externalDir = await get();
      Directory externalDir = Directory('/storage/emulated/0/Download');
        developer.log('Lỗi: Không thể lấy thư mục bộ nhớ ngoại vi. $externalDir');
      if (externalDir == null) {
        developer.log('Lỗi: Không thể lấy thư mục bộ nhớ ngoại vi.');
        return;
      }

      String downloadPath = '${externalDir.path}';
      await Directory(downloadPath).create(recursive: true);

      // Tạo đường dẫn đầy đủ cho file PDF
      String filePath = '$downloadPath/$fileName';

      // Tải file từ URL
      await dio.download(url, filePath);

      // Kiểm tra xem file có tồn tại không trước khi mở
      File file = File(filePath);
      if (await file.exists()) {
        developer.log('File đã được tải và lưu vào: $file');
        await OpenFile.open(file.path);
      } else {
        developer.log('Lỗi: File không tồn tại');
      }
    } catch (e) {
      print('Lỗi khi tải file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter PDF View',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Plugin example app')),
        body: Center(child: Builder(
          builder: (BuildContext context) {
            return Column(
              children: <Widget>[
                TextButton(
                  child: Text("Remote PDF"),
                  onPressed: () {
                    if (remotePDFpath.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PDFScreen(path: remotePDFpath),
                        ),
                      );
                    }
                  },
                ),
                TextButton(
                  child: Text("open print"),
                  onPressed: () {
                    if (remotePDFpath.isNotEmpty) {
                      openPdf();
                    }
                  },
                ),
                TextButton(
                  child: Text("Home"),
                  onPressed: () {
                    if (remotePDFpath.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyHomePage(
                            title: 'Home',
                          ),
                        ),
                      );
                    }
                  },
                ),
                TextButton(
                  child: Text("Mail"),
                  onPressed: () {
                    sendMail();
                  },
                )
              ],
            );
          },
        )),
      ),
    );
  }
}

class PDFScreen extends StatefulWidget {
  final String? path;

  PDFScreen({Key? key, this.path}) : super(key: key);

  _PDFScreenState createState() => _PDFScreenState();
}

class _PDFScreenState extends State<PDFScreen> with WidgetsBindingObserver {
  final Completer<PDFViewController> _controller =
      Completer<PDFViewController>();
  int? pages = 0;
  int? currentPage = 0;
  bool isReady = false;
  String errorMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Document"),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          PDFView(
            filePath: widget.path,
            enableSwipe: true,
            swipeHorizontal: true,
            autoSpacing: false,
            pageFling: true,
            pageSnap: true,
            defaultPage: currentPage!,
            fitPolicy: FitPolicy.BOTH,
            preventLinkNavigation:
                false, // if set to true the link is handled in flutter
            onRender: (_pages) {
              setState(() {
                pages = _pages;
                isReady = true;
              });
            },
            onError: (error) {
              setState(() {
                errorMessage = error.toString();
              });
              print(error.toString());
            },
            onPageError: (page, error) {
              setState(() {
                errorMessage = '$page: ${error.toString()}';
              });
              print('$page: ${error.toString()}');
            },
            onViewCreated: (PDFViewController pdfViewController) {
              _controller.complete(pdfViewController);
            },
            onLinkHandler: (String? uri) {
              print('goto uri: $uri');
            },
            onPageChanged: (int? page, int? total) {
              print('page change: $page/$total');
              setState(() {
                currentPage = page;
              });
            },
          ),
          errorMessage.isEmpty
              ? !isReady
                  ? Center(
                      child: CircularProgressIndicator(),
                    )
                  : Container()
              : Center(
                  child: Text(errorMessage),
                )
        ],
      ),
      floatingActionButton: FutureBuilder<PDFViewController>(
        future: _controller.future,
        builder: (context, AsyncSnapshot<PDFViewController> snapshot) {
          if (snapshot.hasData) {
            return FloatingActionButton.extended(
              label: Text("Go to ${pages! ~/ 2}"),
              onPressed: () async {
                await snapshot.data!.setPage(pages! ~/ 2);
              },
            );
          }

          return Container();
        },
      ),
    );
  }
}
