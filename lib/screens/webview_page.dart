import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> with WidgetsBindingObserver {
  late WebViewController controller;
  static DateTime? currentBackPressTime;
  static const url = 'https://www.trresure.com/';
  bool _isInProgress = false;

  Future<bool> _goBack(BuildContext context) async {
    if (await controller.canGoBack()) {
      controller.goBack();
      return Future.value(false);
    } else {
      if (currentBackPressTime == null) {
        return showToast();
      } else if (DateTime.now().difference(currentBackPressTime!) > const Duration(seconds: 2)) {
        return showToast();
      }

      return Future.value(true);
    }
  }

  Future<bool> showToast() {
    currentBackPressTime = DateTime.now();

    Fluttertoast.showToast(
      msg: "한 번 더 눌러서 종료",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 2,
      fontSize: 12.0,
    );
    return Future.value(false);
  }

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

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {},
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            if (kDebugMode) print(request.url);
            if (request.url.contains(RegExp('^intent:')) || request.url.startsWith('market://') || request.url.startsWith('ncppay://')) {
              getAppUrl(request.url).then((value) async {
                if (await canLaunchUrlString(value)) {
                  await launchUrlString(value);
                } else {
                  // 플레이스토어 이동
                  final marketUrl = await getMarketUrl(request.url);
                  await launchUrlString(marketUrl);
                }
              });
              return NavigationDecision.prevent;
            } else if (request.url.contains('tel:') || request.url.contains('sms:')) {
              // 전화, 문자
              launchUrl(Uri.parse(request.url));
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    addFileSelectionListener(); // web input file 했을 때 리스너
    super.initState();
  }

  // web input file 했을 때 리스너
  void addFileSelectionListener() async {
    if (Platform.isAndroid) {
      final androidController = controller.platform as AndroidWebViewController;
      await androidController.setOnShowFileSelector(_androidImagePicker);
      setState(() {});
    }
  }

  // 파일 선택
  // Future<List<String>> _androidFilePicker(final FileSelectorParams params) async {
  //   final result = await FilePicker.platform.pickFiles();
  //
  //   if (result != null && result.files.single.path != null) {
  //     final file = File(result.files.single.path!);
  //     return [file.uri.toString()];
  //   }
  //   return [];
  // }

  // 이미지 선택
  Future<List<String>> _androidImagePicker(final FileSelectorParams params) async {
    List<String> list = [];
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();

    for (int i = 0; i < images.length; i++) {
      File file = File(images[i].path);
      list.add(file.uri.toString());
    }

    return list;
  }

  // 라이프 사이클 체크
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kDebugMode) print('////////?? $state');

    if (state == AppLifecycleState.resumed) {
      _shouldReloadWebView();
    }
  }

  // 웹뷰 리로드 (삼성 안드14 이슈)
  Future<void> _shouldReloadWebView() async {
    if (Platform.isAndroid) {
      try {
        var androidInfo = await DeviceInfoPlugin().androidInfo;
        var sdkInt = androidInfo.version.sdkInt;
        var manufacturer = androidInfo.manufacturer;

        if (sdkInt == 34 && manufacturer == 'samsung') {
          setState(() {
            _isInProgress = true;
          });

          Future.delayed(const Duration(milliseconds: 300), () {
            setState(() {
              _isInProgress = false;
            });
          });
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: _isInProgress
              ? const SizedBox.shrink()
              : MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0), //사용자 스케일팩터 무시
                  child: SafeArea(
                    child: WillPopScope(
                      onWillPop: () => _goBack(context),
                      child: WebViewWidget(controller: controller),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
