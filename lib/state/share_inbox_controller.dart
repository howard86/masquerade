import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../models/artifact.dart';
import '../models/saved_workflow.dart';
import '../models/work_session.dart';

enum ShareInboxKind { text, url, file }

enum AppIntentAction { inspectClipboard, runWorkflow, resumeLastSession }

@immutable
class AppIntentRequest {
  const AppIntentRequest({
    required this.id,
    required this.action,
    required this.createdAt,
    this.workflowId,
    this.input,
  });

  final String id;
  final AppIntentAction action;
  final DateTime createdAt;
  final String? workflowId;
  final String? input;
}

@immutable
class ShareInboxItem {
  const ShareInboxItem({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.artifact,
    this.filename,
  });

  final String id;
  final ShareInboxKind kind;
  final DateTime createdAt;
  final Artifact<Object?> artifact;
  final String? filename;

  String get label =>
      filename ??
      switch (kind) {
        ShareInboxKind.text => 'Shared text',
        ShareInboxKind.url => 'Shared URL',
        ShareInboxKind.file => 'Shared file',
      };
}

/// Short-lived bridge from the native App Group inbox into Workbench.
class ShareInboxController extends ChangeNotifier {
  ShareInboxController({
    MethodChannel channel = const MethodChannel(channelName),
  }) : _channel = channel {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static const String channelName = 'dev.howardism.masquerade/share_inbox';
  static const int maxPayloadBytes = 65536;
  static final RegExp _id = RegExp(
    r'^[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}$',
  );

  final MethodChannel _channel;
  List<ShareInboxItem> _items = const <ShareInboxItem>[];
  List<AppIntentRequest> _intentRequests = const <AppIntentRequest>[];
  String? _error;
  Future<void>? _refreshing;
  Future<void>? _refreshingIntents;
  int _externalInputRevision = 0;

  List<ShareInboxItem> get items => _items;
  List<AppIntentRequest> get intentRequests => _intentRequests;
  String? get error => _error;
  int get externalInputRevision => _externalInputRevision;

  static Future<ShareInboxController> load({MethodChannel? channel}) async {
    final ShareInboxController controller = ShareInboxController(
      channel: channel ?? const MethodChannel(channelName),
    );
    await Future.wait(<Future<void>>[
      controller.refresh(),
      controller.refreshIntents(),
    ]);
    return controller;
  }

  Future<void> refresh() => _refreshing ??= _refresh().whenComplete(() {
    _refreshing = null;
  });

  Future<Object?> _handleNativeCall(MethodCall call) async {
    if (call.method != 'refreshExternalInputs') return null;
    await Future.wait(<Future<void>>[refresh(), refreshIntents()]);
    return null;
  }

  Future<void> refreshIntents() =>
      _refreshingIntents ??= _refreshIntents().whenComplete(() {
        _refreshingIntents = null;
      });

  Future<void> _refreshIntents() async {
    try {
      final List<Object?> raw =
          await _channel.invokeListMethod<Object?>('consumeIntents') ??
          <Object?>[];
      final List<AppIntentRequest> decoded = raw
          .map(_decodeIntent)
          .whereType<AppIntentRequest>()
          .toList();
      if (decoded.any(
        (AppIntentRequest request) => !_intentRequests.any(
          (AppIntentRequest existing) => existing.id == request.id,
        ),
      )) {
        _externalInputRevision++;
      }
      final Map<String, AppIntentRequest> merged = <String, AppIntentRequest>{
        for (final AppIntentRequest request in _intentRequests)
          request.id: request,
        for (final AppIntentRequest request in decoded) request.id: request,
      };
      _intentRequests = List<AppIntentRequest>.unmodifiable(
        merged.values.toList()..sort(
          (AppIntentRequest a, AppIntentRequest b) => a.createdAt == b.createdAt
              ? a.id.compareTo(b.id)
              : a.createdAt.compareTo(b.createdAt),
        ),
      );
      if (decoded.length != raw.length) {
        _error = 'Some shortcut actions could not be loaded.';
      }
      notifyListeners();
    } on MissingPluginException {
      // Keep already-consumed requests until Workbench handles them.
    } on PlatformException {
      _error = 'Shortcut actions could not be loaded.';
      notifyListeners();
    }
  }

  Future<void> syncWorkflows(Iterable<SavedWorkflow> workflows) async {
    try {
      await _channel.invokeMethod<void>('syncWorkflows', <Object?>[
        for (final SavedWorkflow workflow in workflows)
          <String, String>{'id': workflow.id, 'name': workflow.name},
      ]);
    } on MissingPluginException {
      // App Intents are iOS-only.
    } on PlatformException {
      _error = 'Shortcuts could not be updated.';
      notifyListeners();
    }
  }

  AppIntentRequest? takeIntentRequest(String id) {
    final int index = _intentRequests.indexWhere(
      (AppIntentRequest request) => request.id == id,
    );
    if (index < 0) return null;
    final AppIntentRequest request = _intentRequests[index];
    _intentRequests = List<AppIntentRequest>.unmodifiable(<AppIntentRequest>[
      ..._intentRequests.take(index),
      ..._intentRequests.skip(index + 1),
    ]);
    notifyListeners();
    return request;
  }

  Future<void> _refresh() async {
    try {
      final List<Object?> raw =
          await _channel.invokeListMethod<Object?>('list') ?? <Object?>[];
      final List<ShareInboxItem> next = <ShareInboxItem>[];
      final Set<String> ids = <String>{};
      bool rejected = false;
      for (final Object? value in raw) {
        final ShareInboxItem? item = _decode(value);
        if (item == null || !ids.add(item.id)) {
          rejected = true;
        } else {
          next.add(item);
        }
      }
      next.sort(
        (ShareInboxItem a, ShareInboxItem b) => a.createdAt == b.createdAt
            ? a.id.compareTo(b.id)
            : a.createdAt.compareTo(b.createdAt),
      );
      if (next.any(
        (ShareInboxItem item) =>
            !_items.any((ShareInboxItem existing) => existing.id == item.id),
      )) {
        _externalInputRevision++;
      }
      _items = List<ShareInboxItem>.unmodifiable(next);
      _error = rejected ? 'Some shared items could not be loaded.' : null;
    } on MissingPluginException {
      _items = const <ShareInboxItem>[];
      _error = null;
    } on PlatformException {
      _error = 'Shared items could not be loaded.';
    }
    notifyListeners();
  }

  Future<bool> remove(String id) async {
    if (!_id.hasMatch(id)) return false;
    try {
      final bool removed =
          await _channel.invokeMethod<bool>('remove', id) ?? false;
      if (!removed) {
        _error = 'Shared item could not be removed.';
        notifyListeners();
        return false;
      }
      _items = List<ShareInboxItem>.unmodifiable(
        _items.where((ShareInboxItem item) => item.id != id),
      );
      _error = null;
      notifyListeners();
      return true;
    } on PlatformException {
      _error = 'Shared item could not be removed.';
      notifyListeners();
      return false;
    }
  }

  Future<void> clear() async {
    try {
      await _channel.invokeMethod<void>('clear');
    } on MissingPluginException {
      // Non-iOS shells have no native inbox.
    } on PlatformException {
      _error = 'Shared items could not be cleared.';
      notifyListeners();
      return;
    }
    _items = const <ShareInboxItem>[];
    _error = null;
    notifyListeners();
  }

  static ShareInboxItem? _decode(Object? value) {
    try {
      return _decodeChecked(value);
    } catch (_) {
      return null;
    }
  }

  static ShareInboxItem? _decodeChecked(Object? value) {
    if (value is! Map<Object?, Object?> ||
        value['id'] is! String ||
        !_id.hasMatch(value['id'] as String) ||
        value['kind'] is! String ||
        value['createdAt'] is! int ||
        value['byteCount'] is! int) {
      return null;
    }
    final int byteCount = value['byteCount'] as int;
    if (byteCount <= 0 || byteCount > maxPayloadBytes) return null;
    final ShareInboxKind? kind = switch (value['kind']) {
      'text' => ShareInboxKind.text,
      'url' => ShareInboxKind.url,
      'file' => ShareInboxKind.file,
      _ => null,
    };
    if (kind == null || value['sensitive'] != false) return null;
    if ((value['createdAt'] as int) <= 0) return null;

    final String raw;
    if (kind == ShareInboxKind.file) {
      final Object? data = value['data'];
      if (data is! Uint8List || data.length != byteCount) return null;
      try {
        raw = utf8.decode(data);
      } on FormatException {
        return null;
      }
    } else {
      if (value['payload'] is! String) return null;
      raw = value['payload'] as String;
      if (utf8.encode(raw).length != byteCount) return null;
    }
    if (raw.isEmpty || isProtectedWorkflowString(raw)) return null;

    final String? filename = value['filename'] is String
        ? value['filename'] as String
        : null;
    if ((kind == ShareInboxKind.file) != (filename != null)) return null;
    if (filename != null &&
        (filename.isEmpty ||
            filename.length > 255 ||
            filename.contains('/') ||
            filename.contains('\\') ||
            filename.runes.any(
              (int value) =>
                  value < 32 || value == 127 || (value >= 128 && value <= 159),
            ) ||
            isProtectedWorkflowString(filename))) {
      return null;
    }
    return ShareInboxItem(
      id: value['id'] as String,
      kind: kind,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        value['createdAt'] as int,
        isUtc: true,
      ),
      filename: filename,
      artifact: Artifact<Object?>(
        kind: kind == ShareInboxKind.url
            ? ArtifactKind.url
            : ArtifactKind.unknown,
        rawValue: raw,
        provenance: ArtifactProvenance.shareExtension,
      ),
    );
  }

