// import 'dart:async';
// import 'dart:io';
//
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_webview_pro/webview_flutter.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:url_launcher/url_launcher_string.dart';
//
// class HomePage extends StatefulWidget {
//   const HomePage({Key? key}) : super(key: key);
//
//   @override
//   // ignore: library_private_types_in_public_api
//   _HomePageState createState() => _HomePageState();
// }
//
// class _HomePageState extends State<HomePage> {
//   static DateTime? currentBackPressTime;
//   final Completer<WebViewController> _completerController = Completer<WebViewController>();
//   late WebViewController _controller;
//
//   Future<bool> _goBack(BuildContext context) async {
//     if (await _controller.canGoBack()) {
//       _controller.goBack();
//       return Future.value(false);
//     } else {
//       if (currentBackPressTime == null) {
//         return showToast();
//       } else if (DateTime.now().difference(currentBackPressTime!) > const Duration(seconds: 2)) {
//         return showToast();
//       }
//
//       return Future.value(true);
//     }
//   }
//
//   Future<bool> showToast() {
//     currentBackPressTime = DateTime.now();
//
//     Fluttertoast.showToast(
//       msg: "한 번 더 눌러서 종료",
//       toastLength: Toast.LENGTH_SHORT,
//       gravity: ToastGravity.BOTTOM,
//       timeInSecForIosWeb: 2,
//       fontSize: 12.0,
//     );
//     return Future.value(false);
//   }
//
//   @override
//   void initState() {
//     super.initState();
//     if (Platform.isAndroid) WebView.platform = SurfaceAndroidWebView();
//   }
//
//   static const platform = MethodChannel('intent');
//
//   Future<String> getAppUrl(String url) async {
//     if (Platform.isAndroid) {
//       return await platform.invokeMethod('getAppUrl', <String, Object>{'url': url});
//     } else {
//       return url;
//     }
//   }
//
//   Future<String> getMarketUrl(String url) async {
//     if (Platform.isAndroid) {
//       return await platform.invokeMethod('getMarketUrl', <String, Object>{'url': url});
//     } else {
//       return url;
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: MediaQuery(
//         data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling), //사용자 스케일팩터 무시
//         child: SafeArea(
//           child: WillPopScope(
//             onWillPop: () => _goBack(context),
//             child: WebView(
//               initialUrl: 'https://mooaresume.mooacst.com/',
//               javascriptMode: JavascriptMode.unrestricted,
//               onWebViewCreated: (WebViewController webViewController) {
//                 _completerController.future.then((value) => _controller = value);
//                 _completerController.complete(webViewController);
//               },
//               geolocationEnabled: true,
//               navigationDelegate: (NavigationRequest request) async {
//                 if (kDebugMode) print(request.url);
//                 if (request.url.contains(RegExp('^intent:')) ||
//                     request.url.startsWith('market://') ||
//                     request.url.startsWith('ncppay://')) {
//                   getAppUrl(request.url).then((value) async {
//                     if (await canLaunchUrlString(value)) {
//                       await launchUrlString(value);
//                     } else {
//                       // 플레이스토어 이동
//                       final marketUrl = await getMarketUrl(request.url);
//                       await launchUrlString(marketUrl);
//                     }
//                   });
//                   return NavigationDecision.prevent;
//                 } else if (request.url.contains('tel:') || request.url.contains('sms:')) {
//                   // 전화, 문자
//                   launchUrl(Uri.parse(request.url));
//                   return NavigationDecision.prevent;
//                 }
//                 return NavigationDecision.navigate;
//               },
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
