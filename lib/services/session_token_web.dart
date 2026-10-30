// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

String? readSessionToken(String key) => html.window.sessionStorage[key];
void writeSessionToken(String key, String token) =>
    html.window.sessionStorage[key] = token;
void deleteSessionToken(String key) => html.window.sessionStorage.remove(key);