  static AppIntentRequest? _decodeIntent(Object? value) {
    if (value is! Map<Object?, Object?> ||
        value['id'] is! String ||
        !_id.hasMatch(value['id'] as String) ||
        value['action'] is! String ||
        value['createdAt'] is! int ||
        (value['createdAt'] as int) <= 0) {
      return null;
    }
    final AppIntentAction? action = switch (value['action']) {
      'inspectClipboard' => AppIntentAction.inspectClipboard,
      'runWorkflow' => AppIntentAction.runWorkflow,
      'resumeLastSession' => AppIntentAction.resumeLastSession,
      _ => null,
    };
    if (action == null) return null;
    final String? workflowId = value['workflowId'] as String?;
    final String? input = value['input'] as String?;
    if (action == AppIntentAction.runWorkflow) {
      if (workflowId == null ||
          !RegExp(
            r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$',
          ).hasMatch(workflowId) ||
          input == null ||
          input.isEmpty ||
          utf8.encode(input).length > maxPayloadBytes ||
          isProtectedWorkflowString(input)) {
        return null;
      }
    } else if (workflowId != null || input != null) {
      return null;
    }
    return AppIntentRequest(
      id: value['id'] as String,
      action: action,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        value['createdAt'] as int,
        isUtc: true,
      ),
      workflowId: workflowId,
      input: input,
    );
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }
}

class ShareInboxScope extends InheritedNotifier<ShareInboxController> {
  const ShareInboxScope({
    super.key,
    required ShareInboxController controller,
    required super.child,
  }) : super(notifier: controller);

  static ShareInboxController of(BuildContext context) {
    final ShareInboxScope? scope = context
        .dependOnInheritedWidgetOfExactType<ShareInboxScope>();
    assert(scope != null, 'ShareInboxScope not found.');
    return scope!.notifier!;
  }
}
