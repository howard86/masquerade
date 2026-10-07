import 'dart:js_interop';

extension on JSString {
  external JSString normalize(JSString form);
}

String _normalize(String input, String form) =>
    input.toJS.normalize(form.toJS).toDart;

String nfc(String input) => _normalize(input, 'NFC');
String nfd(String input) => _normalize(input, 'NFD');
String nfkc(String input) => _normalize(input, 'NFKC');
String nfkd(String input) => _normalize(input, 'NFKD');
