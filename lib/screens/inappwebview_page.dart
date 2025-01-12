import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher_string.dart';

class InAppWebViewScreen extends StatefulWidget {
  const InAppWebViewScreen({super.key});

  @override
  State<InAppWebViewScreen> createState() => _InAppWebViewScreenState();
}

class _InAppWebViewScreenState extends State<InAppWebViewScreen> {
  String initialUrl = 'https://beautibucks.com/';
  late final InAppWebViewController webViewController;
  DateTime? currentBackPressTime;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => _goBack(),
      child: ColoredBox(
        color: Colors.white,
        child: SafeArea(
          bottom: false,
          child: Scaffold(
            backgroundColor: Colors.white,
            body: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(initialUrl)),
              initialSettings: InAppWebViewSettings(
                javaScriptCanOpenWindowsAutomatically: true,
                javaScriptEnabled: true,
                useHybridComposition: true,
                allowContentAccess: true,
                builtInZoomControls: true,
                thirdPartyCookiesEnabled: true,
                allowFileAccess: true,
                geolocationEnabled: true,
                useOnRenderProcessGone: true,
                useShouldOverrideUrlLoading: true,
                mediaPlaybackRequiresUserGesture: true,
                allowFileAccessFromFileURLs: true,
                useShouldInterceptRequest: true,
                allowUniversalAccessFromFileURLs: true,
                allowsInlineMediaPlayback: true,
                transparentBackground: true,
                supportMultipleWindows: true,
              ),
              shouldOverrideUrlLoading: _shouldOverrideUrlLoading,
              onCreateWindow: _onCreateWindow,
              onWebViewCreated: (controller) => webViewController = controller,
              onPermissionRequest: (controller, request) async {
                return PermissionResponse(resources: request.resources, action: PermissionResponseAction.GRANT);
              },
            ),
          ),
        ),
      ),
    );
  }

  /// URL 로딩 전 처리
  Future<NavigationActionPolicy?> _shouldOverrideUrlLoading(controller, navigationAction) async {
    final String url = navigationAction.request.url.toString();

    // 특수 URL 처리 (예: tel: 또는 sms:)
    if (url.startsWith('tel:') || url.startsWith('sms:')) {
      if (await canLaunchUrlString(url)) {
        await launchUrlString(url);
      }
      return NavigationActionPolicy.CANCEL;
    }

    final bool isIntentUrl = (!url.startsWith('http') && !url.startsWith('https'));

    // android intent 처리
    if (Platform.isAndroid) {
      if (isIntentUrl) {
        await controller.stopLoading();

        final String appUrl = await getAppUrl(url);
        if (await canLaunchUrlString(appUrl)) {
          await launchUrlString(appUrl); // 앱으로 이동
        } else {
          final String marketUrl = await getMarketUrl(url);
          if (await canLaunchUrlString(marketUrl)) {
            await launchUrlString(marketUrl); // 앱이 없으면 Play Store로 이동
          }
        }

        return NavigationActionPolicy.CANCEL;
      }
    }

    // ios intent 처리
    if (Platform.isIOS) {
      if (isIntentUrl) {
        if (await canLaunchUrlString(url)) {
          await launchUrlString(url); // 앱으로 이동
        }

        return NavigationActionPolicy.CANCEL;
      }
    }

    // 기본적으로는 WebView에서 로드
    return NavigationActionPolicy.ALLOW;
  }

  /// 새 창 생성
  Future<bool?> _onCreateWindow(controller, CreateWindowAction createWindowRequest) async {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) {
        return SafeArea(
          bottom: false,
          child: InAppWebView(
            windowId: createWindowRequest.windowId,
            initialSettings: InAppWebViewSettings(
              builtInZoomControls: true,
              thirdPartyCookiesEnabled: true,
              cacheEnabled: true,
              javaScriptEnabled: true,
              allowsInlineMediaPlayback: true,
              allowsBackForwardNavigationGestures: true,
            ),
            onCloseWindow: (controller) async {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
            shouldOverrideUrlLoading: _shouldOverrideUrlLoading,
          ),
        );
      },
    );
    return true;
  }

  final MethodChannel platform = const MethodChannel('intent');

  /// 앱 URL 가져오기
  Future<String> getAppUrl(String url) async {
    if (Platform.isAndroid) {
      return await platform.invokeMethod('getAppUrl', <String, Object>{'url': url});
    } else {
      return url;
    }
  }

  /// 마켓 URL 가져오기
  Future<String> getMarketUrl(String url) async {
    if (Platform.isAndroid) {
      return await platform.invokeMethod('getMarketUrl', <String, Object>{'url': url});
    } else {
      return url;
    }
  }

  /// 뒤로가기 처리
  void _goBack([bool? didPop]) async {
    if (didPop ?? false) return;

    if (await webViewController.canGoBack()) {
      webViewController.goBack();
      return;
    }

    if (mounted) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        SystemNavigator.pop();
      }
    }
  }
}
