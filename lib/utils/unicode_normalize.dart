// Unicode normalization forms. Browsers ship ICU, so on web this delegates to
// `String.prototype.normalize` instead of bundling the unorm_dart tables.
export 'unicode_normalize_native.dart'
    if (dart.library.js_interop) 'unicode_normalize_web.dart';
