import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

class InAppWebViewScreen extends StatefulWidget {
  const InAppWebViewScreen({Key? key}) : super(key: key);

  @override
  State<InAppWebViewScreen> createState() => _InAppWebViewScreenState();
}

class _InAppWebViewScreenState extends State<InAppWebViewScreen> {
  final GlobalKey webViewKey = GlobalKey();

  Uri myUrl = Uri.parse("www.heymanz.com");
  late final InAppWebViewController webViewController;
  late final PullToRefreshController pullToRefreshController;
  double progress = 0;

  /// file download 관련
  final ReceivePort _port = ReceivePort();

  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int downloadProgress) {
    final SendPort send = IsolateNameServer.lookupPortByName('downloader_send_port')!;
    send.send([id, status, downloadProgress]);
  }

  /// file download 관련

  /// intent 관련
  static const platform = MethodChannel('intent');

  Future<String> getAppUrl(String url) async {
    if (Platform.isAndroid) {
      return await platform.invokeMethod('getAppUrl', <String, Object>{'url': url});
    } else {
      return url;
    }
  }

  Future<String> getMarketUrl(String url) async {
    if (Platform.isAndroid) {
      return await platform.invokeMethod('getMarketUrl', <String, Object>{'url': url});
    } else {
      return url;
    }
  }

  /// intent 관련

  /// 파일 다운로드
  Future<void> downloadFile(InAppWebViewController controller, DownloadStartRequest downloadStartRequest) async {
    // 저장공간 권한 요청 추가
    if(await Permission.storage.status.isDenied) {
      await Permission.storage.request();
    }

    // blob file download
    if (downloadStartRequest.url.toString().startsWith('blob:')) {
      var jsContent = await rootBundle.loadString("assets/js/base64.js");
      await controller.evaluateJavascript(source: jsContent.replaceAll("blobUrlPlaceholder", downloadStartRequest.url.toString()));
    } else {
      // file download
      try {
        final Directory? directory = await getDownloadsDirectory();
        final String savedDirPath = directory!.path;

        await FlutterDownloader.enqueue(
          url: downloadStartRequest.url.toString(),
          savedDir: savedDirPath,
          saveInPublicStorage: true,
          showNotification: false,
          openFileFromNotification: false,
        );

        showToast('파일 다운로드가 완료되었습니다.');
      } catch (e) {
        if (kDebugMode) print(e);
        showToast('파일 다운로드에 실패했습니다.');
      }
    }
  }

  @override
  void initState() {
    super.initState();

    pullToRefreshController = (kIsWeb
        ? null
        : PullToRefreshController(
            options: PullToRefreshOptions(
              color: Colors.blue,
            ),
            onRefresh: () async {
              if (defaultTargetPlatform == TargetPlatform.android) {
                webViewController.reload();
              } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
                webViewController.loadUrl(urlRequest: URLRequest(url: await webViewController.getUrl()));
              }
            },
          ))!;

    /// file download 관련
    IsolateNameServer.registerPortWithName(_port.sendPort, 'downloader_send_port');

    FlutterDownloader.registerCallback(downloadCallback);

    /// file download 관련
  }

  @override
  void dispose() {
    super.dispose();

    IsolateNameServer.removePortNameMapping('downloader_send_port');
  }

  static DateTime? currentBackPressTime;

  Future<bool> _goBack(BuildContext context) async {
    if (await webViewController.canGoBack()) {
      webViewController.goBack();
      return Future.value(false);
    } else {
      if (currentBackPressTime == null) {
        return backToast();
      } else if (DateTime.now().difference(currentBackPressTime!) > const Duration(seconds: 2)) {
        return backToast();
      }

      return Future.value(true);
    }
  }

  Future<bool> backToast() {
    currentBackPressTime = DateTime.now();

    showToast("뒤로가기를 한 번 더 입력하시면 종료됩니다.");
    return Future.value(false);
  }

  void showToast(String msg) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 2,
      fontSize: 12.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: WillPopScope(
          onWillPop: () => _goBack(context),
          child: Column(
            children: <Widget>[
              progress < 1.0 ? LinearProgressIndicator(value: progress, color: Colors.grey) : const SizedBox.shrink(),
              Expanded(
                child: Stack(
                  children: [
                    InAppWebView(
                      key: webViewKey,
                      initialUrlRequest: URLRequest(url: myUrl),
                      initialOptions: InAppWebViewGroupOptions(
                        crossPlatform: InAppWebViewOptions(
                          javaScriptCanOpenWindowsAutomatically: true,
                          javaScriptEnabled: true,
                          useOnDownloadStart: true,
                          useOnLoadResource: true,
                          useShouldOverrideUrlLoading: true,
                          mediaPlaybackRequiresUserGesture: true,
                          allowFileAccessFromFileURLs: true,
                          allowUniversalAccessFromFileURLs: true,
                          verticalScrollBarEnabled: true,
                          userAgent: 'random',
                        ),
                        android: AndroidInAppWebViewOptions(
                          useHybridComposition: true,
                          allowContentAccess: true,
                          builtInZoomControls: true,
                          thirdPartyCookiesEnabled: true,
                          allowFileAccess: true,
                          geolocationEnabled: true,
                          supportMultipleWindows: true,
                        ),
                        ios: IOSInAppWebViewOptions(
                          allowsInlineMediaPlayback: true,
                          allowsBackForwardNavigationGestures: true,
                        ),
                      ),
                      pullToRefreshController: pullToRefreshController,
                      onLoadStart: (InAppWebViewController controller, uri) async {
                        final String url = uri.toString();

                        /// intent
                        if (url.contains(RegExp('^intent:'))) {
                          controller.goBack();

                          getAppUrl(url).then((value) async {
                            /// 플레이스토어 이동
                            final marketUrl = await getMarketUrl(url);
                            await launchUrlString(marketUrl);
                          });
                        } else {
                          /// intent 아닌 경우
                          if (url.startsWith('tel:') || url.startsWith('sms:')) {
                            /// tel, sms
                            controller.goBack();
                            if (await canLaunchUrl(uri!)) launchUrl(uri);
                          } else {
                            setState(() {
                              myUrl = uri!;
                            });
                          }
                        }
                      },
                      onLoadStop: (InAppWebViewController controller, uri) {
                        setState(() {
                          myUrl = uri!;
                        });
                      },
                      onProgressChanged: (controller, progress) {
                        if (progress == 100) {
                          pullToRefreshController.endRefreshing();
                        }
                        setState(() {
                          this.progress = progress / 100;
                        });
                      },
                      androidOnPermissionRequest: (controller, origin, resources) async {
                        return PermissionRequestResponse(resources: resources, action: PermissionRequestResponseAction.GRANT);
                      },
                      onWebViewCreated: (InAppWebViewController controller) {
                        webViewController = controller;
                      },
                      onCreateWindow: (controller, createWindowRequest) async {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return InAppWebView(
                              // Setting the windowId property is important here!
                              windowId: createWindowRequest.windowId,
                              initialOptions: InAppWebViewGroupOptions(
                                android: AndroidInAppWebViewOptions(
                                  builtInZoomControls: true,
                                  thirdPartyCookiesEnabled: true,
                                ),
                                crossPlatform: InAppWebViewOptions(
                                  cacheEnabled: true,
                                  javaScriptEnabled: true,
                                  userAgent: 'random',
                                ),
                                ios: IOSInAppWebViewOptions(
                                  allowsInlineMediaPlayback: true,
                                  allowsBackForwardNavigationGestures: true,
                                ),
                              ),
                              onCloseWindow: (controller) async {
                                if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                }
                              },
                            );
                          },
                        );
                        // Uri uri = createWindowRequest.request.url!;
                        //
                        // if (await canLaunchUrl(uri)) {
                        //   await launchUrl(uri);
                        // }

                        return true;
                      },
                      onDownloadStartRequest: (controller, downloadStartRequest) => downloadFile(controller, downloadStartRequest),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
