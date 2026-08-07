// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

void callJsMethod(String method, [List<dynamic> args = const []]) {
  js.context.callMethod(method, args);
}
